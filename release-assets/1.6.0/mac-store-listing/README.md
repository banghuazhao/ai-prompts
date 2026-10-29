# AI Prompts for Mac: App Store listing

Listing text for the **macOS App** version in App Store Connect (en-US). App name, subtitle, category and privacy details are shared with iOS under App Information, so only the per-version fields are here. The machine-readable copy is [`listing.json`](listing.json).

Screenshots: [`../screenshots/en-US/mac/`](../screenshots/en-US/mac/) (2880 × 1800, Mac placement `MAC_PROFILE`).

## Promotional Text (161/170)

Now on Mac: more than 200 ready-to-use AI prompts and 50+ vibe coding ideas in a roomy sidebar layout. Fill in the blanks, copy, and paste into any AI assistant.

## Description (2412/4000)

```text
AI Prompts brings a curated library of ready-to-use prompts to your Mac. Find the right prompt for writing, learning, coding and creative work, fill in the blanks, and paste it into ChatGPT, Claude, Gemini or any AI assistant you use.

MADE FOR THE MAC
• A sidebar for Prompts, Vibe Prompts, Favorites, More and Search
• Prompts sit in a comfortable reading column, even in a large window
• Your library lives on your Mac, so browsing works offline
• No ads

A LIBRARY OF IDEAS
• More than 200 curated prompts, organized by category
• Vibe Prompts: 50+ ready-to-build ideas for apps, games and tools, tagged by tech stack
• New prompts arrive without an app update, marked NEW
• Create your own prompts, edit, duplicate and sort them into categories

FILL-IN-THE-BLANK TEMPLATES
• Prompts with blanks like {{topic}} open Customize & Use, with a live preview as you type
• Values you enter are remembered for the same blank next time
• Copy the finished prompt, or open it in your favorite assistant in one click

APPLE INTELLIGENCE ON YOUR MAC
On Macs with Apple Intelligence (macOS 26 or later):
• Run any prompt on device with Apple's Foundation Models: private, free and offline. Ask follow-ups, and find past conversations under Favorites › Chats
• Describe what you need in plain language and get the best matching prompts from the library
• Generate new prompt ideas, get suggestions for every blank, and let it suggest a title and category for prompts you add

FIND IT FAST
• Search matches every word you type, in any order, ignoring case and accents, across titles, categories, tech stacks and contributors
• Favorites, a Recently Used shelf and a Most Used sort keep your go-to prompts close
• Surprise Me opens a random prompt when you want inspiration

WRITE BETTER PROMPTS
• Check Prompt gives quick tips on clarity, length, repetition, output format and structure
• See each prompt's size in words and estimated tokens
• Translate a prompt into your language in place (macOS 26 or later)
• Built-in guides to prompt engineering and context engineering

YOUR DATA, YOUR FILE
• Export your prompts, favorites, categories and chats to a backup file, and restore it on any device. Restoring adds to your library and never deletes anything.

AI Prompts is not affiliated with OpenAI, Anthropic, Google or any other AI provider. Assistant names are used only to describe where you can paste your prompts.
```

## Keywords (96/100)

```text
library,writing,coding,vibe,template,assistant,LLM,chatbot,ideas,generator,engineering,study,mac
```

Words already in the app name (AI, Prompt, Prompts, Directory) are left out, since Apple indexes the name.

## Support and Marketing URL

Copied from the iOS 1.6.0 listing by the script below (they are not stored in the repo).

## Fill it in with the API

Uses the same credentials as the other tools: `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_PRIVATE_KEY` (path to the `.p8`). Run from the repository root. Without `--execute` nothing changes.

```sh
python3 Tools/asc-update-listing.py \
  --listing release-assets/1.6.0/mac-store-listing/listing.json \
  --screenshot-manifest release-assets/1.6.0/screenshots/mac-upload-manifest.json \
  --screenshot release-assets/1.6.0/screenshots/en-US/mac/01-library.png \
  --screenshot release-assets/1.6.0/screenshots/en-US/mac/02-vibe-library.png \
  --screenshot release-assets/1.6.0/screenshots/en-US/mac/03-search.png
```

Add `--execute` to save the text. Then add the screenshots with the verified uploader (dry run first, then `--execute`):

```sh
python3 Tools/asc-add-assets.py \
  --manifest release-assets/1.6.0/screenshots/mac-upload-manifest.json \
  --journal release-assets/1.6.0/screenshots/mac-upload-journal.json
```

Neither tool submits the version for review.

## Before submitting the macOS version

- The Mac binary is the same target built for Mac Catalyst with the iOS bundle ID (universal purchase). Archive with **Any Mac (Mac Catalyst)** in Xcode and upload; Xcode creates the Mac Catalyst signing profiles on first archive.
- Version numbers: the macOS draft is **1.0** in App Store Connect while the project's `MARKETING_VERSION` is shared with iOS. Rename the macOS version to match the build you upload (for example 1.6.0).
- The Mac app shows no ads and no tracking prompt, and doesn't offer the ad-removal Premium upgrade. A Premium purchase made on iPhone or iPad still shows as Premium on Mac.
