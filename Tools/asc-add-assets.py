#!/usr/bin/env python3
"""Add verified images to App Store drafts; never replace untracked assets/submit.

Imports the bundled ASC client and upload/decoded-pixel verification helpers.
Credentials remain in memory. Journals contain IDs, hashes, specs and states,
never JWTs, private keys, upload operations or delivery URLs.
"""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys
import time

sys.dont_write_bytecode = True


def run(args):
    module_spec = importlib.util.spec_from_file_location("asc_helpers", args.helper)
    helper = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(helper)
    manifest = helper.load(args.manifest)
    client = helper.ASC(args)
    app = client.check_app(manifest["appId"], manifest["bundleId"])
    version = client.check_version(manifest["appId"], manifest["versionId"])
    if version["attributes"]["versionString"] != manifest["versionString"]:
        raise ValueError("Draft version string differs from manifest")
    library_id = client.request(f"/v1/apps/{app['id']}/assetLibrary")["data"]["id"]
    reference = client.request("/v1/appAssetLibraryRefData")["data"][0]["attributes"]
    placement_types = {p["placementTypeId"]: p for p in reference["placementTypes"]}
    specs = {s["specId"]: s for s in reference["imageSpecs"]}
    locales = client.rows(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations", {"limit": 200})
    localizations = {l["attributes"]["locale"]: l["id"] for l in locales}
    groups = []
    for group in manifest["groups"]:
        typ = group["placementType"]
        if typ not in {"APP_SCREENSHOT", "PRODUCT_PAGE_HEADER_ASSET", "APP_STORE_SEARCH_RESULTS_ASSET"}:
            raise ValueError("Only screenshots and Header/Search Results artwork supported")
        definition = placement_types[typ]
        category = "APP_SCREENSHOTS_AND_PREVIEWS" if typ == "APP_SCREENSHOT" else "CREATIVE_ASSETS"
        if category not in definition["acceptsAssetCategories"]:
            raise ValueError("Backend does not accept requested category")
        allowed = next(m["specs"] for m in definition["specMappings"] if m["placementGroupId"] == group["placementGroup"])
        images = []
        for path in group["images"]:
            image = helper.image_info(path)
            w, h = image["size"]
            accepted = [sid for sid in allowed if sid in specs and
                        specs[sid]["dimensions"]["minWidth"] <= w <= specs[sid]["dimensions"]["maxWidth"] and
                        specs[sid]["dimensions"]["minHeight"] <= h <= specs[sid]["dimensions"]["maxHeight"] and
                        image["fileSize"] <= specs[sid]["maxFileSize"] and
                        Path(path).suffix.lower() in specs[sid]["fileExtensions"]]
            if not accepted:
                raise ValueError("Image fails current Apple dimensions/format/size specifications")
            image["acceptedSpecIds"] = accepted
            image["category"] = category
            images.append(image)
        if len({i["sha256"] for i in images}) != len(images):
            raise ValueError("Duplicate source images in group")
        limit = 10 if typ == "APP_SCREENSHOT" else 1
        if not 1 <= len(images) <= limit:
            raise ValueError("Image count exceeds placement limit")
        groups.append({"locale": group["locale"], "localizationId": localizations[group["locale"]],
                       "placementType": typ, "placementGroup": group["placementGroup"], "images": images})
    identities = {(g["locale"], g["placementType"], g["placementGroup"]) for g in groups}
    if len(identities) != len(groups):
        raise ValueError("Duplicate target group")
    def key(group):
        return ":".join(group[k] for k in ("locale", "placementType", "placementGroup"))

    previous = {}
    previous_journal_path = manifest.get("replaceOwnedPlacementsFromJournal")
    previous_journal_sha = None
    if previous_journal_path:
        prior = helper.load(previous_journal_path)
        if not prior.get("complete") or any(prior["plan"][k] != manifest[k] for k in ("appId", "bundleId", "versionId", "versionString")):
            raise ValueError("Replacement journal must be completed and belong to this exact app draft")
        previous_journal_sha = helper.hashes(Path(previous_journal_path).read_bytes())["sha256"]
        verified_image_ids = {image_id for sha, image_id in prior["images"].items()
                              if prior["verification"].get(sha, {}).get("exactDecodedMatch") is True}
        for group in groups:
            rows = prior.get("finalPlacements", {}).get(key(group), [])
            if not rows or any(p["imageId"] not in verified_image_ids or p["attributes"]["state"] != "ACTIVE" or
                               p["attributes"]["placementType"] != group["placementType"] or
                               p["attributes"]["placementGroup"] != group["placementGroup"] for p in rows):
                raise ValueError("Replacement must identify exact verified task-owned ACTIVE placements")
            previous[key(group)] = rows
    plan = {"appId": app["id"], "bundleId": manifest["bundleId"], "versionId": version["id"],
            "versionString": manifest["versionString"], "assetLibraryId": library_id, "groups": groups}
    if previous_journal_path:
        plan.update(previousJournalSHA256=previous_journal_sha, previousOwnedPlacements=previous)
    fingerprint = helper.hashes(json.dumps(plan, sort_keys=True).encode())["sha256"]
    journal = helper.load(args.journal) if Path(args.journal).exists() else {
        "planSHA256": fingerprint, "plan": plan, "images": {}, "placements": {}, "verification": {}}
    if journal["planSHA256"] != fingerprint:
        raise ValueError("Journal/source images differ from reviewed plan")

    def current(group):
        return client.rows(f"/v1/appStoreVersionLocalizations/{group['localizationId']}/placements", {
            "filter[placementType]": group["placementType"], "filter[placementGroup]": group["placementGroup"],
            "sort": "placementGroupPosition", "include": "image", "limit": 200})

    def check_empty_or_ours(group):
        placements = current(group)
        tracked = set(journal["placements"].get(key(group), []))
        owned_prior = {p["id"]: p for p in previous.get(key(group), [])}
        for placement in placements:
            if placement["id"] in tracked:
                continue
            prior = owned_prior.get(placement["id"])
            if not prior or placement["attributes"]["state"] != "ACTIVE" or placement["relationships"]["image"]["data"]["id"] != prior["imageId"]:
                raise ValueError("Target placement contains an untracked or changed asset; preserving it")
        return placements

    for group in groups:
        check_empty_or_ours(group)
    print("Verified app, editable draft, sources, backend specs and available target placements", flush=True)
    helper.save(args.journal, journal)
    if not args.execute:
        print("Dry run only; add --execute to upload and place verified originals", flush=True)
        return
    existing = client.rows(f"/v1/appAssetLibraries/{library_id}/images", {"limit": 200})
    unique = {i["sha256"]: i for group in groups for i in group["images"]}
    for sha, image in unique.items():
        image_id = journal["images"].get(sha)
        filename = "asc-" + sha[:16] + "-" + image["fileName"]
        resource = client.request(f"/v1/appAssetLibraryImages/{image_id}")["data"] if image_id else next((
            r for r in existing if r["attributes"]["fileName"] == filename and
            r["attributes"]["fileSize"] == image["fileSize"] and r["attributes"]["category"] == image["category"]), None)
        if not resource:
            resource = client.request("/v1/appAssetLibraryImages", "POST", {"data": {
                "type": "appAssetLibraryImages", "attributes": {"category": image["category"],
                "fileName": filename, "fileSize": image["fileSize"], "referenceName": filename},
                "relationships": {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": library_id}}}}})["data"]
            existing.append(resource)
        image_id = resource["id"]
        journal["images"][sha] = image_id
        helper.save(args.journal, journal)
        if resource["attributes"]["state"] == "AWAITING_UPLOAD":
            helper.upload_parts(client, resource["attributes"].get("uploadOperations") or [], image)
            client.request(f"/v1/appAssetLibraryImages/{image_id}", "PATCH", {"data": {
                "type": "appAssetLibraryImages", "id": image_id, "attributes": {"uploaded": True}}})
        print("Uploaded original", image["fileName"], image_id, flush=True)
    # Require successful native PNG delivery and exact decoded RGB equality before any placement.
    for sha, image in unique.items():
        complete = helper.library_complete(client, journal["images"][sha], image)
        for group in groups:
            for target in group["images"]:
                if target["sha256"] == sha and complete["attributes"]["specId"] not in target["acceptedSpecIds"]:
                    raise ValueError("Processed spec is incompatible with a requested placement")
        journal["verification"][sha] = complete["verification"]
        journal["verification"][sha]["state"] = complete["attributes"]["state"]
        journal["verification"][sha]["specId"] = complete["attributes"]["specId"]
        helper.save(args.journal, journal)
        print("Verified exact delivered pixels", image["fileName"], flush=True)
    # Recheck target identity and editable status immediately before adding placements.
    client.check_app(manifest["appId"], manifest["bundleId"])
    client.check_version(manifest["appId"], manifest["versionId"])
    for group in groups:
        placements = check_empty_or_ours(group)
        previous_ids = {p["id"] for p in previous.get(key(group), [])}
        for old in placements:
            if old["id"] in previous_ids:
                # Only exact task-owned placements can be removed, after every
                # replacement's full-resolution pixels have been verified. The
                # old image itself is retained, so recovery can re-place it.
                journal.setdefault("retainedPreviousImages", {})[old["id"]] = {
                    "imageId": old["relationships"]["image"]["data"]["id"], "group": key(group),
                    "localizationId": group["localizationId"], "status": "REMOVING_OWN_PLACEMENT"}
                helper.save(args.journal, journal)
                client.request(f"/v1/appAssetLibraryPlacements/{old['id']}", "DELETE")
                journal["retainedPreviousImages"][old["id"]]["status"] = "OWN_PLACEMENT_REMOVED_IMAGE_RETAINED"
                helper.save(args.journal, journal)
        placements = check_empty_or_ours(group)
        desired = []
        for image in group["images"]:
            image_id = journal["images"][image["sha256"]]
            placement = next((p for p in placements if p["relationships"]["image"]["data"]["id"] == image_id), None)
            if not placement:
                placement = client.request("/v1/appAssetLibraryPlacements", "POST", {"data": {
                    "type": "appAssetLibraryPlacements", "attributes": {
                        "placementType": group["placementType"], "placementGroup": group["placementGroup"]},
                    "relationships": {"image": {"data": {"type": "appAssetLibraryImages", "id": image_id}},
                        "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": group["localizationId"]}}}}})["data"]
                journal["placements"].setdefault(key(group), []).append(placement["id"])
                helper.save(args.journal, journal)
            desired.append(placement["id"])
        if len(desired) > 1:
            client.request("/v1/appAssetLibraryPlacementOrderingRequests", "POST", {"data": {
                "type": "appAssetLibraryPlacementOrderingRequests", "attributes": {"placementGroup": group["placementGroup"]},
                "relationships": {"orderedPlacements": {"data": [{"type": "appAssetLibraryPlacements", "id": p} for p in desired]},
                    "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": group["localizationId"]}}}}})
        deadline = time.monotonic() + 90
        desired_images = [journal["images"][image["sha256"]] for image in group["images"]]
        while time.monotonic() < deadline:
            actual = current(group)
            if ([p["id"] for p in actual] == desired and
                [p["relationships"]["image"]["data"]["id"] for p in actual] == desired_images and
                all(p["attributes"]["state"] == "ACTIVE" for p in actual)):
                break
            time.sleep(2)
        else:
            raise ValueError("Placements did not reach the expected final state/order")
        journal.setdefault("finalPlacements", {})[key(group)] = [{"id": p["id"], "attributes": p["attributes"],
            "imageId": p["relationships"]["image"]["data"]["id"]} for p in actual]
        helper.save(args.journal, journal)
        print("Placed and verified", group["locale"], group["placementType"], group["placementGroup"], len(actual), flush=True)
    journal["complete"] = True
    journal["verifiedAt"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    helper.save(args.journal, journal)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--helper", default=str(Path(__file__).with_name("asc-client.py")),
                        help="Override the bundled ASC client helper")
    parser.add_argument("--issuer-id", default=os.environ.get("ASC_ISSUER_ID"))
    parser.add_argument("--key-id", default=os.environ.get("ASC_KEY_ID"))
    parser.add_argument("--private-key", default=os.environ.get("ASC_PRIVATE_KEY"))
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--journal", required=True)
    parser.add_argument("--execute", action="store_true")
    try:
        run(parser.parse_args())
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        raise SystemExit(1) from None
