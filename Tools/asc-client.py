#!/usr/bin/env python3
"""Shared App Store Connect client and safe image-upload verification helpers.

Adapted from the established asc-screenshots.py tooling. API JWTs/private keys
remain in memory; signed image transfer URLs never receive API authorization.
Dependencies: PyJWT, cryptography, certifi, Pillow.
"""

from __future__ import annotations
import hashlib
import io
import json
from pathlib import Path
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
import certifi
import jwt
from PIL import Image

API_ROOT = "https://api.appstoreconnect.apple.com"


EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}


class APIError(RuntimeError):
    pass


def save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    def safe_record(item):
        if isinstance(item, dict):
            return {key: safe_record(value) for key, value in item.items() if key != "uploadOperations"}
        if isinstance(item, list):
            return [safe_record(value) for value in item]
        return item
    temporary.write_text(json.dumps(safe_record(value), indent=2) + "\n")
    temporary.replace(path)


def load(path):
    return json.loads(Path(path).read_text())


def hashes(data):
    return {"md5": hashlib.md5(data).hexdigest(), "sha256": hashlib.sha256(data).hexdigest()}


def image_info(path):
    path = Path(path).resolve()
    data = path.read_bytes()
    with Image.open(io.BytesIO(data)) as image:
        if path.suffix.lower() not in {".png", ".jpeg", ".jpg"} or image.format not in {"PNG", "JPEG"} or image.mode not in {"RGB", "L"}:
            raise ValueError(f"Opaque RGB/L PNG or JPEG required: {path}")
        size = list(image.size)
        image.verify()
    # PNG EXIF inspection may load the image, so inspect it in a fresh decoder
    # after verify(), which Pillow requires immediately after opening the file.
    with Image.open(io.BytesIO(data)) as image:
        if getattr(image, "n_frames", 1) != 1 or image.getexif().get(274, 1) != 1 or "transparency" in image.info:
            raise ValueError(f"One upright, opaque image required: {path}")
    return {"path": str(path), "fileName": path.name, "fileSize": len(data), "size": size, **hashes(data)}


class ASC:
    def __init__(self, args):
        self.issuer = args.issuer_id
        self.key_id = args.key_id
        if not self.issuer or not self.key_id or not args.private_key:
            raise ValueError("Supply issuer/key IDs and private-key path, or ASC_ISSUER_ID/ASC_KEY_ID/ASC_PRIVATE_KEY")
        self.key = Path(args.private_key).read_text()
        self.context = ssl.create_default_context(cafile=certifi.where())
        class APIRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, request, response, code, message, headers, new_url):
                parsed = urllib.parse.urlparse(new_url)
                if parsed.scheme != "https" or parsed.netloc != "api.appstoreconnect.apple.com":
                    raise APIError("Refusing an API redirect outside App Store Connect")
                return super().redirect_request(request, response, code, message, headers, new_url)
        self.api_opener = urllib.request.build_opener(APIRedirect(), urllib.request.HTTPSHandler(context=self.context))
        self.token = None
        self.expires = 0

    def authorization(self):
        now = int(time.time())
        if now + 90 >= self.expires:
            self.expires = now + 900
            self.token = jwt.encode({"iss": self.issuer, "iat": now, "exp": self.expires,
                                     "aud": "appstoreconnect-v1"}, self.key, algorithm="ES256",
                                    headers={"kid": self.key_id, "typ": "JWT"})
        return "Bearer " + self.token

    def request(self, path, method="GET", payload=None):
        url = path if path.startswith("https://") else API_ROOT + path
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or parsed.netloc != "api.appstoreconnect.apple.com":
            raise ValueError("API credentials may only be sent to App Store Connect")
        data = None if payload is None else json.dumps(payload).encode()
        request = urllib.request.Request(url, data=data, method=method,
                                         headers={"Authorization": self.authorization(),
                                                  "Accept": "application/json", "Content-Type": "application/json"})
        try:
            with self.api_opener.open(request, timeout=90) as response:
                body = response.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace").replace(self.token or "", "[REDACTED]")
            raise APIError(f"HTTP {error.code}: {detail}") from None

    def rows(self, path, query=None):
        if query:
            path += ("&" if "?" in path else "?") + urllib.parse.urlencode(query)
        page = self.request(path)
        rows = page.get("data", [])
        while page.get("links", {}).get("next"):
            page = self.request(page["links"]["next"])
            rows.extend(page["data"])
        return rows

    def check_app(self, app_id, bundle_id):
        app = self.request(f"/v1/apps/{app_id}")["data"]
        if app["attributes"]["bundleId"] != bundle_id:
            raise ValueError("App ID and bundle ID mismatch; refusing operation")
        return app

    def check_version(self, app_id, version_id):
        versions = self.rows(f"/v1/apps/{app_id}/appStoreVersions", {"limit": 200})
        version = next((v for v in versions if v["id"] == version_id), None)
        if not version:
            raise ValueError("Version does not belong to the exact target app")
        state = version["attributes"].get("appVersionState") or version["attributes"].get("appStoreState")
        if state not in EDITABLE:
            raise ValueError(f"Version is not editable: {state}; live versions are protected")
        return version

    def bytes(self, url, *, method="GET", headers=None, data=None):
        if urllib.parse.urlparse(url).scheme != "https":
            raise ValueError("Asset delivery/upload requires HTTPS")
        request = urllib.request.Request(url, method=method, headers=headers or {}, data=data)
        # Signed asset URLs are deliberately requested without API authorization.
        try:
            with urllib.request.urlopen(request, context=self.context, timeout=120) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            raise APIError(f"Asset transfer HTTP {error.code}; signed URL omitted") from None


