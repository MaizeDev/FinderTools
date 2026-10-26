# FinderTools — Mac 鼠标右键菜单管理工具

FinderTools 是一款简单、轻量的 **Mac 鼠标右键管理工具**，帮助你自定义 macOS Finder（访达）右键菜单。无需复杂设置，即可实现 Mac 右键新建文件、管理“打开方式”、快速在终端打开文件夹，并自由控制菜单项目显示在一级菜单或二级菜单。

如果你正在寻找 Mac 右键菜单管理、Finder 右键菜单管理、Mac 右键新建文件或 Mac 打开方式管理工具，FinderTools 可以让日常办公和软件开发中的文件操作更快捷。

[Download the English README](README.md)

[下载 FinderTools V1.1.2](https://github.com/MaizeDev/FinderTools/releases)

## V1.1.2 更新内容

- 可选：关闭最后一个主窗口后隐藏 Dock 图标。FinderTools 会继续在后台运行，右键菜单与 Finder 动作照常可用；再从“应用程序”或 Spotlight 打开 FinderTools，窗口与 Dock 图标会恢复。该选项默认关闭，关闭窗口时保持原来的行为。
- 右键菜单改为始终显示，不再只在已授权文件夹里出现。第一次在某个位置使用“新建文件”“打开方式”或“在终端中打开”时，FinderTools 才会请求该文件夹的权限，授权后自动继续刚才的操作；取消授权窗口会静默结束。`/System`、`/Library`、`/usr`、`/bin`、`/sbin`、`/private` 等系统位置，以及根级别的 `/`、`/Applications`、`/Volumes`、`/Users` 无法授权，会给出一次“此位置不支持”的提示，而不是请求权限。
- 按 ⌘Q 会完全退出 FinderTools，右键菜单随即消失；强制退出或崩溃时同样不会残留菜单，因为扩展每次弹出菜单前都会确认 FinderTools 是否在运行。“通用”页新增“退出 FinderTools”按钮，隐藏 Dock 图标时也能退出。
- 可选：“登录时自动启动 FinderTools”，使用系统登录项。登录后在后台启动，不弹主窗口、不显示 Dock 图标，右键菜单随即可用。该功能已在未签名的本地构建上验收可用，包括重启后的登录启动。关闭登录项后，重启电脑需要手动打开一次 FinderTools；未开启时主窗口顶部会显示提示。FinderTools 没有 Apple Developer 证书签名，如果 macOS 拒绝注册登录项，设置页会显示原因和“打开登录项设置”入口。
- 侧边栏新增“通用”页，集中放置窗口、Dock、启动与退出设置。

## V1.1.1 更新内容

- 授权书签暂时无法解析（例如外置硬盘未插）时不再被误删，权限页会把这类文件夹标为“不可用”，而不是直接丢失。
- 授权时选错文件夹不再反复弹同一个提示：只提示一次“所选文件夹不包含目标”，然后结束。
- 右键菜单只在已授权的文件夹及其子文件夹中出现，与文档描述一致。
- “打开方式”改为按文件类型能力匹配，支持更多扩展名（`.tsx`、`.jsx`、`.go`、`.rs`、`.sh`、`.toml`、`.env`、`.sql`、`.vue`、`.php`、`.rb`、`.kt` 等）；`Makefile`、`Dockerfile`、`.gitignore` 这类无扩展名文件只显示编辑器类软件。
- 启动更快：应用列表先读缓存、后台刷新，右键配置的广播也会合并短时间内的多次变更。
- 主窗口改用标准标题栏，窗口顶部附近的按钮不会再被拖拽区挡住。
- 安全加固：`findertools://` 链接在执行前会校验参数；Finder 扩展不再申请用不到的用户选择文件权限。

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
- 右键菜单始终显示在访达中（需 FinderTools 在后台运行）；第一次在某个位置使用菜单功能时，FinderTools 会请求该文件夹的权限。
- 随时添加或移除已授权的文件夹，不需要开放整个个人目录。
- 可选：关闭最后一个窗口后隐藏 Dock 图标，App 继续在后台运行，右键菜单照常可用。
- 可选：登录时自动启动，并可在“通用”页退出 FinderTools。

## 系统要求

- macOS 26.2 或更高版本（部署目标）。
- 目前仅提供 Apple 芯片 Mac 版本。

## 测试环境

- 本版本在 macOS 27.0.1 上使用 Xcode 27.1（Swift 6）构建和测试。
- 尚未在 macOS 26.x 上实测。

## 下载与安装

1. 前往 [Releases](https://github.com/MaizeDev/FinderTools/releases) 下载 `FinderTools-1.1.2.dmg`。
2. 打开 DMG，窗口里会显示 `FinderTools`、`Applications` 替身和一份中英双语的 `安装说明 Install Guide.txt`；把 `FinderTools` 拖到 `Applications` 上。
3. 双击“应用程序”中的 FinderTools，启动一次并让它在后台保持运行；关闭主窗口不会退出 App。
4. 如果 macOS 阻止打开，请前往“系统设置 → 隐私与安全性”，在页面下方点击“仍要打开”，然后在确认窗口中点击“打开”。

> 当前 V1.1.2 尚未使用 Apple Developer 证书签名和公证，因此第一次打开时会出现无法验证开发者的安全提示。软件源代码完全公开，可以在本仓库查看。

## 首次使用

1. 打开 FinderTools，进入“扩展权限”。
2. 点击“打开扩展管理”，启用 FinderTools 访达扩展。
3. 回到访达，在任意位置点击右键：只要 FinderTools 正在运行，就能看到 FinderTools 菜单。菜单由访达扩展提供，但需要 FinderTools 主 App 在后台保持运行；关闭主窗口不会退出 App。
4. 第一次在某个文件夹使用菜单功能时，FinderTools 会弹出授权窗口；选择包含该项目的文件夹并点击“授权”，刚才的操作会自动继续完成。
5. 也可以在“已授权的文件夹”中提前添加或移除常用位置。
6. 想重启电脑后右键菜单自动可用：在“通用”页开启“登录时自动启动 FinderTools”，或在“系统设置 → 通用 → 登录项”里手动添加 FinderTools。同一页还可以选择关闭最后一个窗口后隐藏 Dock 图标。

FinderTools 只能在已授权文件夹及其子文件夹中执行操作；只要 FinderTools 正在运行，右键菜单本身始终显示，“用到时再授权”是默认流程。

如果菜单或授权没有立即更新，可以重新打开一个访达窗口，或在 FinderTools 中点击“刷新状态”。

## 文件夹权限与隐私

FinderTools 使用 macOS 提供的文件夹授权机制保存权限。右键菜单由访达扩展提供，需要 FinderTools 主 App 保持运行；关闭窗口不会退出 App。只要 FinderTools 正在运行，菜单就始终显示在访达中，但第一次在某个位置使用菜单功能时会请求该文件夹的权限；FinderTools 只能在已授权的文件夹及其子文件夹中执行操作。`/System`、`/Library`、`/usr`、`/bin`、`/sbin`、`/private` 等系统位置，以及根级别的 `/`、`/Applications`、`/Volumes`、`/Users` 不能作为授权文件夹。移除某个文件夹的授权后，FinderTools 无法再操作该位置，下次使用时会重新请求权限。

FinderTools 不会上传文件内容，也不包含账号、广告或数据收集功能。

## 从源代码构建

开发环境需要 Xcode 27.1 或更高版本（本版本实际构建与测试使用的版本）：

1. 使用 Xcode 打开 `FinderTools.xcodeproj`。
2. 选择 `FinderTools` Scheme。
3. 点击运行按钮进行编译。

项目内的 `script/build_and_run.sh` 可以完成本地编译、安装和启动；生成带安装界面的发布 DMG 前，先运行一次 `script/dmg/setup.sh` 安装打包工具（dmgbuild，需要联网），再运行 `script/package_release.sh`。

## 反馈

如果遇到问题或有功能建议，可以在 [GitHub Issues](https://github.com/MaizeDev/FinderTools/issues) 中提交。
