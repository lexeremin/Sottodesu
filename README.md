<p align="center">
  <img src="Sottodesu/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" alt="Sottodesu app icon">
</p>

<h1 align="center">Sottodesu</h1>

<p align="center">
  <b>Tidy your Mac's Downloads folder with one click — and undo it any time.</b>
</p>

<p align="center">
  <a href="https://github.com/lexeremin/Sottodesu/releases/latest"><img alt="Download" src="https://img.shields.io/github/v/release/lexeremin/Sottodesu?label=download&color=D8431F"></a>
  <a href="https://github.com/lexeremin/Sottodesu/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/lexeremin/Sottodesu/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="macOS 15 or later" src="https://img.shields.io/badge/macOS-15%2B-1f1f1f">
  <img alt="6 languages" src="https://img.shields.io/badge/languages-6-1f1f1f">
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/sort-dark.png">
    <img src="docs/screenshots/sort-light.png" alt="Sottodesu's main window: a Sort Downloads button above a history of past sorts" width="760">
  </picture>
</p>

Sottodesu sorts everything in your Downloads folder into neat folders — Images, Documents, Videos, Books and more — and remembers every sort, so you can put things back with a single click.

- 🧹 **One button.** Press *Sort Downloads*. That's it.
- ↩️ **Always undoable.** Every sort is saved in a history. Undo any of them later.
- 🔐 **Careful with secrets.** Keys, certificates and `.env` files go into their own private folder.
- 🔒 **Private.** Works entirely on your Mac. No account, no internet, no tracking — and it never opens your files, only looks at their names.
- 🌍 **Speaks your language.** English, Русский, 简体中文, 한국어, 日本語 and Français — even the folders it creates are named in your language.
- 🪶 **Light.** One small window, no menu-bar icon, nothing running in the background.

Free and open source. Requires **macOS 15 or later** (Apple silicon or Intel).

---

## Install

