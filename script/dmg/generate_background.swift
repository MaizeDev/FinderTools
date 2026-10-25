#!/usr/bin/env swift
//
// generate_background.swift
// 生成 FinderTools DMG 的原创背景图（1x / 2x），不复制参考图的任何素材。
//
// 用法：
//   swift script/dmg/generate_background.swift [输出目录]
//
// 输出（默认写入脚本所在目录 script/dmg/）：
//   background.png       658 x 434  @ 72 dpi   （1x）
//   background@2x.png    1316 x 868 @ 144 dpi  （2x，Retina）
//
// 合成多分辨率 TIFF 由 script/package_release.sh 中的
//   tiffutil -cathidpicheck background.png background@2x.png -out background.tiff
// 完成。
//

import CoreGraphics
import CoreText
import Foundation
import ImageIO

// MARK: - 设计尺寸（单位：点，与窗口内容区一致）

// 设计尺寸 = Finder 内容区尺寸。窗口外框 658 x 494 =
// 434 内容 + 32 标题栏 + 28 路径栏（macOS 27 本机实测，路径栏无法由 .DS_Store 隐藏）。
let designWidth: CGFloat = 658
let designHeight: CGFloat = 434

// MARK: - 右下角签名

/// 签名文字与字体（GitHub 名称；用带笔锋的英文字体与系统字体区分）。
let SIGNATURE_TEXT = "MaizeDev"
let SIGNATURE_FONT = "SnellRoundhand"
let SIGNATURE_SIZE: CGFloat = 14
let SIGNATURE_TRACKING: CGFloat = 0.5

// MARK: - 小工具

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

/// 以“左上角为原点”的坐标构造矩形，内部仍使用 CoreGraphics 的左下原点。
func rectFromTop(_ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    CGRect(x: x, y: designHeight - top - height, width: width, height: height)
}

/// 以“左上角为原点”的坐标构造点。
func pointFromTop(_ x: CGFloat, _ top: CGFloat) -> CGPoint {
    CGPoint(x: x, y: designHeight - top)
}

func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fillLinearGradient(_ ctx: CGContext,
                        rect: CGRect,
                        colors: [CGColor],
                        locations: [CGFloat]?,
                        start: CGPoint,
                        end: CGPoint) {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations) else {
        return
    }
    ctx.saveGState()
    ctx.clip(to: rect)
    ctx.drawLinearGradient(gradient, start: start, end: end,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

func drawRadialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color glowColor: CGColor) {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
    let fade = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0)
    guard let gradient = CGGradient(colorsSpace: space,
                                    colors: [glowColor, fade] as CFArray,
                                    locations: [0, 1]) else { return }
    ctx.saveGState()
    ctx.drawRadialGradient(gradient,
                           startCenter: center, startRadius: 0,
                           endCenter: center, endRadius: radius,
                           options: [])
    ctx.restoreGState()
}

func drawText(_ ctx: CGContext,
              _ text: String,
              size: CGFloat,
              color textColor: CGColor,
              fontName: String? = nil,
              tracking: CGFloat = 0,
              left: CGFloat? = nil,
              centerX: CGFloat? = nil,
              rightX: CGFloat? = nil,
              top: CGFloat,
              shadow: Bool = false) {
    let font = fontName.flatMap { CTFontCreateWithName($0 as CFString, size, nil) }
        ?? CTFontCreateUIFontForLanguage(.system, size, nil)
    guard let font else { return }
    var attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: textColor,
    ]
    if tracking != 0 {
        attributes[kCTKernAttributeName] = tracking
    }
    guard let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary) else { return }
    let line = CTLineCreateWithAttributedString(attributed)

    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

    var x: CGFloat = 0
    if let left { x = left }
    else if let centerX { x = centerX - width / 2 }
    else if let rightX { x = rightX - width }

    ctx.saveGState()
    if shadow {
        ctx.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 5,
                      color: color(0x24314C, 0.20))
    }
    ctx.textPosition = CGPoint(x: x, y: designHeight - top - ascent)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// MARK: - 绘制

