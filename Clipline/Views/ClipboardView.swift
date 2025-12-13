//
//  ClipboardView.swift
//  Clipline
//
//  Created by mazhj on 2025/12/3.
//

import SwiftUI

struct ClipboardView: View {
    
    @ObservedObject var viewModel: ClipboardViewModel
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("", text: $viewModel.query)
                .textFieldStyle(.plain)
                .onChange(of: viewModel.query) {
                    viewModel.input()
                }
                .padding(.vertical, 1)
                .padding(.horizontal, 10)
                .focused($isSearchFocused)
            
            GeometryReader { geo in
                ZStack {
                    HStack(spacing: 0) {
                        HistoryListView(
                            viewModel: viewModel,
                            height: geo.size.height
                        )
                        .frame(width: geo.size.width * 0.45)

                        HistoryPreviewView(viewModel: viewModel)
                            .frame(width: geo.size.width * 0.55, height: geo.size.height)
                            .focusable(false)
                    }
                    .background(Color.clear)
                    .frame(maxHeight: .infinity)
                    .opacity(viewModel.histories.isEmpty ? 0 : 1)
                    
                    if viewModel.histories.isEmpty {
                        VStack {
                            Spacer()
                            Text("No matching clipboard history items")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear) // 确保鼠标事件能穿透或者阻挡，视需求而定
                        .transition(.opacity) // 加上淡入淡出，让提示文字出现得更柔和
                    }
                }
            }
            .background(Color.clear)
            .focusable(false)
        }
        .padding(12)
        .background(
            // 背景会自动对齐到 VStack 的 padding 边界
            Color.clear
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: 24)
                )
        )
        .onAppear {
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
    }
}


struct HistoryListView: View {
    
    @ObservedObject var viewModel: ClipboardViewModel
    @Namespace private var listNamespace
    
    var height: CGFloat
    
    var body: some View {
        // 1. 这里的 items 不需要 enumerated()，直接传数组，减轻编译器负担
        let items = viewModel.itemsForTableView
        
        StepScrollViewReader { proxy in
            StepScrollList(
                proxy: proxy,
                stepHeight: 26,
                onScrollPositionChanged: { firstVisibleIndex in
                    viewModel.currentScrollTopIndex = firstVisibleIndex
                }
            ) {
                lazyListContent(items: items)
            }
            .onChange(of: viewModel.scrollToRow) { _, targetIdx in
                handleScrollToRow(proxy: proxy, targetIdx: targetIdx)
            }
            .onChange(of: viewModel.scrollByStep) { _, scrollStep in
                handleScrollByStep(proxy: proxy, scrollStep: scrollStep)
            }
            .focusable(false)
        }
    }
    
    // MARK: - Subviews (解决编译器超时 Resolve compiler timeout)
    