def upload_parts(client, operations, image):
    # Bind the transfer to the reviewed bytes, not just an earlier filesystem
    # inspection. Keep that verified immutable buffer for every part.
    data = Path(image["path"]).read_bytes()
    if len(data) != image["fileSize"] or hashes(data) != {"md5": image["md5"], "sha256": image["sha256"]}:
        raise ValueError("Reviewed bytes changed immediately before upload")
    ranges = []
    for operation in operations:
        offset, length = operation.get("offset"), operation.get("length")
        if type(offset) is not int or type(length) is not int or offset < 0 or length <= 0 or offset + length > len(data):
            raise ValueError("Upload operation has an invalid or out-of-bounds byte range")
        ranges.append((offset, offset + length))
    ranges.sort()
    if not ranges or ranges[0][0] != 0 or ranges[-1][1] != len(data) or any(a[1] != b[0] for a, b in zip(ranges, ranges[1:])):
        raise ValueError("Upload operations must cover the file exactly, without gaps or overlaps")
    for operation in operations:
        offset, length = operation["offset"], operation["length"]
        part = data[offset:offset + length]
        if len(part) != length:
            raise ValueError("Upload slice does not match the declared part length")
        headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
        client.bytes(operation["url"], method=operation["method"], headers=headers, data=part)


def library_complete(client, image_id, image):
    deadline = time.monotonic() + 360
    while time.monotonic() < deadline:
        resource = client.request(f"/v1/appAssetLibraryImages/{image_id}")["data"]
        attrs = resource["attributes"]
        if attrs["state"] in {"COMPLETE", "PREPARE_FOR_SUBMISSION", "APPROVED", "ACCEPTED"}:
            asset = attrs.get("imageAsset") or {}
            # The backend can enter its review state before asynchronous image
            # classification fields are populated. Wait for those fields rather
            # than treating a temporarily absent spec/image as a mismatch.
            if not attrs.get("specId") or not asset.get("width") or not asset.get("height") or not (asset.get("templateUrl") or asset.get("url")):
                time.sleep(2)
                continue
            if attrs["fileSize"] != image["fileSize"] or attrs["specId"] not in image["acceptedSpecIds"]:
                raise ValueError("Processed Asset Library size/spec does not match the reviewed file")
            if [asset.get("width"), asset.get("height")] != image["size"]:
                raise ValueError("Processed dimensions do not match the reviewed file")
            # This modern endpoint exposes a review state, not the legacy
            # assetDeliveryState/sourceFileChecksum fields. A review state alone
            # is insufficient: verify Apple's classified, full-resolution CDN
            # image against the exact reviewed source pixels before accepting it.
            resource["verification"] = verify_library_pixels(client, resource, image)
            return resource
        if attrs["state"] in {"FAILED", "REJECTED", "ARCHIVED"}:
            raise ValueError(f"Asset Library image failed: {image_id}")
        time.sleep(2)
    raise TimeoutError("Asset Library processing did not complete")


def verify_library_pixels(client, resource, image):
    source = Path(image["path"]).read_bytes()
    if len(source) != image["fileSize"] or hashes(source) != {key: image[key] for key in ("md5", "sha256")}:
        raise ValueError("A reviewed local image changed before processed-image verification")
    asset = resource["attributes"]["imageAsset"]
    url = asset.get("templateUrl") or asset.get("url")
    if not url:
        raise ValueError("Processed Asset Library image has no full-resolution delivery URL")
    for name, value in {"w": image["size"][0], "h": image["size"][1], "c": "", "f": "png"}.items():
        url = url.replace("{" + name + "}", str(value))
    delivered = client.bytes(url)
    def decoded_hash(data, *, is_delivered=False):
        with Image.open(io.BytesIO(data)) as decoded:
            if list(decoded.size) != image["size"]:
                raise ValueError("Full-resolution delivered image dimensions differ from the reviewed source")
            if is_delivered and decoded.format != "PNG":
                raise ValueError("Full-resolution delivery is not the requested native PNG")
            if getattr(decoded, "n_frames", 1) != 1 or decoded.getexif().get(274, 1) != 1:
                raise ValueError("Processed image must contain one upright frame")
            if decoded.convert("RGBA").getchannel("A").getextrema() != (255, 255):
                raise ValueError("Processed image must be fully opaque")
            return hashlib.sha256(decoded.convert("RGB").tobytes()).hexdigest()
    source_hash, delivered_hash = decoded_hash(source), decoded_hash(delivered, is_delivered=True)
    if source_hash != delivered_hash:
        raise ValueError("Full-resolution delivered image pixels differ from the reviewed source")
    return {"verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "sourceSHA256": image["sha256"], "sourceMD5": image["md5"],
            "decodedRGBSHA256": source_hash, "deliveredSHA256": hashes(delivered)["sha256"],
            "deliveredFileSize": len(delivered), "exactDecodedMatch": True,
            "uprightOpaqueSingleFramePNG": True,
            "note": "Apple may transcode PNG encoding; full-resolution decoded RGB pixels match exactly."}
