# Changelog

All notable changes to Sottodesu are listed here.

## 1.4.0 — 2026-10-28

- **Updates.** Sottodesu checks GitHub about once a day for a newer release and shows a banner (and a notification if it is in the menu bar). **Update and Relaunch** downloads the release, verifies its checksum, swaps the app and reopens it. You can skip a version, postpone it, or switch automatic checks off in **Sottodesu ▸ Settings…** (⌘,). **Check for Updates…** is in the app menu.
- **More config files.** `xml`, `rc`, `json`, `jsonc`, `json5`, `properties`, `cnf`, `config`, `xcconfig` and `reg` now go to **Config & VPN** along with the formats that were already there.

## 1.3.0 — 2026-10-28

- **Schedules now run inside the app.** macOS blocks background items from apps without an Apple Developer signature, so Sottodesu checks for due schedules itself every minute (and after waking from sleep) while it is open or kept in the menu bar. New switches on the Schedule tab: **Keep running in the menu bar** and **Open at login**.
- A clearer **Schedule editor**: folder cards, weekday and day-of-month buttons, and a big time field with hour and minute popups. Schedule cards have Run, Edit and Delete buttons.
- **Check Now** on the Schedule tab, with a plain-language result ("Nothing is due yet. Next: …"), so you can see what the scheduler is doing.
- A menu bar icon that matches the app icon.
- The history search box no longer grabs the cursor when the window opens.
- Removes the test background item from earlier builds.

## 1.2.0 — 2026-10-28

- **Schedule tab:** tidy a folder up automatically every day, week or month. Sottodesu runs the schedules while it is open or kept in the menu bar (with an optional *Open at login*). Automatic sorts appear in the history, marked *Scheduled*, and can be undone. Includes a pause switch.
- **Preview** what a sort would move before anything moves, and untick files you want to keep in place.
- **Search history** to find where a single file went, and restore just that file or just one type from a sort.

## 1.1.0 — 2026-10-28

- Easy install: open the disk image and Sottodesu offers to move itself to Applications, then ejects the installer and moves the downloaded `.dmg` to the Trash. Drag-to-install still works.
- One-command install from Terminal, with no Gatekeeper warning.
- The app is built with Xcode 26, so it has the current macOS look.
- Screenshots and an updated guide in the README.

## 1.0.0 — 2026-10-28

First public version.

- Sort your Downloads folder into folders by file type with one button; loose folders go into *Projects*.
- Hidden "dot" files are sorted too — into *Config & VPN*, or into a private *Keys & Secrets* folder when they hold credentials (`.env`, certificates, SSH keys…). Hidden folders and macOS's own hidden files are left alone.
- Choose where to sort — Downloads, Desktop, your home folder (restricted to loose media and documents: photos, videos and music go to Pictures, Movies and Music, the rest into Documents) or any folder you pick — and which kinds of files to sort.
- Every sort is saved to a history and can be undone, completely and safely (nothing is ever overwritten).
- Report tab: sort statistics, a breakdown by category, and a chart of what takes space in Downloads.
- Largest Files tab: the biggest files in Downloads; double-click to show one in Finder.
- English, Russian, Simplified Chinese, Korean, Japanese and French; the folders it creates are named in your language.
- Drag-to-install disk image, built automatically for every release.
