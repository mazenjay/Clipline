//
//  StepScrollView.swift
//  Clipline
//
//  Created by mazhj on 2025/12/4.
//

import AppKit
import SwiftUI

enum ScrollPosition {
    case top
    case center
    case bottom
}

class NSStepScrollView: NSScrollView {

    var stepHeight: CGFloat = 100.0

    private var scrollAccumulator: CGFloat = 0.0
    
    var onScrollPositionChanged: ((Int) -> Void)?

    override func scrollWheel(with event: NSEvent) {

        guard event.hasPreciseScrollingDeltas || event.scrollingDeltaY != 0
        else {
            super.scrollWheel(with: event)
            return
        }

        scrollAccumulator += event.scrollingDeltaY

        if abs(scrollAccumulator) >= stepHeight {
            let steps = round(scrollAccumulator / stepHeight)

            let scrollAmount = steps * stepHeight

            scroll(by: scrollAmount)

            scrollAccumulator -= scrollAmount
        }
    }
    
    /// 根据给定的像素值手动滚动视图
    private func scroll(by amount: CGFloat) {
        guard let documentView = self.documentView else {
            print("❌ scroll(by:) documentView is nil")
            return
        }
        
        let currentY = contentView.bounds.origin.y
        let newY = currentY - amount
        print(" amount: \(amount)")
        
        // 计算有效的滚动范围
        let maxY = calculateMaxScrollY()
        let clampedY = clamp(newY, min: 0, max: maxY)
        
        print("🔧 scroll(by:) currentY: \(currentY), newY: \(newY), maxY: \(maxY), clampedY: \(clampedY)")
        print("🔧 documentHeight: \(documentView.frame.height), contentHeight: \(contentView.frame.height)")
        
        // 只有位置实际变化时才滚动
        guard clampedY != currentY else {
            print("⚠️ scroll(by:) clampedY == currentY, no scroll performed")
            return
        }
        print("✅ scroll(by:) performing scroll to: \(clampedY)")
        performScroll(to: clampedY)
        
    }
        
    func scrollByStep(_ direction: Int) {
        print("📦 NSStepScrollView.scrollByStep called with direction: \(direction)")
        let scrollAmount = CGFloat(direction) * stepHeight
        print("📦 scrollAmount: \(scrollAmount), stepHeight: \(stepHeight)")
        print("📦 Current contentView.bounds.origin.y: \(contentView.bounds.origin.y)")
        scroll(by: scrollAmount)
        print("📦 After scroll, contentView.bounds.origin.y: \(contentView.bounds.origin.y)")
    }

    func scrollTo(yOffset: CGFloat) {
        let currentY = contentView.bounds.origin.y
        let maxY = calculateMaxScrollY()
        let clampedY = clamp(yOffset, min: 0, max: maxY)
        guard clampedY != currentY else { return }
        performScroll(to: clampedY)
    }

    func scrollTo(index: Int, position: ScrollPosition) {
        // a. 获取必要的尺寸信息
        guard let documentView = self.documentView else { return }
        let documentHeight = documentView.frame.height
        let contentHeight = contentView.frame.height  // 这是可见区域的高度

        guard documentHeight > contentHeight else {
            return
        }

        // b. 计算目标行本身的 Y 坐标
        // 这是目标行的顶部在整个内容中的位置
        let itemY = stepHeight * CGFloat(index)
        // c. 根据期望的位置（position）计算最终的 yOffset
        var targetY: CGFloat
        switch position {
        case .top:
            // 滚动到顶部：目标行的顶部对齐可见区域的顶部
            targetY = itemY

        case .center:
            // 滚动到中心：目标行的中心对齐可见区域的中心
            // - 目标行中心点: itemY + stepHeight / 2
            // - 可见区域中心点: yOffset + contentHeight / 2
            // - 两者相等，解出 yOffset = itemY + stepHeight / 2 - contentHeight / 2
            targetY = itemY - (contentHeight / 2.0) + (stepHeight / 2.0)

        case .bottom:
            // 滚动到底部：目标行的底部对齐可见区域的底部
            // - 目标行底部: itemY + stepHeight
            // - 可见区域底部: yOffset + contentHeight
            // - 两者相等，解出 yOffset = itemY + stepHeight - contentHeight
            targetY = itemY - contentHeight + stepHeight
        }

        // d. 调用我们已有的核心滚动方法来执行滚动
        // scrollTo(yOffset:) 内部已经处理了边界检查，所以这里不需要重复检查
        scrollTo(yOffset: targetY)
    }

    private func calculateMaxScrollY() -> CGFloat {
        guard let documentView = self.documentView else { return 0 }
        let documentHeight = documentView.frame.height
        let contentHeight = contentView.frame.height
        return max(0, documentHeight - contentHeight)
    }

    private func clamp(
        _ value: CGFloat,
        min minValue: CGFloat,
        max maxValue: CGFloat
    ) -> CGFloat {
        return max(minValue, min(value, maxValue))
    }

