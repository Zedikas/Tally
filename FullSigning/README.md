# Tally 2.0 signing configurations

Tally now has two XcodeGen specifications so entitlement-dependent features never destabilize the unsigned AppDB build.

## AppDB-safe unsigned build

Generate with:

```bash
xcodegen generate --spec project.yml
```

This produces the single-target `Tally` app used by `.github/workflows/build-unsigned-ipa.yml`.

Included:

- Counters, folders, drag-and-drop, pinning, sessions, history and statistics
- Local persistence and versioned backup migration
- JSON, CSV and `.tallysync` file exchange
- Local reset notifications
- Main-application App Intents and Shortcuts
- Alternate app icons

It intentionally contains no embedded `.appex`, App Group, iCloud or CloudKit entitlement.

## Full-signing build

Generate with:

```bash
xcodegen generate --spec project-full.yml
```

This adds:

- Home Screen and Lock Screen widgets
- Session Live Activities and Dynamic Island UI
- App Group data sharing
- Private CloudKit backup synchronisation

A compatible Apple Developer provisioning profile must contain the App Group and iCloud container declared in the entitlements files. Replace the sample identifiers when using another bundle identifier or development team.

The unsigned IPA workflow always validates that these extension targets and entitlements are absent from the AppDB-safe application bundle.
