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
                        .background(Color.clear)
                        .transition(.opacity)
                    }
                }
            }
            .background(Color.clear)
            .focusable(false)
        }
        .padding(12)
        .background(
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
        let items = viewModel.itemsForTableView
        StepScrollViewReader { proxy in
            StepScrollList(
                proxy: proxy,
                stepHeight: 26,
                scrollToIndex: $viewModel.scrollToRow,
                onScrollPositionChanged: { firstVisibleIndex in
                    viewModel.currentScrollTopIndex = firstVisibleIndex
                }
            ) {
                lazyListContent(items: items)
            }
            .onChange(of: viewModel.scrollByStep) { _, scrollStep in
                handleScrollByStep(proxy: proxy, scrollStep: scrollStep)
            }
            .focusable(false)
        }
    }
    
    // MARK: - Subviews (Resolve compiler timeout)
    
    private func lazyListContent(items: [ClipboardHistory]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(items, id: \.id) { item in
                makeRowView(for: item)
            }
        }
    }
    
    private func makeRowView(for item: ClipboardHistory) -> some View {
        RowView(
            item: item,
            isHovered: viewModel.hoveredItem == item,
            namespace: listNamespace,
            onHover: { isHovering in
                if isHovering {
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
    
    // MARK: - Logic Helpers (Resolve long closure)
    
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
        if let id = item.id {
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

                Text(item.showContent.trimmingCharacters(in: .whitespacesAndNewlines))
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
            Group {
                if dataType.isFile() {
                    FilePreviewView(contents: contents)
                } else if dataType.isImage(), let first = contents.first {
                    ImagePreviewView(content: first)
                } else {
                    LargeTextView(text: viewModel.text)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            // Multi-file list
            StepScrollList(stepHeight: 28) {
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

/// Single file line view
struct SingleFileRow: View {
    let content: ClipboardHistoryContent
    var isLarge: Bool = false

    var body: some View {
        if let urlString = String(data: content.content, encoding: .utf8),
           let url = URL(string: urlString) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)

            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isLarge ? 64 : 24, height: isLarge ? 64 : 24)

                Text(url.lastPathComponent)
                    .font(isLarge ? .title3 : .body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !isLarge {
                    Spacer()
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


/// Image preview component
struct ImagePreviewView: View {
    let content: ClipboardHistoryContent
    
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
        .task(id: content.id) {
            isLoading = true
            image = nil
            let result = await NSPasteboard.preview(for: content.content, with: content.type)
            guard !Task.isCancelled else { return }
            image = result
            isLoading = false
        }
    }
}


/// Bottom metadata component
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
            HStack(spacing: 4) {
                Image(systemName: typeIcon)
                Text(typeDescription)
            }
            
            Spacer()
            
            Text("Copied at \(dateString)")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, 8)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.1)), alignment: .top)
    }

    private var typeIcon: String {
        if dataType.isFile() { return "folder" }
        if dataType.isImage() { return "photo" }
        return "text.alignleft"
    }

    private var typeDescription: String {
        if dataType.isFile() {
            return String(localized: "\(contents.count) files", comment: "Description for file count in history list")
        }
        if dataType.isImage() {
            if let size = contents.first?.content.count {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            return "Image"
        }
        if let len = textLength {
            return String(localized: "\(len) chars", comment: "Length of text content")
        }
        return "Text"
    }
}