func drawBackground(_ ctx: CGContext) {
    let full = CGRect(x: 0, y: 0, width: designWidth, height: designHeight)

    // 1. 基础渐变：左上偏冷的雾蓝 -> 中部淡紫 -> 右下柔和粉
    fillLinearGradient(
        ctx,
        rect: full,
        colors: [color(0x9CC0E9), color(0xC2C2EA), color(0xE7C1D8), color(0xF5D3D6)],
        locations: [0.0, 0.36, 0.72, 1.0],
        start: CGPoint(x: 0, y: designHeight),
        end: CGPoint(x: designWidth, y: 0)
    )

    // 2. 柔光：四角大面积光晕，模拟柔和材质
    drawRadialGlow(ctx, center: pointFromTop(designWidth * 0.16, designHeight * 0.10),
                   radius: 470, color: color(0xFFFFFF, 0.40))
    drawRadialGlow(ctx, center: pointFromTop(designWidth * 0.90, designHeight * 0.06),
                   radius: 380, color: color(0xC3DAFF, 0.32))
    drawRadialGlow(ctx, center: pointFromTop(designWidth * 0.94, designHeight * 0.90),
                   radius: 430, color: color(0xFFC6D6, 0.42))
    drawRadialGlow(ctx, center: pointFromTop(designWidth * 0.08, designHeight * 0.88),
                   radius: 390, color: color(0x9FB8E8, 0.34))

    // 3. 极淡的斜向玻璃高光（覆盖整张图，避免出现裁剪边缘）
    fillLinearGradient(
        ctx,
        rect: full,
        colors: [color(0xFFFFFF, 0.0), color(0xFFFFFF, 0.10), color(0xFFFFFF, 0.0)],
        locations: [0.18, 0.46, 0.74],
        start: CGPoint(x: 0, y: designHeight),
        end: CGPoint(x: designWidth, y: 0)
    )

    // 4. 轻微暗角，让中间内容更聚焦
    if let space = CGColorSpace(name: CGColorSpace.sRGB),
       let vignette = CGGradient(colorsSpace: space,
                                 colors: [CGColor(srgbRed: 0x33 / 255.0, green: 0x3F / 255.0, blue: 0x66 / 255.0, alpha: 0),
                                          CGColor(srgbRed: 0x33 / 255.0, green: 0x3F / 255.0, blue: 0x66 / 255.0, alpha: 0.10)] as CFArray,
                                 locations: [0.55, 1.0]) {
        ctx.saveGState()
        ctx.clip(to: full)
        ctx.drawRadialGradient(vignette,
                               startCenter: CGPoint(x: designWidth / 2, y: designHeight / 2), startRadius: 120,
                               endCenter: CGPoint(x: designWidth / 2, y: designHeight / 2), endRadius: 430,
                               options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }

    // 5. 毛玻璃面板（左右内缩 26；顶部 26、底部留 34，使不同内容区高度下边距都协调）
    let panelRect = rectFromTop(26, 26, designWidth - 52, 374)
    let panelPath = roundedPath(panelRect, radius: 20)
    ctx.saveGState()
    ctx.addPath(panelPath)
    ctx.clip()
    if let space = CGColorSpace(name: CGColorSpace.sRGB),
       let panelGradient = CGGradient(colorsSpace: space,
                                      colors: [color(0xFFFFFF, 0.24), color(0xFFFFFF, 0.07)] as CFArray,
                                      locations: [0, 1]) {
        ctx.drawLinearGradient(panelGradient,
                               start: CGPoint(x: 0, y: panelRect.maxY),
                               end: CGPoint(x: 0, y: panelRect.minY),
                               options: [])
    }
    // 左上到右下的高光，增强“玻璃”质感
    if let space = CGColorSpace(name: CGColorSpace.sRGB),
       let sheen = CGGradient(colorsSpace: space,
                              colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0.0)] as CFArray,
                              locations: [0, 1]) {
        ctx.drawLinearGradient(sheen,
                               start: CGPoint(x: panelRect.minX, y: panelRect.maxY),
                               end: CGPoint(x: panelRect.maxX, y: panelRect.minY),
                               options: [])
    }
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(panelPath)
    ctx.setStrokeColor(color(0xFFFFFF, 0.55))
    ctx.setLineWidth(1.0)
    ctx.strokePath()
    ctx.addPath(roundedPath(panelRect.insetBy(dx: 1.5, dy: 1.5), radius: 18.5))
    ctx.setStrokeColor(color(0xFFFFFF, 0.16))
    ctx.setLineWidth(0.8)
    ctx.strokePath()
    ctx.restoreGState()

    // 6. 两个图标之间的柔和白色箭头（图标中心 170 与 490，箭头控制在 246…412）
    let shaft = rectFromTop(246, 156, 112, 28)
    let head = CGMutablePath()
    head.move(to: pointFromTop(350, 132))
    head.addLine(to: pointFromTop(412, 170))
    head.addLine(to: pointFromTop(350, 208))
    head.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 16,
                  color: color(0x2B3A55, 0.22))
    ctx.setFillColor(color(0xFFFFFF, 0.93))
    // 分开填充，避免圆角箭杆与三角箭头因路径方向相反产生缺口
    ctx.addPath(roundedPath(shaft, radius: 14))
    ctx.fillPath()
    ctx.addPath(head)
    ctx.fillPath()
    ctx.restoreGState()

    // 7. 箭头下方提示文字（居中，避开图标名称区域；用灰蓝保证在浅色背景上的对比度）
    //    top = 236：位于两个 App 图标名称下方、安装说明图标上方，保持版式呼吸感。
    drawText(ctx, "Drag to Applications", size: 16,
             color: color(0x5F708F, 0.92),
             centerX: designWidth / 2, top: 236)

    // 8. 右下角签名（GitHub 名称，字体与正文区分；不复制参考图的署名/水印）
    drawText(ctx, SIGNATURE_TEXT, size: SIGNATURE_SIZE,
             color: color(0xFFFFFF, 0.82),
             fontName: SIGNATURE_FONT, tracking: SIGNATURE_TRACKING,
             rightX: designWidth - 46, top: 374)
}

