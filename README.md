# FinderTools

让 macOS 访达右键菜单更顺手的小工具。

[下载 FinderTools V1.0](https://github.com/MaizeDev/FinderTools/releases/tag/v1.0)

## 功能

- 在访达右键菜单中新建 TXT、Word、Excel 和 PowerPoint 文件。
- 使用常用软件打开所选文件，也可以临时选择其他软件。
- 在当前文件夹中打开“终端”。
- 每项功能都可以单独开启或关闭，并选择显示在一级或二级菜单。
- 使用授权文件夹列表控制访问范围，可以分别授权桌面、下载、文稿、影片等目录。
- 随时添加或移除已授权的文件夹，不需要开放整个个人目录。

## 系统要求

- macOS 26.2 或更高版本。
- 目前仅提供 Apple 芯片 Mac 版本。

## 下载与安装

1. 前往 [Releases](https://github.com/MaizeDev/FinderTools/releases) 下载 `FinderTools-1.0.dmg`。
2. 打开 DMG，将 `FinderTools` 拖入“应用程序”文件夹。
3. 双击“应用程序”中的 FinderTools，尝试启动一次。
4. 如果 macOS 阻止打开，请前往“系统设置 → 隐私与安全性”，在页面下方点击“仍要打开”，然后在确认窗口中点击“打开”。

> 当前 V1.0 尚未使用 Apple Developer 证书签名和公证，因此第一次打开时会出现无法验证开发者的安全提示。软件源代码完全公开，可以在本仓库查看。

## 首次使用

1. 打开 FinderTools，进入“扩展权限”。
2. 点击“打开扩展管理”，启用 FinderTools 访达扩展。
3. 在“已授权的文件夹”中点击“添加文件夹”。
4. 分别添加需要使用右键功能的位置，例如桌面、下载、文稿或影片。
5. 回到访达，在授权文件夹中点击右键即可使用 FinderTools。

如果右键菜单没有立即出现，可以重新打开一个访达窗口，或在 FinderTools 中点击“刷新状态”。

## 文件夹权限与隐私

FinderTools 使用 macOS 提供的文件夹授权机制保存权限，只能对授权列表中的文件夹及其子文件夹执行操作。移除某个文件夹后，FinderTools 将无法继续操作该位置。

FinderTools 不会上传文件内容，也不包含账号、广告或数据收集功能。

## 从源代码构建

开发环境需要 Xcode 26.2 或更高版本：

1. 使用 Xcode 打开 `FinderTools.xcodeproj`。
2. 选择 `FinderTools` Scheme。
3. 点击运行按钮进行编译。

项目内的 `script/build_and_run.sh` 可以完成本地编译、安装和启动；`script/package_release.sh` 用于生成发布用 DMG。

## 反馈

如果遇到问题或有功能建议，可以在 [GitHub Issues](https://github.com/MaizeDev/FinderTools/issues) 中提交。
