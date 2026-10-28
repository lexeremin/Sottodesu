# Troubleshooting

Find your problem below. If it isn't here, [open an issue](https://github.com/lexeremin/Sottodesu/issues/new) and tell me what you saw — a screenshot helps.

## macOS says Sottodesu "cannot be opened" or "could not be verified"

This is expected the first time. Sottodesu isn't registered with Apple (that costs money), so macOS wants you to approve it once.

1. Click **Done** in the warning. Don't click *Move to Trash*.
2. Open **System Settings ▸ Privacy & Security**.
3. Scroll down to **Security** and click **Open Anyway** next to *"Sottodesu was blocked…"*.
4. Confirm with your password or Touch ID, then click **Open**.

Don't see *Open Anyway*? It only appears for about an hour after your last attempt. Try opening Sottodesu again, then go straight back to *Privacy & Security*.

Terminal alternative:

```sh
xattr -dr com.apple.quarantine /Applications/Sottodesu.app
```

If you opened the app straight from the disk image instead of from Applications, drag it to **Applications** first.

## "Sottodesu can't access this folder"

macOS asks for permission the first time Sottodesu touches your Downloads folder, your Desktop or your Documents folder. If you clicked *Don't Allow* (or missed the question), turn it on here:

**System Settings ▸ Privacy & Security ▸ Files & Folders ▸ Sottodesu** and switch on the folder in question (Downloads Folder, Desktop Folder or Documents Folder). For a folder on an external drive, switch on *Removable Volumes*.

If Sottodesu isn't in that list, quit it, open it again and press **Sort Downloads** — the question should come back. If it doesn't, run this in Terminal and try again:

```sh
tccutil reset SystemPolicyDownloadsFolder dev.sottodesu.app
tccutil reset SystemPolicyDesktopFolder dev.sottodesu.app
tccutil reset SystemPolicyDocumentsFolder dev.sottodesu.app
```

## I pressed Sort and "Nothing to sort"

That means there was nothing to move. Common reasons:

- Your Downloads folder is already sorted.
- The files are **still downloading** or were **added in the last few seconds**. Wait a moment and press Sort again.
- The only things left are **apps**, **hidden folders**, **symbolic links** or macOS's own hidden files (`.DS_Store`, `.localized`). Sottodesu leaves those alone.
- Sottodesu sorts what is **directly inside** Downloads. It doesn't reach into folders it didn't create — but it does move those whole folders into **Projects**.

## A file didn't move

See the list above. Also: Sottodesu skips anything that is still being written (`.crdownload`, `.download`, `.part` and similar). Once the download finishes, sort again.

## Where did my hidden files (like `.env` or `.gitignore`) go?

Sottodesu sorts hidden "dot" files too: into **Config & VPN**, or into **Keys & Secrets** if they hold credentials (`.env`, `.npmrc`, certificates, SSH keys…). They stay hidden after they move — press **⌘⇧.** (Command-Shift-Period) in Finder to show hidden files. Open the **History** card of the sort to see exactly where each one went, and **Undo** puts them back.

Hidden *folders* (like `.git` or `.ssh`) are never moved.

## Undo says some items "couldn't be restored"

Sottodesu never overwrites anything. When undoing, it skips an item if:

- you've **moved or deleted it** since the sort — there's nothing left to restore, or
- **something new already sits at its original place** with the same name. Rename or move that one, then undo again.

## My folders are in a different language than I expected

Sottodesu names the folders it creates in your Mac's current language (System Settings ▸ General ▸ Language & Region). Folders it created earlier keep their names, and it keeps using them — it recognises all six supported languages, so you never get duplicates. If you'd like to switch an old folder to the new language, just rename it in Finder; Sottodesu will still recognise it.

## The Report or Largest Files tab is empty or slow

Both tabs measure your whole Downloads folder when you open them. A very large folder can take a few seconds — there's a progress indicator while it works. Press **Rescan** (⌘R) to measure again. The *Largest Files* list shows the biggest 500 files.

## I can't choose a folder

Sottodesu refuses folders where sorting could do real damage: system folders, the Applications folder, a whole disk, your **Library**, apps, and hidden folders (names starting with a dot). To tidy your home folder itself, use the **Home** card — it works differently on purpose (see below).

## Why does Home only move a few things?

Your home folder is full of settings and data that apps depend on, so Sottodesu keeps to the safe part: loose **media and documents** sitting directly in it. Photos go to **Pictures**, videos to **Movies**, music to **Music**, and documents, books, archives, installers, 3D models and design files into **Documents**. Folders, hidden files (`.zshrc`, `.ssh`…), code, databases, configuration files, keys and secrets, fonts and apps are never touched. If you want more, sort a specific folder with **Choose Folder…**.

## Sottodesu asked whether I'm sure about a folder

When the folder you picked contains things like `.git`, `package.json`, `Package.swift` or an Xcode project, it's probably a software project. Sorting moves its files into subfolders by type, which can break it. Say **Cancel** unless that's really what you want — and remember **Undo** puts everything back.

## Where does Sottodesu keep its data? How do I remove everything?

Only here: `~/Library/Application Support/Sottodesu/history.sqlite` (your history and your last choices — which folder and which file types).

That one file also holds your schedules. Dragging the app to the Trash does **not** delete it, so a reinstall remembers everything. Use **Sottodesu ▸ Uninstall Sottodesu…** to delete it, take Sottodesu out of your login items and move the app to the Trash in one go. Files you already sorted stay where they are. Note that after uninstalling you can no longer undo past sorts.

To remove every trace by hand, including the small files macOS may add and the permissions you granted, follow [Uninstall in the README](../README.md#uninstall).

## Sottodesu won't start at all

- Make sure you're on **macOS 15 or later** (Apple menu ▸ About This Mac).
- Re-download the latest `.dmg` from the [releases page](https://github.com/lexeremin/Sottodesu/releases/latest) — a download that was cut short can leave a damaged app.
- Still stuck? [Open an issue](https://github.com/lexeremin/Sottodesu/issues/new) with your macOS version and what happens when you open the app.

## My schedule doesn't run

1. **Schedules only run while Sottodesu is running.** On the Schedule tab, switch on **Keep running in the menu bar** (and **Open at login** if you want it after a restart). Look for the Sottodesu icon in the menu bar.
2. Check that the schedule is switched on and **Pause all schedules** is off.
3. The line at the top of the Schedule tab shows when Sottodesu last looked for due schedules. A recent time means it is working and the schedule just wasn't due yet. To test, press **Run Now** in the schedule's ⋯ menu.
4. Files newer than ten minutes are skipped on purpose.
5. For Desktop or Documents, macOS must have allowed Sottodesu to access the folder (**Privacy & Security ▸ Files & Folders**).
6. If you turned on **Open at login** and macOS asks for approval, switch Sottodesu on under **System Settings ▸ General ▸ Login Items & Extensions**.