    // 提取列表容器
    private func lazyListContent(items: [ClipboardHistory]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(items, id: \.id) { item in
                makeRowView(for: item)
            }
        }
    }
    
    // 提取 Row 的构建逻辑
    private func makeRowView(for item: ClipboardHistory) -> some View {
        RowView(
            item: item,
            isHovered: viewModel.hoveredItem == item,
            namespace: listNamespace,
            onHover: { isHovering in
                if isHovering {
                    // 如果需要反查 index 给 ViewModel，在这里查，不要在 View 构建时查
                    if viewModel.shouldRespondToHover {
                        viewModel.hoveredItem = item
                    }
                    viewModel.shouldRespondToHover = true
                }
            },
            onTap: {
                handleTap(for: item)
            }
        )
    }
    
    // MARK: - Logic Helpers (解决闭包过长)
    
    private func handleScrollToRow(proxy: StepScrollViewProxy, targetIdx: Int?) {
        guard let targetIdx = targetIdx else { return }
        Task {
            await Task.yield()
            proxy.scrollTo(index: targetIdx)
            // 确保 ViewModel 里同步更新选中态
            viewModel.hoveredIdx = targetIdx
            viewModel.scrollToRow = nil
        }
    }
    
    private func handleScrollByStep(proxy: StepScrollViewProxy, scrollStep: Int?) {
        guard let scrollStep = scrollStep else { return }
        proxy.scrollByStep(scrollStep)
        viewModel.scrollByStep = nil
    }
    
    
    private func handleTap(for item: ClipboardHistory) {
        if item.loadMore {
            viewModel.hoveredIdx = nil
            viewModel.loadHistories()
            return
        }

        if let modifiers = NSApp.currentEvent?.modifierFlags,
            modifiers.contains(.command)
        {
            handleMultiSelect(item: item)
        } else {
            handleSingleSelect(item: item)
        }
    }

    private func handleMultiSelect(item: ClipboardHistory) {
        // ...
    }

    private func handleSingleSelect(item: ClipboardHistory) {
        if let id = item.id { // 如果 id 已经是 Int64 非可选，直接 let id = item.id
            viewModel.selections = [id]
            viewModel.paste()
        }
        AppContext.shared.clipWindowController?.hideWindow(nil)
    }
    
    
    struct RowView: View {
        let item: ClipboardHistory
        let isHovered: Bool
        let namespace: Namespace.ID
        let onHover: (Bool) -> Void
        let onTap: () -> Void
        
        @State private var icon: NSImage?
        
        var body: some View {
            HStack {
                Image(nsImage: icon ?? fallbackIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text(item.showContent.trimmingCharacters(in: .whitespaces))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)

                Spacer()

                if isHovered {
                    Image(systemName: "return")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .contentShape(Rectangle())
            .onHover { hovering in
                onHover(hovering)
            }
            .background(
                Group {
                    if isHovered {
                        Color.clear
                            .glassEffect(
                                .clear.tint(Color.black.opacity(0.2)).interactive(),
                                in: .rect(cornerRadius: 6.0)
                            )
                            .glassEffectID(item.id, in: namespace)
                    }
                }
            )
            .gesture(
                TapGesture().onEnded {
                    // 调用传入的 onTap 闭包
                    onTap()
                }
            )
            .task(id: item.id) {
                if let cached = NSWorkspace.shared.checkAppIconCache(for: item.sourceApp) {
                    self.icon = cached
                    return
                }
                
                let resultIcon = await Task.detached(priority: .userInitiated) {
                    return NSWorkspace.shared.getAppIcon(for: item.sourceApp)
                }.value
                
                if !Task.isCancelled {
                    self.icon = resultIcon
                }
            }
        }

    }
}


// MARK: Preview View
struct HistoryPreviewView: View {
    
    @ObservedObject var viewModel: ClipboardViewModel
    
    var body: some View {
        Group {
            // 使用 if let 并在同一层级解包，逻辑更清晰
            if let item = viewModel.hoveredItem {
                if item.loadMore {
                    lodaMoreView
                } else {
                    contentView(for: item)
                        .padding(.horizontal)
                }
            } else {
                emptyView
            }
        }
    }
    
    // MARK: - Content Switcher
    @ViewBuilder
    private func contentView(for item: ClipboardHistory) -> some View {
        let contents = viewModel.contents
        let dateStr = item.createdAt?.smartDescription() ?? ""
        let dataType = NSPasteboard.PasteboardType(item.dataType)
        
        
        VStack(spacing: 12) {
            // 1. 主要内容区域 (使用 Spacer 把内容顶上去，元数据沉底)
            Group {
                if dataType.isFile() {
                    FilePreviewView(contents: contents)
                } else if dataType.isImage(), let first = contents.first {
                    ImagePreviewView(content: first)
                } else {
                    // 文本视图
                    LargeTextView(text: viewModel.text)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 2. 底部元数据区域
            MetadataFooterView(
                item: item,
                contents: contents,
                textLength: viewModel.text?.string.count,
                dateString: dateStr
            )
        }
    }
    
    var lodaMoreView: some View {
        Text("Load More Histories")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.5))
            Text("Select an item to preview")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
}


// MARK: Preview Subviews

struct FilePreviewView: View {
    let contents: [ClipboardHistoryContent]

    var body: some View {
        if contents.count > 1 {
            // 多文件列表
            StepScrollList(stepHeight: 28) { // 稍微增加高度方便阅读
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(contents, id: \.id) { item in
                        SingleFileRow(content: item)
                    }
                }
            }
        } else if let first = contents.first {
            VStack {
                SingleFileRow(content: first)
                Spacer()
                ImagePreviewView(content: first)
            }
        }
    }
}

/// 单个文件行视图
struct SingleFileRow: View {
    let content: ClipboardHistoryContent
    var isLarge: Bool = false

    var body: some View {
        // 安全解包 URL
        if let urlString = String(data: content.content, encoding: .utf8),
           let url = URL(string: urlString) {
            
            // 获取图标（建议使用之前优化的 AppUtils 或类似逻辑）
            let icon = NSWorkspace.shared.icon(forFile: url.path)

            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isLarge ? 64 : 24, height: isLarge ? 64 : 24)

                Text(url.lastPathComponent) // 只显示文件名，路径太长
                    .font(isLarge ? .title3 : .body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle) // 文件名通常中间省略更好

                if !isLarge {
                    Spacer()
                    // 只有列表模式才显示路径提示，或者悬停显示完整路径
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .padding(.vertical, 4)
        }
    }
}


/// 2. 图片预览组件
struct ImagePreviewView: View {
    let content: ClipboardHistoryContent
    
    // ⭐️ 改进：使用本地 State 管理图片加载，不依赖 ViewModel
    // 这样切换 Item 时，UI 会自动重置，不会显示上一张图
    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .shadow(radius: 4)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "photo.fill")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Image preview unavailable")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // ⭐️ 改进：当 ID 变化时自动重新加载
        .task(id: content.id) {
            isLoading = true
            image = nil // 清空旧图
            let result = await NSPasteboard.preview(for: content.content, with: content.type)
            guard !Task.isCancelled else { return }
            image = result
            isLoading = false
        }
    }
}


/// 3. 底部元数据组件
struct MetadataFooterView: View {
    let item: ClipboardHistory
    let contents: [ClipboardHistoryContent]
    let textLength: Int?
    let dateString: String
    
    var dataType: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(item.dataType)
    }

    var body: some View {
        HStack(spacing: 16) {
            // 左侧：类型信息
            HStack(spacing: 4) {
                Image(systemName: typeIcon)
                Text(typeDescription)
            }
            
            Spacer()
            
            // 右侧：时间
            Text("Copied at \(dateString)")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, 8)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.1)), alignment: .top)
    }

    // 辅助计算属性
    private var typeIcon: String {
        if dataType.isFile() { return "folder" }
        if dataType.isImage() { return "photo" }
        return "text.alignleft"
    }

    private var typeDescription: String {
        if dataType.isFile() {
            return "\(contents.count) file\(contents.count > 1 ? "s" : "")"
        }
        if dataType.isImage() {
            if let size = contents.first?.content.count {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            return "Image"
        }
        if let len = textLength {
            return "\(len) chars"
        }
        return "Text"
    }
}
