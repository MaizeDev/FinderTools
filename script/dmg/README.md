# script/dmg —— DMG 安装界面素材与打包配置

本目录包含 FinderTools 安装镜像（DMG）的原创背景、安装说明和 dmgbuild 配置。
参考图只用于版式参考，**没有任何素材、署名或水印来自参考图**。

右下角小签名为 GitHub 名称 `MaizeDev`，字体 Snell Roundhand 14pt（字距 +0.5、白色 82%）。
如需更换：改 `generate_background.swift` 顶部的 `SIGNATURE_TEXT` / `SIGNATURE_FONT` /
`SIGNATURE_SIZE` / `SIGNATURE_TRACKING`，再执行
`./script/package_release.sh 1.1.1 --regenerate-background`。

## 文件

| 文件 | 说明 |
|---|---|
| `generate_background.swift` | 原创背景生成脚本（Swift + CoreGraphics/CoreText，无需 Pillow） |
| `background.png` | 1x 背景：658 x 434 点 @ 72 dpi |
| `background@2x.png` | 2x 背景（Retina）：1320 x 880 像素 @ 144 dpi |
| `background.tiff` | 由上面两张图合成的多分辨率 TIFF（`tiffutil -cathidpicheck`） |
| `install-guide.txt` | DMG 里的中英双语安装说明（UTF-8，无 BOM） |
| `settings.py` | dmgbuild 配置：窗口尺寸、图标坐标、视图选项、背景、符号链接 |
| `setup.sh` | 在 `.build/dmg-venv` 里安装 dmgbuild（只需联网一次，不写系统 Python） |

## 重新生成背景

修改 `generate_background.swift` 里的绘制代码后，运行：

```bash
swift script/dmg/generate_background.swift script/dmg
tiffutil -cathidpicheck "script/dmg/background.png" "script/dmg/background@2x.png" \
  -out "script/dmg/background.tiff"
tiffutil -info "script/dmg/background.tiff"   # 应看到 658x434@72dpi 与 1316x868@144dpi 两档
```

也可以直接让打包脚本重绘：`./script/package_release.sh 1.1.1 --regenerate-background`。
背景只用代码绘制，不联网、不依赖第三方图形库。

## 版式参数（settings.py）

- 窗口外框 658 x 494 点、内容区 658 x 434 点；`window_rect` 写的是窗口外框，所以高度加了
  `TITLEBAR_HEIGHT = 32`（macOS 27 实测标题栏高度）再加 `PATHBAR_HEIGHT = 28`。
  28 点是 Finder 开启「显示路径栏」时窗口底部多出的路径栏：macOS 27 上
  `.DS_Store` 的 `show_pathbar = False` 不会覆盖 Finder 全局偏好，按“标题栏 + 路径栏”
  计算外框后，用户机器上的内容区精确等于 658 x 434；关闭路径栏的机器内容区为
  658 x 462，Finder 会把背景图等比拉伸铺满（面板与图标仍对齐）。
- 图标位置（视图左上角为原点，单位点）：
  - `FinderTools.app`：(164, 170)
  - `Applications`（指向 `/Applications` 的符号链接）：(494, 170)
  - `安装说明 Install Guide.txt`：(329, 312)
- 图标大小 84、文字大小 13、图标名称在图标下方；隐藏工具栏、状态栏、侧边栏、
  路径栏与标签页，使用图标视图、不自动排列。安装说明图标上移到 312，保证图标与
  文件名标签完整落在背景内卡片（28…412）内，且图标视图不产生滚动条。

## 打包

```bash
./script/dmg/setup.sh                 # 第一次：联网安装 dmgbuild 到 .build/dmg-venv
./script/package_release.sh 1.1.1     # 构建 Release + 生成 DMG + verify + SHA-256
```

`package_release.sh` 的输出是 `dist/FinderTools-<版本>.dmg`，并会打印大小与
SHA-256。脚本不联网、不需要开发者证书、不修改系统设置；签名是 Xcode 构建时的
本地 ad-hoc 签名。

## 注意

- 不要往本目录放参考图以外的第三方素材；参考图本身也不应进入发布分支。
- `background.tiff` 与两张 PNG 已提交进仓库，所以打包时不依赖 Swift/Pillow
  （只有在设计变更、显式传 `--regenerate-background` 或 TIFF 丢失时才重绘）。
- DMG 里的窗口版式写在镜像内的 `.DS_Store` 中，换机器/换用户挂载时同样生效。
- 路径栏是否显示由对方机器的 Finder 全局偏好决定，无法由 DMG 强制隐藏；外框高度已
  兼容两种情况，见上文 `PATHBAR_HEIGHT`。