// MARK: - 输出

func render(scale: Int, to url: URL) throws {
    let pixelWidth = Int(designWidth) * scale
    let pixelHeight = Int(designHeight) * scale
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil,
                              width: pixelWidth,
                              height: pixelHeight,
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "generate_background", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "无法创建绘图上下文"])
    }

    // 以“点”为单位绘图，再按 scale 放大像素
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    ctx.setShouldAntialias(true)

    drawBackground(ctx)

    guard let image = ctx.makeImage() else {
        throw NSError(domain: "generate_background", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "无法生成位图"])
    }

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL,
                                                           "public.png" as CFString,
                                                           1, nil) else {
        throw NSError(domain: "generate_background", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "无法写入 PNG：\(url.path)"])
    }
    let dpi = CGFloat(72 * scale)
    let properties: [CFString: Any] = [
        kCGImagePropertyDPIWidth: dpi,
        kCGImagePropertyDPIHeight: dpi,
        kCGImagePropertyPNGCompressionFilter: 0,
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "generate_background", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "PNG 写入失败：\(url.path)"])
    }
    print("已生成 \(url.path)（\(pixelWidth)x\(pixelHeight)，\(Int(dpi)) dpi）")
}

// MARK: - 入口

let arguments = CommandLine.arguments
let defaultDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outputDirectory: URL
if arguments.count > 1 {
    outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
} else {
    outputDirectory = defaultDirectory
}
do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try render(scale: 1, to: outputDirectory.appendingPathComponent("background.png"))
    try render(scale: 2, to: outputDirectory.appendingPathComponent("background@2x.png"))
} catch {
    FileHandle.standardError.write("错误：\(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
