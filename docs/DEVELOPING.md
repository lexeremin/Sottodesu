# Developing Sottodesu

A small SwiftUI app for macOS 15+. One dependency: [GRDB.swift](https://github.com/groue/GRDB.swift) (SQLite).

## Build and run

You need Xcode 16 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The Xcode project is generated from `project.yml` and is not checked in.

```sh
brew install xcodegen
xcodegen generate
open Sottodesu.xcodeproj
```

Press ⌘R to run and ⌘U to test, or from the terminal:

```sh
xcodebuild test -scheme Sottodesu -destination 'platform=macOS'
```

The project signs ad hoc, which is fine for running locally. macOS may ask for Downloads access again after each rebuild.

## Project layout

| File | Role |
|---|---|
| `Sorter.swift` | Categories (extensions, localized folder names) and the move logic |
| `HistoryStore.swift`, `HistoryReport.swift` | SQLite history and the report queries |
| `Reverter.swift` | Undo |
| `DownloadsScanner.swift` | Measures Downloads for the size report and Largest Files |
| `AppModel.swift` | State and actions behind the UI |
| `ContentView.swift`, `ReportView.swift`, `LargestFilesView.swift` | The three tabs |
| `Components.swift`, `Theme.swift` | Shared views, colours, formatting |
| `Localization.swift` | Looks strings up in every shipped language |
| `DemoMode.swift` | Made-up data for screenshots (`--demo`) |
| `Uninstaller.swift`, `AppPaths.swift` | Clean removal; every path the app touches |
| `Localizable.xcstrings`, `InfoPlist.xcstrings` | All translations |
| `Tools/make_icon.py` | Draws the app icon set (needs Pillow) |
| `Scripts/build-dmg.sh` | Builds the installer disk image |
| `Scripts/take-screenshots.sh` | Takes the README screenshots in demo mode |

### Design rules worth keeping

- **Footprint:** the app writes one file (the history database) and nothing else — no preferences, no saved window state, no caches. Keep it that way; `AppPaths.swift` lists every location.
- **Never overwrite, never delete.** Sorting and undo only move files, and they skip rather than clobber.
- **The database stores stable English category identifiers** (`FileCategory.rawValue`, e.g. `"Images"`), never translated names, so changing language never breaks the history. Translate only for display (`Localized.string(id)`) and for folder names on disk.

## Screenshots

The images in `docs/screenshots/` are generated, not hand-made, so they can be refreshed whenever the UI changes:

```sh
Scripts/take-screenshots.sh
```

It builds the app, launches it in **demo mode** (`Sottodesu --demo --tab sort|report|largest`, which uses invented data in a temporary folder and never touches your real Downloads or history) in light and dark appearance and in every language, and saves the window with `screencapture`. The first run asks for Screen Recording permission for your terminal. Don't touch the keyboard or mouse while it runs. Commit the updated PNGs.

## Languages

Shipped: English (source), Русский (`ru`), 简体中文 (`zh-Hans`), 한국어 (`ko`), 日本語 (`ja`), Français (`fr`).

Folder names on disk follow the system language. The **Keys & Secrets** folder is created with owner-only permissions (0700). To keep existing folders working after a language change, the app treats a folder in **any** shipped language as that category's folder (`FileCategory.knownFolderNames`) and reuses whichever exists.

### Adding or fixing a translation

All text lives in `Sottodesu/Localizable.xcstrings` (a String Catalog, plain JSON). Keys are the English text.

- **Fix a string:** open the file in Xcode (it shows a table) or edit the JSON, and send a pull request.
- **Add a language:**
  1. In Xcode, select `Localizable.xcstrings` and click **+** at the bottom of the language list; do the same for `InfoPlist.xcstrings`.
  2. Translate every row. Strings with `%lld` have **plural variants** — fill in every form your language needs (Russian needs *one / few / many / other*).
  3. The **category names** (`Images`, `Documents`, `3D Models`, …) are also the **folder names** created on disk: keep them short, make sure no two categories share a name, and don't use `/` or `:`. A unit test checks this.
  4. Add the language code to `CFBundleLocalizations` in `project.yml`, then run the tests.

## Releasing

Releases are built by GitHub Actions. To publish version 1.2.3:

```sh
git tag v1.2.3
git push origin v1.2.3
```

The *Release* workflow builds the app, makes `Sottodesu-1.2.3.dmg`, and creates the GitHub release with the disk image attached and auto-generated notes. The tag decides the version number. Update `CHANGELOG.md` first.

To build the installer locally instead: `Scripts/build-dmg.sh 1.2.3` → `build/Sottodesu-1.2.3.dmg`.

### Signing and notarization (optional)

Without an Apple Developer ID the app is signed ad hoc, which is why users have to click *Open Anyway* the first time. With a paid Apple Developer account you can remove that step:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="my-notary-profile" \
Scripts/build-dmg.sh 1.2.3
```

`NOTARY_PROFILE` is created once with `xcrun notarytool store-credentials`. Making the GitHub workflow do this needs the certificate and notary credentials stored as repository secrets — not set up yet.
