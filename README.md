# Sottodesu

A tiny, native macOS app that sorts your **Downloads** folder into subfolders by file type
(Images, Videos, Audio, Documents, Archives, Installers, Other) — and remembers every sort so you can undo it.

- One window, one button.
- Every sort is saved like a commit: when it ran, and every file it moved. Undo any sort later.
- Only touches the top level of `~/Downloads`. Folders, hidden files, symlinks, and files that are still
  downloading (`.crdownload`, `.download`, `.part`, or modified in the last few seconds) are left alone.
- Never overwrites: name clashes become `photo 2.jpg`, and undo refuses to overwrite anything.

## Footprint

The history is a single SQLite file: `~/Library/Application Support/Sottodesu/history.sqlite`.
Nothing else is written on purpose (no preferences, no window-state restoration, no caches, no login item).

macOS has no uninstall hook, so dragging the app to the Trash cannot remove that file by itself.
Use **Sottodesu ▸ Uninstall Sottodesu…** instead: it deletes the history, clears anything macOS may have
generated for the app, and moves the app to the Trash. Files you already sorted stay where they are.

## Build

Requirements: macOS 15+, Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Sottodesu.xcodeproj
```

Run the `Sottodesu` scheme. The project signs ad hoc by default, which is fine for running locally
(macOS may ask for Downloads access again after a rebuild). To distribute it, set your team in the target's
Signing settings and notarize.

Run the tests with **⌘U** in Xcode, or:

```sh
xcodebuild test -scheme Sottodesu -destination 'platform=macOS'
```

The only dependency is [GRDB.swift](https://github.com/groue/GRDB.swift) (SQLite).

## Layout

| File | Role |
|---|---|
| `Sorter.swift` | Categories and the move logic |
| `HistoryStore.swift` | SQLite history (runs and moved files) |
| `Reverter.swift` | Undo |
| `AppModel.swift` | State and actions for the UI |
| `ContentView.swift`, `SottodesuApp.swift` | SwiftUI window |
| `Uninstaller.swift`, `AppPaths.swift` | Clean removal |
