# FinderTools — macOS Finder Context Menu Manager

FinderTools is a simple, lightweight **macOS Finder context menu manager**. It helps you customize Finder's right-click menu without complicated setup: create new files, manage “Open With,” open folders in Terminal, and choose whether each item appears in the main menu or a submenu.

If you are looking for a Finder context menu manager, a tool for creating files from the right-click menu, or a way to manage “Open With,” FinderTools makes everyday file operations faster.

[中文说明](README-zh.md)

[Download FinderTools V1.1.2](https://github.com/MaizeDev/FinderTools/releases)

## What's New in V1.1.2

- Optional: hide the Dock icon after you close the last FinderTools window. The app keeps running in the background, so the context menu and Finder actions keep working; open FinderTools again from Applications or Spotlight and its window and Dock icon come back. This option is off by default, so closing the window keeps the previous behavior.
- The Finder context menu is always available again, instead of only inside authorized folders. FinderTools asks for a folder's permission the first time you use New File, Open With, or Open in Terminal there, and then continues the action automatically. Canceling the authorization window ends silently, and system locations that cannot be authorized show a short “not supported” message instead of asking for permission.
- Pressing ⌘Q now quits FinderTools completely and the FinderTools context menu disappears; this also covers a force quit or a crash, because the extension checks whether FinderTools is running every time the menu opens. A new “Quit FinderTools” button on the General settings page gives you a way to quit when the Dock icon is hidden.
- Optional: launch FinderTools automatically when you log in, using the system Login Items. It starts in the background with no window and no Dock icon, so the context menu is available right after login. This has been verified on an unsigned local build, including login start after a restart. If the login item is off, you need to open FinderTools once after a restart; the main window shows a reminder about this. FinderTools is not signed with an Apple Developer certificate, so if macOS refuses to register the login item, the app shows the reason and a shortcut to Login Items settings.
- A new “General” page in the sidebar collects these window, Dock, launch, and quit options.

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
- Control access with an authorized-folder list: while FinderTools is running, the Finder context menu is always available, and FinderTools asks for a folder's permission the first time you use an action there.
- Add or remove authorized folders at any time without granting access to your entire home directory.
- Optionally hide the Dock icon after the last window closes; FinderTools keeps running in the background so the menu keeps working.
- Optionally launch FinderTools at login in the background, and quit it from the General settings page.

## System Requirements

- macOS 26.2 or later (deployment target).
- Apple silicon Macs only.

## Tested Environment

- Built and tested on macOS 27.0.1 with Xcode 27.1 and Swift 6.
- macOS 26.x has not been tested yet.

## Download and Installation

1. Go to [Releases](https://github.com/MaizeDev/FinderTools/releases) and download `FinderTools-1.1.2.dmg`.
2. Open the DMG. Its window shows `FinderTools`, an `Applications` shortcut, and a bilingual `安装说明 Install Guide.txt`; drag `FinderTools` onto `Applications`.
3. Open FinderTools from Applications once and keep it running in the background; closing its window does not quit it.
4. If macOS blocks the app, go to “System Settings → Privacy & Security,” click “Open Anyway” near the bottom, then click “Open” in the confirmation dialog.

> V1.1.2 is not signed with an Apple Developer certificate or notarized, so macOS will show an “unidentified developer” warning the first time you open it. The source code is fully public in this repository.

## First Use

1. Open FinderTools and go to “Extension Permissions.”
2. Click “Open Extension Manager” and enable the FinderTools Finder extension.
3. Return to Finder and right-click anywhere: the FinderTools context menu appears while FinderTools is running. The menu is provided by the Finder extension, but it needs the FinderTools app to stay running in the background; closing the main window does not quit the app.
4. The first time you use an action in a folder, FinderTools opens an authorization window. Choose a folder that contains the item, click “Authorize,” and the action continues automatically.
5. You can also add or remove folders in advance under “Authorized Folders.”
6. To have the context menu available right after a restart, turn on “Launch at Login” on the “General” page, or add FinderTools manually in System Settings → General → Login Items. The same page also offers the option to hide the Dock icon after the last window closes.

FinderTools can execute actions only inside authorized folders and their subfolders. The context menu itself stays visible everywhere while FinderTools is running, and asking for permission when needed is the default flow.

If the menu or an authorization does not update immediately, reopen a Finder window or click “Refresh Status” in FinderTools.

## Folder Permissions and Privacy

FinderTools uses macOS folder permissions to save access. The Finder context menu is provided by the extension and requires the FinderTools app to be running; closing the window does not quit it. While FinderTools is running, the menu is available in Finder, but FinderTools asks for a folder's permission the first time you use an action there, and it can operate only in authorized folders and their subfolders. System locations such as `/System`, `/Library`, `/usr`, `/bin`, `/sbin` and `/private`, and the root-level `/`, `/Applications`, `/Volumes` and `/Users`, cannot be authorized. After you remove a folder authorization, FinderTools can no longer operate there and will ask again the next time you use the menu in that location.

FinderTools does not upload file contents and does not include accounts, advertising, or data collection.

## Build from Source

You need Xcode 27.1 or later (the version this release was built and tested with):

1. Open `FinderTools.xcodeproj` in Xcode.
2. Select the `FinderTools` scheme.
3. Click the Run button to build the app.

The `script/build_and_run.sh` script builds, installs, and launches the app locally. To create a release DMG with the installer window, run `script/dmg/setup.sh` once (installs the packaging tool dmgbuild; requires network access), then use `script/package_release.sh`.

## Feedback

If you encounter a problem or have a feature suggestion, please open an issue on [GitHub Issues](https://github.com/MaizeDev/FinderTools/issues).
