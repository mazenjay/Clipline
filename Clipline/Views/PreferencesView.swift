//
//  PreferencesView.swift
//  Clipline
//
//  Created by mazhj on 2025/12/7.
//

import SwiftUI
import UniformTypeIdentifiers
import KeyboardShortcuts

struct PreferencesView: View {

    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
//        ScrollView {
//
//        }
        HistoryTab(viewModel: viewModel)
        
    }
}

struct LabelColumn: View {
    let text: String
    var body: some View {
        Text(text)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.trailing)  // 文字内部右对齐
            .lineLimit(1)  // 禁止换行
//            .fixedSize()   再次确保文字本身不被压缩
            .frame(width: 130, alignment: .trailing)  // ⭐️ 关键：固定容器宽度
            .padding(.trailing, 8)  // 和右侧内容保持间距
    }
}

struct HistoryTab: View {
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Grid(
                alignment: .topLeading,
                horizontalSpacing: 12,
                verticalSpacing: 20
            ) {
                GridRow {
                    LabelColumn(text: "Clipboard History:")
                        .padding(.top, 12)  // 微调对齐

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            HistoryOptionCard(
                                title: "Keep Plain Text",
                                isEnabled: $viewModel.keepPlainText,
                                duration: $viewModel.plainTextDuration
                            )
                            HistoryOptionCard(
                                title: "Keep Images",
                                isEnabled: $viewModel.keepImages,
                                duration: $viewModel.imagesDuration
                            )
                            HistoryOptionCard(
                                title: "Keep File Lists",
                                isEnabled: $viewModel.keepFileLists,
                                duration: $viewModel.fileListsDuration
                            )
                            HistoryOptionCard(
                                title: "Keep Others",
                                isEnabled: $viewModel.keepOthers,
                                duration: $viewModel.othersDuration
                            )
                        }

                        Text(
                            "When disabled, the clipboard viewer can still show your snippets."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                GridRow {
                    LabelColumn(text: "Viewer Hotkey:")
                        .padding(.top, 4)
                    
                    KeyboardShortcuts.Recorder(for: Action.toggleClipboardWindow.name)
                }
                
                GridRow {
                    LabelColumn(text: "Ignored Apps:")
                        .padding(.top, 4)
                    
                    IgnoredAppsListView(viewModel: viewModel)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct HistoryOptionCard: View {
    let title: String
    @Binding var isEnabled: Bool
    @Binding var duration: HistoryDuration

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(title, isOn: $isEnabled)
                .toggleStyle(.checkbox)
                .font(.system(size: 13, weight: .medium))

            HStack {
                Picker("", selection: $duration) {
                    ForEach(HistoryDuration.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 120)
                .disabled(!isEnabled)

                // 上下箭头图标装饰 (macOS Picker 自带，这里为了对齐不需要额外加)
            }
        }
        .padding(12)
        .frame(width: 150, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )

    }
}

struct IgnoredAppsListView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    @State private var selection: String?  // 选中的 Bundle ID

    var body: some View {
        VStack(alignment: .leading) {
            // 列表区域
            List(selection: $selection) {
                ForEach(viewModel.ignoredApps, id: \.self) { bundleId in
                    HStack {
                        // 获取 App 图标
                        if let path = NSWorkspace.shared.urlForApplication(
                            withBundleIdentifier: bundleId
                        )?.path {
                            Image(
                                nsImage: NSWorkspace.shared.icon(forFile: path)
                            )
                            .resizable()
                            .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "app.dashed")
                        }

                        // 显示 Bundle ID 或 尝试获取 App 名称
                        Text(appName(for: bundleId) ?? bundleId)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(bundleId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(bundleId)
                }
            }
            .frame(width: 450, height: 250)  // 固定高度
            .border(Color.gray.opacity(0.2))
            .background(Color(nsColor: .controlBackgroundColor))

            // 按钮区域 (+ -)
            HStack(spacing: 0) {
                Button(action: addApp) {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .overlay(
                    Rectangle().frame(width: 1).foregroundColor(
                        Color.gray.opacity(0.2)
                    ),
                    alignment: .trailing
                )

                Button(action: removeApp) {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .disabled(selection == nil)

                Spacer()
            }
            .frame(width: 450, height: 24)
            .background(Color(nsColor: .controlBackgroundColor))
            .border(Color.gray.opacity(0.2))

            Text("Content copied from these apps will not be saved to history.\nOnly focusable applications can be ignored.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // 辅助方法：获取 App 名称
    func appName(for bundleId: String) -> String? {
        guard
            let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleId
            )
        else { return nil }
        return FileManager.default.displayName(atPath: url.path)
    }

    // Action: 添加 App
    func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Select App"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let bundle = Bundle(url: url),
                    let id = bundle.bundleIdentifier
                {
                    viewModel.addIgnoredApp(id)
                }
            }
        }
    }

    // Action: 删除 App
    func removeApp() {
        if let sel = selection {
            viewModel.removeIgnoredApp(sel)
            selection = nil
        }
    }
}
