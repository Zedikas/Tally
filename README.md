# Tally

**Tally** is a clean, native SwiftUI multi-counter app for iPhone.

It is designed as a polished but reliable app: multiple counters, groups, history, stats, export/import, themes, and interchangeable app icons without fragile extension targets. The app intentionally stays single-target for now so it can build and sideload more reliably than the extension-heavy Universal Downloader experiments.

## Repository description

A polished SwiftUI multi-counter app for iPhone with grouped counters, goals, stats, history, export/import, OLED mode, and interchangeable icons.

## v1.2 features

- New Stats tab
- Stats ranges: Today, 7 days, 30 days, and all time
- Daily summary cards
- Top counters by selected activity range
- Goal completion overview
- Streak insights based on consecutive days with positive counter activity
- History search improvements
- History filters: All, Today, Last 7 Days, Positive, Negative, and Resets
- Version bump to v1.2 build 3

## v1.1 features

- Counter search by name, group, and notes
- Sort counters manually, by recent update, by name, or by value
- Counter templates for common use cases
- Duplicate counters
- Move counters up/down from the card menu
- Import JSON backups
- Merge imported backups into existing data
- Replace current data with an imported backup

## v1.0 features

- Multiple named counters
- Counter groups/folders
- Optional goals and progress bars
- Fast actions: `-1`, `+1`, `+5`, `+10`, `+100`
- Reset and undo
- History timeline with before/after values
- JSON backup export
- CSV history export
- Light, dark, system, and OLED black themes
- Interchangeable icon family inspired by Universal Downloader
- XcodeGen-based project setup
- Unsigned IPA GitHub Actions workflow triggered by `(!F)`

## Project structure

```text
Tally/
├── Tally/                  # SwiftUI app source
├── Tally/Resources/        # Info.plist, assets, launch screen
├── Scripts/                # Icon generator
├── docs/                   # Roadmap and notes
├── project.yml             # XcodeGen project spec
└── .github/workflows/      # Unsigned IPA build workflow
```

## Build locally

Install XcodeGen first:

```bash
brew install xcodegen
```

Generate the icon assets and Xcode project:

```bash
swift Scripts/generate_icons.swift
xcodegen generate --spec project.yml
```

Build the app:

```bash
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

The workflow builds an unsigned IPA when run manually or when the latest commit message contains:

```text
(!F)
```

The artifact name is:

```text
Tally_v1_2_unsigned_ipa
```

## Icon system

The repo includes a programmatic icon generator instead of committing large binary icon files. The generator creates:

- Primary AppIcon assets
- Classic Blue
- Neon Dark
- Glass
- Pearl
- Amber
- Tech Green
- Cosmic Purple
- Synthwave

All variants use the same simplified, meaningful symbol: a single handheld tally counter with a display and one press button.

## Roadmap

See [`docs/ROADMAP.md`](docs/ROADMAP.md). Future features should stay single-target until the core app is stable. Widgets, App Intents, Live Activities, and iCloud sync should come later only when signing is solved cleanly.