# Tally

**Tally** is a native SwiftUI multi-counter app for iPhone built as a reliable single-target project.

It includes multiple counters, timed sessions, collapsible folders, detailed analytics, history, archive-safe management, export/import, themes, custom accents, and interchangeable app icons without extension-signing requirements.

## v1.6 features

- Dedicated detail page for every counter
- Quick actions, notes, milestones, recent history, and a 30-day activity chart
- Pin counters into a Favorites section
- Lock counters against accidental increments, exact-value edits, and resets
- Folder colors, counter counts, and combined folder totals
- Smart automatic daily, weekly, or monthly resets when Tally opens
- Configurable per-counter milestones with celebration history entries
- Expanded symbol library with readable names
- Full-page counter, folder-color, and symbol selectors instead of displaced popovers
- Redesigned Settings with dedicated Appearance and App Icon pages
- Preset accent themes plus a native custom color picker
- App icon gallery with larger previews and selection checkmarks
- Backward-compatible decoding for all v1.0–v1.5 backups
- JSON backups upgraded to version 1.6
- Version bump to v1.6 build 8

## v1.5 features

- Exact value entry from the counter overview
- Collapsible folders with remembered state
- Clear 1, 7, and 30 reset icons
- Human-readable symbol labels
- Global accent-color setting
- True-color picker representation

## Earlier releases

- **v1.4:** timed sessions, session summaries, CSV export, and reset schedules
- **v1.3:** archive management, custom step buttons, and import previews
- **v1.2:** stats dashboard, summaries, streaks, and history filters
- **v1.1:** search, sorting, templates, duplication, movement, and JSON import
- **v1.0:** counters, groups, goals, history, exports, themes, and alternate icons

## Project structure

```text
Tally/
├── Tally/                  # SwiftUI app source
├── Tally/Resources/        # Info.plist, assets, launch screen
├── Scripts/                # Icon generator
├── docs/                   # Roadmap and notes
├── project.yml             # XcodeGen project spec
└── .github/workflows/      # Unsigned IPA workflow
```

## Build locally

```bash
brew install xcodegen
swift Scripts/generate_icons.swift
xcodegen generate --spec project.yml
xcodebuild \
  -project Tally.xcodeproj \
  -scheme Tally \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## GitHub Actions IPA build

The unsigned IPA workflow runs manually or when a commit message contains:

```text
(!F)
```

The v1.6 artifact is:

```text
Tally_v1_6_unsigned_ipa
```

## Signing boundary

Widgets, App Intents extensions, Live Activities, Watch support, and other extra targets remain postponed until the required bundle identifiers, entitlements, and provisioning assets are available.
