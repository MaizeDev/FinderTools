# FinderTools — macOS Finder Context Menu Manager

FinderTools is a simple, lightweight **macOS Finder context menu manager**. It helps you customize Finder's right-click menu without complicated setup: create new files, manage “Open With,” open folders in Terminal, and choose whether each item appears in the main menu or a submenu.

If you are looking for a Finder context menu manager, a tool for creating files from the right-click menu, or a way to manage “Open With,” FinderTools makes everyday file operations faster.

[中文说明](README-zh.md)

[Download FinderTools V1.1](https://github.com/MaizeDev/FinderTools/releases)

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

- macOS 26.2 or later.
- Apple silicon Macs only.

## Download and Installation

1. Go to [Releases](https://github.com/MaizeDev/FinderTools/releases) and download `FinderTools-1.1.dmg`.
2. Open the DMG and drag `FinderTools` to the Applications folder.
3. Open FinderTools from Applications once.
4. If macOS blocks the app, go to “System Settings → Privacy & Security,” click “Open Anyway” near the bottom, then click “Open” in the confirmation dialog.

> V1.1 is not signed with an Apple Developer certificate or notarized, so macOS will show an “unidentified developer” warning the first time you open it. The source code is fully public in this repository.

## First Use

1. Open FinderTools and go to “Extension Permissions.”
2. Click “Open Extension Manager” and enable the FinderTools Finder extension.
3. Under “Authorized Folders,” click “Add Folder.”
4. Add the locations where you want to use the context menu, such as Desktop, Downloads, Documents, or Movies.
5. Return to Finder and right-click inside an authorized folder.

If the context menu does not appear immediately, reopen a Finder window or click “Refresh Status” in FinderTools.

## Folder Permissions and Privacy

FinderTools uses macOS folder permissions and can operate only within authorized folders and their subfolders. After you remove a folder, FinderTools can no longer operate there.

FinderTools does not upload file contents and does not include accounts, advertising, or data collection.

## Build from Source

You need Xcode 26.2 or later:

1. Open `FinderTools.xcodeproj` in Xcode.
2. Select the `FinderTools` scheme.
3. Click the Run button to build the app.

The `script/build_and_run.sh` script builds, installs, and launches the app locally. Use `script/package_release.sh` to create a release DMG.

## Feedback

If you encounter a problem or have a feature suggestion, please open an issue on [GitHub Issues](https://github.com/MaizeDev/FinderTools/issues).
