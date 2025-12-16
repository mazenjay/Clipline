//
//  StepScrollView.swift
//  Clipline
//
//  Created by mazhj on 2025/12/4.
//

import AppKit
import SwiftUI
import QuartzCore

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
    
    private func scroll(by amount: CGFloat) {
        guard let documentView = self.documentView else { return }
        
        let currentY = contentView.bounds.origin.y
        let newY = currentY - amount
        let maxY = calculateMaxScrollY()
        let clampedY = clamp(newY, min: 0, max: maxY)
        
        guard clampedY != currentY else { return }
        performScroll(to: clampedY)
        
    }
        
    func scrollByStep(_ direction: Int) {
        let scrollAmount = CGFloat(direction) * stepHeight
        scroll(by: scrollAmount)
    }

    func scrollTo(yOffset: CGFloat) {
        let currentY = contentView.bounds.origin.y
        let maxY = calculateMaxScrollY()
        let clampedY = clamp(yOffset, min: 0, max: maxY)
        guard clampedY != currentY else { return }
        performScroll(to: clampedY)
    }

    func scrollTo(index: Int, position: ScrollPosition) {
        guard let documentView = self.documentView else { return }
        let documentHeight = documentView.frame.height
        let contentHeight = contentView.frame.height

        guard documentHeight > contentHeight else {
            return
        }

        let itemY = stepHeight * CGFloat(index)
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
    var scrollToIndex: Binding<Int?>?


    init(
        proxy: StepScrollViewProxy? = nil,
        stepHeight: CGFloat,
        scrollToIndex: Binding<Int?>? = nil,
        onScrollPositionChanged: ((Int) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.proxy = proxy
        self.stepHeight = stepHeight
        self.scrollToIndex = scrollToIndex
        self.onScrollPositionChanged = onScrollPositionChanged
        self.content = content
    }

    func makeNSView(context: Context) -> NSStepScrollView {
        let scrollView = NSStepScrollView()
        scrollView.stepHeight = self.stepHeight
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.onScrollPositionChanged = onScrollPositionChanged
        scrollView.lineScroll = self.stepHeight
        scrollView.scrollsDynamically = false
        
        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hostingView
        

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
        nsView.stepHeight = self.stepHeight
        nsView.lineScroll = self.stepHeight
        
        nsView.onScrollPositionChanged = onScrollPositionChanged
        if let proxy = self.proxy {
            proxy.scrollAction = { [weak nsView] index, pos in
                guard let nsView = nsView else { return }
                nsView.scrollTo(index: index, position: pos)
            }
            
            proxy.stepScrollAction = { [weak nsView] direction in
                nsView?.scrollByStep(direction)
            }
        }
        
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            
            hostingView.rootView = self.content()
            hostingView.invalidateIntrinsicContentSize()
            
            if let binding = scrollToIndex, let targetIndex = binding.wrappedValue {
                hostingView.layoutSubtreeIfNeeded()
                let targetY = CGFloat(targetIndex) * stepHeight
                let maxY = max(0, hostingView.frame.height - nsView.contentView.bounds.height)
                let clampedY = min(targetY, maxY)
                
                // Forcefully close all implicit animations
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                CATransaction.setAnimationDuration(0)
                nsView.contentView.bounds.origin = CGPoint(x: 0, y: clampedY)
                nsView.reflectScrolledClipView(nsView.contentView)
                CATransaction.commit()
                
                DispatchQueue.main.async {
                    binding.wrappedValue = nil
                }
            }
        } else {
            let newHostingView = NSHostingView(rootView: content())
            newHostingView.translatesAutoresizingMaskIntoConstraints = false
            newHostingView.layer?.backgroundColor = NSColor.clear.cgColor
            nsView.documentView = newHostingView
        }
    }
}

class StepScrollViewProxy {
    fileprivate var scrollAction: ((Int, ScrollPosition) -> Void)?
    
    fileprivate var stepScrollAction: ((Int) -> Void)?

    func scrollTo(index: Int, position: ScrollPosition = .top) {
        scrollAction?(index, position)
    }
    
    func scrollByStep(_ direction: Int) {
        stepScrollAction?(direction)
    }
}

struct StepScrollViewReader<Content: View>: View {
    private let content: (StepScrollViewProxy) -> Content
    @State private var proxy = StepScrollViewProxy()

    init(@ViewBuilder content: @escaping (StepScrollViewProxy) -> Content) {
        self.content = content
    }

    var body: some View {
        content(proxy)
    }
}
