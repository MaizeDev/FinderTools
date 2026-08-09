# FinderTools — Mac 鼠标右键菜单管理工具

FinderTools 是一款简单、轻量的 **Mac 鼠标右键管理工具**，帮助你自定义 macOS Finder（访达）右键菜单。无需复杂设置，即可实现 Mac 右键新建文件、管理“打开方式”、快速在终端打开文件夹，并自由控制菜单项目显示在一级菜单或二级菜单。

如果你正在寻找 Mac 右键菜单管理、Finder 右键菜单管理、Mac 右键新建文件或 Mac 打开方式管理工具，FinderTools 可以让日常办公和软件开发中的文件操作更快捷。

[Download the English README](README.md)

[下载 FinderTools V1.1](https://github.com/MaizeDev/FinderTools/releases)

## V1.1 更新内容

- “新建文件”新增 Markdown、RTF、CSV、JSON、YAML、HTML、CSS、JavaScript、Swift 和 Python。
- “打开方式”通过 macOS 的文件类型能力清单，只加载能打开常见文件的软件，并支持搜索与手动刷新。
- 软件扫描时会提前缓存菜单小图标；Finder 扩展只接收当前已开启的软件快照。
- 右键文件时会按实际文件格式从内存快照匹配软件，不再临时扫描软件或读取图标。
- 启动 FinderTools 时会检查软件列表；主窗口重新活跃超过 5 分钟也会自动更新。
- 新发现的软件默认不加入右键菜单，用户可按需开启，避免菜单突然变得很长。

> macOS 目前只允许 FinderTools 管理自己添加的右键菜单。Finder 自带的“拷贝”“显示简介”等系统项目无法由第三方软件隐藏。

## Mac 鼠标右键管理功能

- 在 Finder 右键菜单中新建 TXT、Word、Excel、PowerPoint、Markdown、JSON、HTML、Swift、Python 等常用文件。
- 管理 Mac“打开方式”菜单，选择常用软件打开文件，也可以临时选择其他软件。
- 在当前文件夹中打开“终端”。
- 每项功能都可以单独开启或关闭，并选择显示在一级或二级菜单。
- 使用授权文件夹列表控制访问范围，可以分别授权桌面、下载、文稿、影片等目录。
- 随时添加或移除已授权的文件夹，不需要开放整个个人目录。

## 系统要求

- macOS 26.2 或更高版本。
- 目前仅提供 Apple 芯片 Mac 版本。

## 下载与安装

1. 前往 [Releases](https://github.com/MaizeDev/FinderTools/releases) 下载 `FinderTools-1.1.dmg`。
2. 打开 DMG，将 `FinderTools` 拖入“应用程序”文件夹。
3. 双击“应用程序”中的 FinderTools，尝试启动一次。
4. 如果 macOS 阻止打开，请前往“系统设置 → 隐私与安全性”，在页面下方点击“仍要打开”，然后在确认窗口中点击“打开”。

> 当前 V1.1 尚未使用 Apple Developer 证书签名和公证，因此第一次打开时会出现无法验证开发者的安全提示。软件源代码完全公开，可以在本仓库查看。

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
