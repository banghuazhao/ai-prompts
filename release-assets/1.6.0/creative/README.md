# AI Prompts App Store creative

- Final asset: `ai-prompts-universal-header-search-v2.png`
- Original exploration: `ai-prompts-universal-header-search.png` (retained locally and in Asset Library).
- Placements: product page Header and Search Results
- Export: 5244 × 2950 pixels, opaque RGB PNG
- Created with the built-in imagegen tool on October 29, 2026; deterministically resized to Apple's exact universal export size with `sips`.
- Reference: app icon concept and existing app palette. The artwork illustrates the product's writing, learning, and coding prompt use cases; it does not depict an app screenshot.

Version 2 is the final approved release asset. A later enlargement experiment failed the official safe-area check and was discarded without uploading; it is not part of this release folder.

## App Store upload

Uploaded to the English (U.S.) localization of draft version 1.6.0 in both Header and Search Results placements. The PNG was processed, classified under Apple's universal creative asset specification, and downloaded at its native resolution. Its decoded RGB pixels match the reviewed source exactly. Final verification and placement IDs are recorded in `upload-v2-journal.json`; the original exploration's separate journal and image remain available. The version remains a draft; this workflow does not submit it for review.

Apple's [official universal Photoshop template](https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-universal_asset_template-static.psd) defines an `Art Safe Area` layer at x1921–3323, y660–1622 on its 5244 × 2950 canvas. The final compact central bulb, title, and tagline sit within this area; the outer decorative cards may crop. `v2-safe-area-verification.json` records template metadata and measured core bounds. The original wide composition was corrected after checking this template. The exact two task-owned placements were replaced only after the new original passed full-resolution verification, and the old image was retained for recovery. Iterative built-in imagegen prompts are saved in `v2-prompts.txt`.

The reusable uploader at `Tools/asc-add-assets.py` uses bundled `Tools/asc-client.py` helpers. Install PyJWT, cryptography, certifi, and Pillow in the Python environment and set `ASC_ISSUER_ID`, `ASC_KEY_ID`, and `ASC_PRIVATE_KEY`. Run from the repository root:

```sh
python3 Tools/asc-add-assets.py \
  --manifest release-assets/1.6.0/creative/upload-v2-manifest.json \
  --journal release-assets/1.6.0/creative/upload-v2-journal.json
```

The default command validates without changing remote assets. Add `--execute` to upload verified originals and add placements. Existing untracked assets are always preserved; the command refuses to replace them. An explicit `replaceOwnedPlacementsFromJournal` manifest can correct only exact placements from a prior completed journal for the same app/version, preserving all old images and recording recovery IDs. Credentials and transfer URLs are never written to journals. The same uploader accepts `APP_SCREENSHOT` / `IPHONE_DUO_PROFILE` groups for native Duo screenshots.

## Generation prompt

Use case: ads-marketing.
Asset type: App Store universal creative asset for product page Header and Search Results, landscape 5244 x 2950 PNG, about 16:9.
Primary request: Design a refined, memorable promotional artwork for the app AI Prompts. Use the supplied app screenshot only as a reference for the app's visual brand, and the supplied lightbulb icon only as conceptual reference for the bulb-and-speech-bubble symbol. Create a fresh marketing illustration, not a phone screenshot or a fabricated app screen.
Scene/backdrop: rich deep ink navy #131430 with a controlled violet #664FE3 luminous sweep, subtle cyan #64E0F5 light, matte background with very fine soft grain. Clean editorial software art direction.
Composition: comfortably spacious landscape. Essential content inside the central safe rectangle between 18% and 82% of width and between 28% and 72% of height, so it crops gracefully into a wide header and a search card. At left of that central rectangle, bold beautiful white sans-serif typography reading exactly "AI Prompts" with a smaller second line "Find your next idea." At right, a sculptural cyan glass lightbulb intertwined with a simple rounded speech bubble, flanked by three restrained floating pale-lavender prompt cards with fine violet line icons: a pencil, an open book, and code brackets. The cards may have a few short purely abstract horizontal rules, NO small readable text. This motif must clearly communicate a library of ideas for writing, learning, and coding. Grounded soft shadows, tactile glass, subtle layered depth, excellent large-format finish. Balance the bold type with the luminous symbol, no busy decoration. Wide margins and empty space above and below central content.
Text (verbatim): "AI Prompts" and "Find your next idea."
Constraints: no phones or other devices, no actual screenshot UI, no third-party logos, no third-party product or platform names, no pricing, no awards, no URL, no badges, no watermark, no copyright. Do not reproduce the watermark on the reference image. Ensure exact spelling and legibility. Opaque background, no transparency.
