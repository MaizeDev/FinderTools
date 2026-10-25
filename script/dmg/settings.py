# -*- coding: utf-8 -*-
"""dmgbuild 配置：FinderTools 安装镜像的窗口版式。

由 script/package_release.sh 调用，例如：

    .build/dmg-venv/bin/dmgbuild -s script/dmg/settings.py \
        -D app=<FinderTools.app 路径> \
        -D background=<background.tiff 路径> \
        -D guide=<安装说明文本路径> \
        -D version=1.1.1 \
        "FinderTools 1.1.1" dist/FinderTools-1.1.1.dmg

dmgbuild 是纯 Python 工具（不依赖 Finder 自动化），直接写入镜像内的
.DS_Store，因此窗口版式可在一台机器上生成、在别的机器上得到相同结果。
"""

import os


def _require(name):
    """读取 -D 传入的值并确认路径存在。"""
    value = defines.get(name)  # noqa: F821  （dmgbuild 注入的全局变量）
    if not value:
        raise ValueError("缺少参数：-D%s=..." % name)
    if not os.path.exists(value):
        raise ValueError("-D%s 指定的路径不存在：%s" % (name, value))
    return value


app = _require("app")
background = _require("background")
guide = _require("guide")
version = defines.get("version", "1.1.1")  # noqa: F821

APP_NAME = "FinderTools.app"
GUIDE_NAME = "安装说明 Install Guide.txt"

# 窗口内容区 658 x 434 点（窗口外框 658 x 494，由评审后要求确定）。
# dmgbuild 的 window_rect 会写入 .DS_Store 的 WindowBounds，格式为
# {{x, y}, {w, h}}，其中宽高是 Finder 窗口的外框尺寸（含标题栏与路径栏）。
# 高度 = 内容区高度 + 标题栏高度 + 路径栏高度：
#   * 标题栏 32 点是 macOS 27 上用 NSWindow.frameRect(forContentRect:) 实测的值；
#   * 路径栏 28 点是本机 Finder 开启「显示路径栏」时窗口底部多出的一条。
#     .DS_Store 里的 show_pathbar = False 在 macOS 27 上不会覆盖 Finder
#     全局偏好（实测：本机与参考项目的 DMG 都会出现该栏；参考项目 DMG
#     在本机内容区同样从 504 变成 476）。因此这里把外框按「标题栏 + 路径栏」
#     计算，让内容区在开启路径栏的机器上仍精确等于 660 x 440；关闭路径栏
#     的机器内容区为 660 x 468，Finder 会把 660x440 的背景图等比拉伸铺满
#     （面板边距等比例变化，图标仍落在面板内）。
CONTENT_WIDTH = 658
CONTENT_HEIGHT = 434
TITLEBAR_HEIGHT = 32
PATHBAR_HEIGHT = 28

# 窗口 / 视图
window_rect = ((100, 100),
               (CONTENT_WIDTH, CONTENT_HEIGHT + TITLEBAR_HEIGHT + PATHBAR_HEIGHT))
default_view = "icon-view"
icon_size = 84
text_size = 13
label_pos = "bottom"
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
show_toolbar = False
show_status_bar = False
show_sidebar = False
show_pathbar = False
show_tab_view = False

# 背景与内容
background = background
files = [(app, APP_NAME), (guide, GUIDE_NAME)]
symlinks = {"Applications": "/Applications"}

# 图标位置：视图左上角为原点，单位点。
# 图标位于内容区中上部；安装说明图标上移，让图标 + 文件名标签完整落在
# 背景内卡片（26…400）内部，同时保证图标视图内容不超出内容区（不出现右侧滚动条）。
# 左右两个 App 图标以内容区水平中心 329 对称（164 / 494）。
icon_locations = {
    APP_NAME: (164, 170),
    "Applications": (494, 170),
    GUIDE_NAME: (329, 312),
}

# 输出格式
format = "UDZO"
filesystem = "HFS+"
