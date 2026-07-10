# Tally

**Tally** is a clean, native SwiftUI multi-counter app for iPhone.

It is designed as a polished but reliable app: multiple counters, sessions, collapsible folders, history, stats, safer counter management, export/import, themes, accent colors, and interchangeable app icons without fragile extension targets. The app intentionally stays single-target so it can build and sideload reliably without extension signing files.

## Repository description

A polished SwiftUI multi-counter app for iPhone with timed sessions, collapsible folders, exact value entry, goals, stats, archive-safe management, export/import, OLED mode, accent colors, and interchangeable icons.

## v1.5 features

- Tap a counter’s large value to enter an exact whole number with the numeric keyboard
- Exact value changes are recorded in History and support Undo
- Counter groups now behave as collapsible folders
- Folder expanded/collapsed state is remembered between launches
- Expand All and Collapse All actions
- Clear reminder icons: 1 for daily, 7 for weekly, and 30 for monthly
- Color-picker icons and names are tinted using their actual colors
- Human-readable symbol names instead of raw SF Symbol identifiers
- Global accent-color setting inspired by Universal Downloader
- Accent color applies to tab selection, buttons, pickers, and navigation controls
- Version bump to v1.5 build 6

## v1.4 features

- New Sessions tab
- Start timed sessions linked to a counter or as standalone sessions
- Active session timers update while the Sessions screen is open
- End sessions with duration, start value, end value, and delta summaries
- Start or end a linked session directly from a counter card menu
- Export sessions as CSV
- JSON backups include sessions
- Per-counter reset reminder metadata

## Earlier releases

- **v1.3:** archive management, custom step buttons, and import previews
- **v1.2:** stats dashboard, summaries, streaks, and history filters
- **v1.1:** search, sorting, templates, duplication, movement, and JSON import
- **v1.0:** multiple counters, groups, goals, history, exports, themes, and alternate icons

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
Tally_v1_5_unsigned_ipa
```

## Icon system

The repo includes a programmatic icon generator instead of committing large binary icon files. The generator creates the primary icon plus Classic Blue, Neon Dark, Glass, Pearl, Amber, Tech Green, Cosmic Purple, and Synthwave alternatives.

## Roadmap

See [`docs/ROADMAP.md`](docs/ROADMAP.md). Widgets, App Intents, Live Activities, Watch support, and other extension targets remain postponed until the required signing assets are available.