1. **[Download the latest release](https://github.com/lexeremin/Sottodesu/releases/latest)** — get the file ending in `.dmg` from the *Assets* list.
2. **Open the downloaded file** and drag **Sottodesu** onto the **Applications** folder.
3. **Open Sottodesu** from your Applications folder (or Launchpad).

### Opening it for the first time

Sottodesu isn't registered with Apple yet (that costs money; this is a free project), so macOS asks you to approve it **once**:

1. Try to open Sottodesu. macOS says it *"could not be verified"* or *"cannot be opened"*. Click **Done**. *(Don't click "Move to Trash".)*
2. Open **System Settings ▸ Privacy & Security**.
3. Scroll down to the **Security** section. Next to *"Sottodesu was blocked…"* click **Open Anyway**.
4. Confirm with your password or Touch ID, then click **Open**.

After that it opens normally. Prefer the Terminal? This does the same thing:

```sh
xattr -dr com.apple.quarantine /Applications/Sottodesu.app
```

Stuck? See [Troubleshooting](docs/TROUBLESHOOTING.md).

---

## Your first sort

1. Open Sottodesu and press **Sort Downloads**.
2. The first time, macOS asks whether Sottodesu may access your Downloads folder. Click **Allow** — it can't work without it.
3. Done. Sottodesu tells you what it sorted, with an **Undo** link right there in case you change your mind.

Sottodesu only looks at the **top level** of your Downloads folder, and it only **moves** things — it never deletes or overwrites anything. If two files would end up with the same name, the second one becomes `photo 2.jpg`.

It deliberately leaves alone:

- files that are still downloading (and anything changed in the last few seconds),
- apps (`.app`) and symbolic links,
- hidden **folders**, and the hidden clutter macOS creates by itself (`.DS_Store`, `.localized`, `._…`),
- the folders it created itself.

> **Hidden files** such as `.gitignore` or `.zshrc` *are* sorted — into **Config & VPN**, or into **Keys & Secrets** if they hold credentials (`.env`, `.npmrc`…). They stay hidden after they move; press **⌘⇧.** in Finder to show them.

## Undo

Every sort appears under **History** on the *Sort* tab. Click a sort to see exactly what it moved, and press **Undo** to put everything back where it was. If you've since moved or deleted something, Sottodesu skips it and tells you — it never overwrites anything while undoing.

---

## A quick tour

### See what's been sorted — and take it back

Each sort is a card with a colour bar showing what went where. Open one to see every item and its size.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/sort-dark.png">
    <img src="docs/screenshots/sort-light.png" alt="The Sort tab with the sort history" width="760">
  </picture>
</p>

### Understand your Downloads folder

The **Report** tab shows how much Sottodesu has sorted, which categories you use most, and where the space in Downloads actually goes.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/report-dark.png">
    <img src="docs/screenshots/report-light.png" alt="The Report tab with statistics and a chart of disk space by folder" width="760">
  </picture>
</p>

### Find the big files

**Largest Files** lists the biggest files in Downloads, biggest first. **Double-click a file to show it in Finder.** Right-click for *Open* and *Copy Path*; click a column to sort, or just search.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/largest-dark.png">
    <img src="docs/screenshots/largest-light.png" alt="The Largest Files tab: a table of the biggest files with a Finder shortcut" width="760">
  </picture>
</p>

Tip: ⌘1 / ⌘2 / ⌘3 switch tabs, ⌘R rescans.

### In your language

<table align="center">
  <tr>
    <td align="center"><img src="docs/screenshots/sort-ru.png" width="270" alt="Русский"><br><sub>Русский</sub></td>
    <td align="center"><img src="docs/screenshots/sort-zh-Hans.png" width="270" alt="简体中文"><br><sub>简体中文</sub></td>
    <td align="center"><img src="docs/screenshots/sort-ko.png" width="270" alt="한국어"><br><sub>한국어</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/sort-ja.png" width="270" alt="日本語"><br><sub>日本語</sub></td>
    <td align="center"><img src="docs/screenshots/sort-fr.png" width="270" alt="Français"><br><sub>Français</sub></td>
    <td></td>
  </tr>
</table>

---

## What goes where

| Folder | What's in it |
|---|---|
| **Images** | photos, screenshots, RAW photos (jpg, png, heic, svg, arw, cr3, nef, dng…) |
| **Videos** | mp4, mov, mkv, avi, webm… |
| **Audio** | mp3, m4a, wav, flac… |
| **Documents** | pdf, Word, Excel, PowerPoint, Pages, Numbers, Keynote, txt, md, csv… |
| **Books** | epub, mobi, azw3, kfx, fb2, djvu, cbz, cbr… |
| **Archives** | zip, rar, 7z, tar, gz… |
| **Installers** | dmg, pkg, iso |
| **3D Models** | stl, 3mf, obj, step, gcode, blend, fbx, glb… |
| **Anki** | apkg, colpkg |
| **Config & VPN** | ovpn, conf, mobileconfig, json, yaml, toml, plist… and **hidden "dot" files** like `.gitignore`, `.zshrc` |
| **Keys & Secrets** | `.env` and `.env.*`, certificates and keys (cert, pem, crt, cer, p12, pfx, SSH keys), `.npmrc`, `.netrc`, password databases… |
| **Code** | py, js, ts, swift, c, cpp, rs, go, sh, ipynb, sql… |
| **Fonts** | ttf, otf, woff, woff2 |
| **Design** | psd, ai, sketch, fig, xd… |
| **Projects** | any loose folder |
| **Other** | everything else |

**Keys & Secrets** is created so that only your user account can open it. Sottodesu never reads what's inside these files — it only moves them, so they don't sit loose among your downloads. (Template files like `.env.example` aren't secret and go to Config & VPN.)

## Languages

Sottodesu follows your Mac's language (System Settings ▸ General ▸ Language & Region). The window **and the folders it creates** use that language:

| | English | Русский | 简体中文 | 한국어 | 日本語 | Français |
|---|---|---|---|---|---|---|
| Images | Images | Изображения | 图片 | 이미지 | 画像 | Images |
| Videos | Videos | Видео | 视频 | 동영상 | 動画 | Vidéos |
| Audio | Audio | Аудио | 音频 | 오디오 | オーディオ | Audio |
| Documents | Documents | Документы | 文档 | 문서 | 書類 | Documents |
| Books | Books | Книги | 图书 | 도서 | 書籍 | Livres |
| Archives | Archives | Архивы | 压缩包 | 압축 파일 | アーカイブ | Archives |
| Installers | Installers | Установщики | 安装程序 | 설치 파일 | インストーラ | Installateurs |
| 3D Models | 3D Models | 3D-модели | 3D 模型 | 3D 모델 | 3Dモデル | Modèles 3D |
| Anki | Anki | Anki | Anki | Anki | Anki | Anki |
| Config & VPN | Config & VPN | Конфиги и VPN | 配置与 VPN | 설정 및 VPN | 設定とVPN | Config et VPN |
| Keys & Secrets | Keys & Secrets | Ключи и секреты | 密钥与机密 | 키 및 보안 정보 | 鍵と機密情報 | Clés et secrets |
| Code | Code | Код | 代码 | 코드 | コード | Code |
| Fonts | Fonts | Шрифты | 字体 | 글꼴 | フォント | Polices |
| Design | Design | Дизайн | 设计 | 디자인 | デザイン | Design |
| Projects | Projects | Проекты | 项目 | 프로젝트 | プロジェクト | Projets |
| Other | Other | Другое | 其他 | 기타 | その他 | Autres |

If you change your Mac's language later, nothing breaks: Sottodesu recognises folders it made in *any* of these languages and keeps using them, so you never end up with two sets. Chinese means Simplified Chinese; Traditional Chinese isn't included yet.

Want another language? See [Translating](docs/DEVELOPING.md#adding-or-fixing-a-translation).

---

## Privacy

- Sottodesu **never connects to the internet.** There is no account, no analytics and no update check.
- It only looks at **file names** inside your Downloads folder and moves files. It **never opens or reads what's inside them.**
- The only thing it stores is its history — one small file at `~/Library/Application Support/Sottodesu/history.sqlite`.

## Uninstall

Use **Sottodesu ▸ Uninstall Sottodesu…** from the menu bar. It deletes the history file and moves the app to the Trash. (Just dragging the app to the Trash works too, but leaves the small history file behind — macOS gives apps no chance to clean up after themselves.) Files that were already sorted stay where they are.

## Help

- 🛟 [Troubleshooting](docs/TROUBLESHOOTING.md) — the most common problems and fixes
- 🐞 [Report a problem or suggest something](https://github.com/lexeremin/Sottodesu/issues/new)
- 🛠 [Build it yourself / contribute](docs/DEVELOPING.md)
- 📝 [What's new](CHANGELOG.md)
