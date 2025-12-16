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
        scrollView.stepHeight = 10
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.layoutManager?.allowsNonContiguousLayout = true
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
//        textView.font = self.font
//        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        scrollView.documentView = textView
        return scrollView
    }

    // MARK: - Update NSView
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView,
              let text = text  else {
            return
        }
        if textView.textStorage?.string != text.string {
            textView.textStorage?.setAttributedString(text)
        }
    }
}