    private func performScroll(to yOffset: CGFloat) {
        var newOrigin = contentView.bounds.origin
        newOrigin.y = yOffset
        contentView.scroll(to: newOrigin)
        reflectScrolledClipView(contentView)
        notifyScrollPositionChanged()
    }
    
    private func notifyScrollPositionChanged() {
        let currentY = contentView.bounds.origin.y
        let firstVisibleIndex = Int(round(currentY / stepHeight))
        onScrollPositionChanged?(firstVisibleIndex)
    }
}

struct StepScrollList<Content: View>: NSViewRepresentable {
    private var proxy: StepScrollViewProxy?
    let stepHeight: CGFloat
    let content: () -> Content
    let onScrollPositionChanged: ((Int) -> Void)?

    init(
        proxy: StepScrollViewProxy? = nil,
        stepHeight: CGFloat,
        onScrollPositionChanged: ((Int) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.proxy = proxy
        self.stepHeight = stepHeight
        self.onScrollPositionChanged = onScrollPositionChanged
        self.content = content
    }

    func makeNSView(context: Context) -> NSStepScrollView {
        let scrollView = NSStepScrollView()
        scrollView.stepHeight = self.stepHeight  // 设置步长
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        // ✅ 确保这两行设置了
        scrollView.backgroundColor = .clear // 显式设为 clear
        scrollView.onScrollPositionChanged = onScrollPositionChanged
        scrollView.lineScroll = self.stepHeight
        scrollView.scrollsDynamically = false

        // 将 SwiftUI 内容包装在 NSHostingView 中
        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = hostingView
        

        // 约束，让 hostingView 填满 scrollView 的宽度
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(
                equalTo: scrollView.contentView.leadingAnchor
            ),
            hostingView.trailingAnchor.constraint(
                equalTo: scrollView.contentView.trailingAnchor
            ),
            hostingView.topAnchor.constraint(
                equalTo: scrollView.contentView.topAnchor
            ),
        ])

        return scrollView
    }

    func updateNSView(_ nsView: NSStepScrollView, context: Context) {
        // 在这里可以处理 SwiftUI 状态变化
        // 例如，如果 stepHeight 是一个 @State 变量，在这里更新
        nsView.stepHeight = self.stepHeight
        nsView.lineScroll = self.stepHeight
        
        nsView.onScrollPositionChanged = onScrollPositionChanged

        // --- 关键的连接代码 ---
        // 将遥控器（proxy）和执行者（nsView）连接起来
        if let proxy = self.proxy {
            // 定义当 proxy.scrollTo(index:) 被调用时，应该执行什么操作
            proxy.scrollAction = { [weak nsView] index, pos in
                //                // 使用 weak 引用防止循环引用
                guard let nsView = nsView else { return }
                nsView.scrollTo(index: index, position: pos)
            }
            
            proxy.stepScrollAction = { [weak nsView] direction in
                nsView?.scrollByStep(direction)
            }
        }
        
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            // 1. 更新内容
            hostingView.rootView = self.content()
            
            // 2. 告诉 AppKit 大小可能变了，但在下一个循环更新（软更新）
            hostingView.invalidateIntrinsicContentSize()
            
            // 3. ❌❌❌ 绝对删除这一行 ❌❌❌
            // hostingView.layoutSubtreeIfNeeded()
            // 这一行会强制立即重绘，配合 LazyVStack 极易导致闪烁
        } else {
            // 初始化逻辑 (保持不变)
            let newHostingView = NSHostingView(rootView: content())
            newHostingView.translatesAutoresizingMaskIntoConstraints = false
            // 确保背景透明
            newHostingView.layer?.backgroundColor = NSColor.clear.cgColor
            nsView.documentView = newHostingView
        }
    }
}

class StepScrollViewProxy {
    // 内部存储一个可以执行滚动操作的闭包
    fileprivate var scrollAction: ((Int, ScrollPosition) -> Void)?
    
    fileprivate var stepScrollAction: ((Int) -> Void)?

    /// 命令滚动视图滚动到指定的行索引
    /// - Parameter index: 目标行的索引
    func scrollTo(index: Int, position: ScrollPosition = .top) {
        // 调用注入的滚动操作
        scrollAction?(index, position)
    }
    
    func scrollByStep(_ direction: Int) {
        stepScrollAction?(direction)
    }
}

// 容器视图，模仿 ScrollViewReader
struct StepScrollViewReader<Content: View>: View {
    private let content: (StepScrollViewProxy) -> Content

    // 我们在视图内部创建并持有这个遥控器
    @State private var proxy = StepScrollViewProxy()

    init(@ViewBuilder content: @escaping (StepScrollViewProxy) -> Content) {
        self.content = content
    }

    var body: some View {
        // 将创建好的 proxy 传递给内容闭包
        // 这样，在闭包内部就能使用这个 proxy 了
        content(proxy)
    }
}
