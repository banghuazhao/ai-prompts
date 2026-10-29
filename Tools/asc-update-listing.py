#!/usr/bin/env python3
"""Fill a platform's draft App Store version listing text; never submits.

Finds the single editable App Store version for --platform (for example MAC_OS),
then updates its localization's promotional text, description, keywords and
URLs from a listing JSON file. Empty URLs are copied from the iOS draft or live
version of the same locale. Dry run by default; add --execute to write.

Optionally writes an asc-add-assets.py screenshot manifest for the same draft,
so screenshots can be added with the existing verified uploader.
Credentials stay in memory, exactly as in asc-client.py.
"""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True

FIELDS = ("promotionalText", "description", "keywords", "supportUrl", "marketingUrl")
LIMITS = {"promotionalText": 170, "description": 4000, "keywords": 100}


def load_helper(path):
    spec = importlib.util.spec_from_file_location("asc_helpers", path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    return helper


def state(version):
    attributes = version["attributes"]
    return attributes.get("appVersionState") or attributes.get("appStoreState")


def run(args):
    helper = load_helper(args.helper)
    listing = helper.load(args.listing)
    for field, limit in LIMITS.items():
        if len(listing.get(field) or "") > limit:
            raise ValueError(f"{field} is longer than {limit} characters")

    client = helper.ASC(args)
    app = client.check_app(args.app_id, args.bundle_id)
    versions = client.rows(f"/v1/apps/{app['id']}/appStoreVersions", {"limit": 200})
    drafts = [v for v in versions if v["attributes"]["platform"] == args.platform and state(v) in helper.EDITABLE]
    if len(drafts) != 1:
        raise ValueError(f"Expected exactly one editable {args.platform} version, found {len(drafts)}")
    version = client.check_version(app["id"], drafts[0]["id"])
    version_string = version["attributes"]["versionString"]
    print(f"Target: {args.platform} {version_string} ({state(version)}), version ID {version['id']}")

    locale = listing["locale"]
    localizations = client.rows(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations", {"limit": 200})
    localization = next((l for l in localizations if l["attributes"]["locale"] == locale), None)

    # Copy URLs the listing leaves empty from the iOS version of the same locale.
    wanted = {field: listing.get(field) for field in FIELDS}
    if not wanted["supportUrl"] or not wanted["marketingUrl"]:
        ios = [v for v in versions if v["attributes"]["platform"] == "IOS"]
        ios.sort(key=lambda v: state(v) not in helper.EDITABLE)  # prefer the draft
        for source in ios[:2]:
            rows = client.rows(f"/v1/appStoreVersions/{source['id']}/appStoreVersionLocalizations", {"limit": 200})
            match = next((l for l in rows if l["attributes"]["locale"] == locale), None)
            if match:
                for field in ("supportUrl", "marketingUrl"):
                    wanted[field] = wanted[field] or match["attributes"].get(field)
                if wanted["supportUrl"]:
                    break
    if not wanted["supportUrl"]:
        raise ValueError("No support URL in the listing or the iOS version; add supportUrl to the listing file")
    wanted = {field: value for field, value in wanted.items() if value}

    current = localization["attributes"] if localization else {}
    changes = {field: value for field, value in wanted.items() if current.get(field) != value}
    for field, value in changes.items():
        before = current.get(field)
        print(f"- {field}: {len(before or '')} -> {len(value)} characters" + ("" if before else " (new)"))
    if not changes:
        print("Listing already matches; nothing to change")

    if args.screenshot_manifest:
        manifest = {"appId": app["id"], "bundleId": args.bundle_id, "versionId": version["id"],
                    "versionString": version_string,
                    "groups": [{"locale": locale, "placementType": "APP_SCREENSHOT", "placementGroup": "MAC_PROFILE",
                                "images": args.screenshot}]}
        helper.save(args.screenshot_manifest, manifest)
        print("Wrote screenshot manifest", args.screenshot_manifest)

    if not args.execute:
        print("Dry run only; add --execute to save the listing text (the version is never submitted)")
        return
    if not changes:
        return
    # Recheck the target is still the exact editable draft right before writing.
    client.check_version(app["id"], version["id"])
    if localization:
        client.request(f"/v1/appStoreVersionLocalizations/{localization['id']}", "PATCH", {"data": {
            "type": "appStoreVersionLocalizations", "id": localization["id"], "attributes": changes}})
    else:
        client.request("/v1/appStoreVersionLocalizations", "POST", {"data": {
            "type": "appStoreVersionLocalizations", "attributes": {"locale": locale, **changes},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
    saved = next(l for l in client.rows(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations",
                                         {"limit": 200}) if l["attributes"]["locale"] == locale)
    mismatched = [field for field, value in wanted.items() if saved["attributes"].get(field) != value]
    if mismatched:
        raise ValueError(f"Saved listing differs for: {', '.join(mismatched)}")
    print(f"Saved and verified {locale} listing for {args.platform} {version_string}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--helper", default=str(Path(__file__).with_name("asc-client.py")))
    parser.add_argument("--issuer-id", default=os.environ.get("ASC_ISSUER_ID"))
    parser.add_argument("--key-id", default=os.environ.get("ASC_KEY_ID"))
    parser.add_argument("--private-key", default=os.environ.get("ASC_PRIVATE_KEY"))
    parser.add_argument("--app-id", default="6748734078")
    parser.add_argument("--bundle-id", default="com.appsbay.aiPrompts")
    parser.add_argument("--platform", default="MAC_OS", choices=["MAC_OS", "IOS", "TV_OS", "VISION_OS"])
    parser.add_argument("--listing", required=True)
    parser.add_argument("--screenshot-manifest", help="Also write an asc-add-assets.py manifest for this draft")
    parser.add_argument("--screenshot", action="append", default=[], help="Screenshot path, in order (repeatable)")
    parser.add_argument("--execute", action="store_true")
    try:
        run(parser.parse_args())
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        raise SystemExit(1) from None
