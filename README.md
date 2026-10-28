# Sottodesu

**Tidy your Mac's Downloads folder with one click — and undo it any time.**

Sottodesu sorts everything in your Downloads folder into neat folders — Images, Documents, Videos, Books and more — and remembers every sort, so you can put things back with a single click.

- 🧹 **One button.** Press *Sort Downloads*. That's it.
- ↩️ **Always undoable.** Every sort is saved in a history. Undo any of them later.
- 🔒 **Private.** Works entirely on your Mac. No account, no internet, no tracking.
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
- hidden files and symbolic links,
- apps (`.app`),
- the folders it created itself.

## Undo

Every sort appears under **History** on the *Sort* tab. Click a sort to see exactly what it moved, and press **Undo** to put everything back where it was. If you've since moved or deleted something, Sottodesu skips it and tells you — it never overwrites anything while undoing.

## Report and Largest Files

- **Report** — how much Sottodesu has sorted so far, which categories you use most, and a chart of what's taking space in your Downloads folder.
- **Largest Files** — the biggest files in Downloads, biggest first. **Double-click a file to show it in Finder.** Right-click for *Open* and *Copy Path*. You can sort by any column and search.

Tip: ⌘1 / ⌘2 / ⌘3 switch tabs, ⌘R rescans.

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
| **Config & VPN** | ovpn, conf, mobileconfig, json, yaml, toml, plist, pem, crt… |
| **Code** | py, js, ts, swift, c, cpp, rs, go, sh, ipynb, sql… |
| **Fonts** | ttf, otf, woff, woff2 |
| **Design** | psd, ai, sketch, fig, xd… |
| **Projects** | any loose folder |
| **Other** | everything else |

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
- It only reads and moves files **inside your Downloads folder**.
- The only thing it stores is its history — one small file at `~/Library/Application Support/Sottodesu/history.sqlite`.

## Uninstall

Use **Sottodesu ▸ Uninstall Sottodesu…** from the menu bar. It deletes the history file and moves the app to the Trash. (Just dragging the app to the Trash works too, but leaves the small history file behind — macOS gives apps no chance to clean up after themselves.) Files that were already sorted stay where they are.

## Help

- 🛟 [Troubleshooting](docs/TROUBLESHOOTING.md) — the most common problems and fixes
- 🐞 [Report a problem or suggest something](https://github.com/lexeremin/Sottodesu/issues/new)
- 🛠 [Build it yourself / contribute](docs/DEVELOPING.md)
- 📝 [What's new](CHANGELOG.md)
