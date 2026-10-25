# FinderTools — macOS Finder Context Menu Manager

FinderTools is a simple, lightweight **macOS Finder context menu manager**. It helps you customize Finder's right-click menu without complicated setup: create new files, manage “Open With,” open folders in Terminal, and choose whether each item appears in the main menu or a submenu.

If you are looking for a Finder context menu manager, a tool for creating files from the right-click menu, or a way to manage “Open With,” FinderTools makes everyday file operations faster.

[中文说明](README-zh.md)

[Download FinderTools V1.1.1](https://github.com/MaizeDev/FinderTools/releases)

## What's New in V1.1.1

- Folder authorizations are no longer deleted when a bookmark temporarily cannot be resolved (for example, when an external drive is unplugged); the Permissions page marks such folders as unavailable instead of dropping them.
- Choosing the wrong folder during authorization no longer opens the same prompt in an endless loop; FinderTools tells you once that the chosen folder does not contain the target and stops.
- The Finder context menu now appears only inside authorized folders and their subfolders, as documented.
- “Open With” now matches apps by file-type capability and covers many more extensions (`.tsx`, `.jsx`, `.go`, `.rs`, `.sh`, `.toml`, `.env`, `.sql`, `.vue`, `.php`, `.rb`, `.kt`, and more). Files without an extension, such as `Makefile`, `Dockerfile`, and `.gitignore`, now show only editor-style apps.
- Startup is faster: the app list is loaded from cache first and refreshed in the background, and Finder menu configuration updates are coalesced.
- The main window now uses a standard title bar, so controls near the top of the window are no longer blocked by a drag area.
- Security hardening: `findertools://` URLs are validated before any action runs, and the Finder extension no longer requests user-selected file access it does not use.

## What's New in V1.1

- “New File” now supports Markdown, RTF, CSV, JSON, YAML, HTML, CSS, JavaScript, Swift, and Python.
- “Open With” uses macOS file-type capabilities to show only apps that can open common file types, with search and manual refresh support.
- Menu icons are cached during app scanning, and the Finder extension receives only the currently enabled app snapshot.
- When you right-click a file, apps are matched by the file's actual format from the in-memory snapshot, without scanning apps or loading icons on demand.
- FinderTools checks the app list at launch and refreshes it when the main window becomes active again after more than five minutes.
- Newly discovered apps are disabled by default, so your context menu does not suddenly become crowded.

> macOS only allows FinderTools to manage context menu items added by FinderTools itself. Built-in Finder items such as “Copy” and “Get Info” cannot be hidden by third-party apps.

## Features

- Create common files such as TXT, Word, Excel, PowerPoint, Markdown, JSON, HTML, Swift, and Python files from Finder's context menu.
- Manage the Mac “Open With” menu, choose a preferred app, or select another app temporarily.
- Open the current folder in Terminal.
- Enable or disable each feature independently, and choose whether it appears in the main menu or a submenu.
- Control access with an authorized-folder list, including Desktop, Downloads, Documents, and Movies.
- Add or remove authorized folders at any time without granting access to your entire home directory.

## System Requirements

- macOS 26.2 or later (deployment target).
- Apple silicon Macs only.

## Tested Environment

- Built and tested on macOS 27.0.1 with Xcode 27.1 and Swift 6.
- macOS 26.x has not been tested yet.

## Download and Installation

1. Go to [Releases](https://github.com/MaizeDev/FinderTools/releases) and download `FinderTools-1.1.1.dmg`.
2. Open the DMG. Its window shows `FinderTools`, an `Applications` shortcut, and a bilingual `安装说明 Install Guide.txt`; drag `FinderTools` onto `Applications`.
3. Open FinderTools from Applications once.
4. If macOS blocks the app, go to “System Settings → Privacy & Security,” click “Open Anyway” near the bottom, then click “Open” in the confirmation dialog.

> V1.1.1 is not signed with an Apple Developer certificate or notarized, so macOS will show an “unidentified developer” warning the first time you open it. The source code is fully public in this repository.

## First Use

1. Open FinderTools and go to “Extension Permissions.”
2. Click “Open Extension Manager” and enable the FinderTools Finder extension.
3. Under “Authorized Folders,” click “Add Folder.”
4. Add the locations where you want to use the context menu, such as Desktop, Downloads, Documents, or Movies.
5. Return to Finder and right-click inside an authorized folder.

FinderTools' context menu appears only inside authorized folders and their subfolders. If you have not added any folder yet, the menu does not appear anywhere in Finder.

After adding or removing a folder, if the context menu does not appear immediately, reopen a Finder window or click “Refresh Status” in FinderTools.

## Folder Permissions and Privacy

FinderTools uses macOS folder permissions to save access. The context menu appears only inside authorized folders and their subfolders, and FinderTools can operate only there. After you remove a folder, its menu disappears and FinderTools can no longer operate there.

FinderTools does not upload file contents and does not include accounts, advertising, or data collection.

## Build from Source

You need Xcode 27.1 or later (the version this release was built and tested with):

1. Open `FinderTools.xcodeproj` in Xcode.
2. Select the `FinderTools` scheme.
3. Click the Run button to build the app.

The `script/build_and_run.sh` script builds, installs, and launches the app locally. To create a release DMG with the installer window, run `script/dmg/setup.sh` once (installs the packaging tool dmgbuild; requires network access), then use `script/package_release.sh`.

## Feedback

If you encounter a problem or have a feature suggestion, please open an issue on [GitHub Issues](https://github.com/MaizeDev/FinderTools/issues).
