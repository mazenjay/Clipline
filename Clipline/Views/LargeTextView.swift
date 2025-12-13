//
//  LargeTextView.swift
//  Clipline
//
//  Created by mazhj on 2025/12/4.
//

import AppKit
import SwiftUI


struct LargeTextView: NSViewRepresentable {

    var text: NSAttributedString?
    
//    var isEditable: Bool = false
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSStepScrollView()
        scrollView.stepHeight = 10  // 设置步长
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.autohidesScrollers = true

        // --- 创建 TextView ---
        let textView = NSTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        
        // --- 核心性能设置 ---
        // 允许非连续布局，这是处理大文本的关键性能优化！
        textView.layoutManager?.allowsNonContiguousLayout = true
        
        // --- 外观和行为 ---
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true // 允许富文本
//        textView.font = self.font
//        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        scrollView.documentView = textView
//        context.coordinator.textView = textView

        return scrollView
    }

    // MARK: - Update NSView
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // 2. 在 updateNSView 中处理 SwiftUI 状态的变化
        guard let textView = nsView.documentView as? NSTextView,
              let text = text  else {
            return
        }

        // 3. 检查内容是否真的发生了变化，避免不必要的刷新
        //    这对于性能至关重要！
        if textView.textStorage?.string != text.string {
            textView.textStorage?.setAttributedString(text)
        }
                
//        if textView.isEditable != self.isEditable {
//            textView.isEditable = self.isEditable
//        }
    }
    
    // MARK: - Coordinator
    
    // 5. Coordinator 用于处理代理回调，例如当用户在 TextView 中输入时
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    class Coordinator: NSObject, NSTextViewDelegate {
//        var parent: LargeTextView
//        weak var textView: NSTextView? // 弱引用以避免循环引用
//
//        init(_ parent: LargeTextView) {
//            self.parent = parent
//        }
//
//        // 当文本发生变化时（例如用户输入），此代理方法会被调用
//        func textDidChange(_ notification: Notification) {
//            guard let textView = notification.object as? NSTextView else {
//                return
//            }
//            
//            // 将 AppKit 中的变化同步回 SwiftUI 的 @Binding
//            // 使用 DispatchQueue.main.async 避免潜在的“在视图更新期间修改状态”的警告
//            DispatchQueue.main.async {
//                self.parent.text = NSAttributedString(attributedString: textView.attributedString())
//            }
//        }
//    }
}
