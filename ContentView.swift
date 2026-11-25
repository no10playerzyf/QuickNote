import SwiftUI
import AppKit

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ContentView: View {
    @ObservedObject var store: SnippetStore
    @Binding var isPinned: Bool
    var onCopyAndMaybeHide: (SnippetItem) -> Void
    var onClose: () -> Void

    @State private var copiedKey: String? = nil
    @State private var toastMessage: String? = nil
    @State private var toastToken: UUID = UUID()
    @State private var showingAddSheet = false
    @State private var editingSnippet: SnippetItem? = nil
    @State private var showingCategoryManager = false
    @State private var hoveredSnippetId: UUID? = nil
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                headerBar
                if let warning = store.loadWarningMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        Text(warning)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            store.loadWarningMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
                searchBar
                categoryBar
                Divider().opacity(0.35)
                snippetList
            }

            if let toast = toastMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThickMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 380, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
        .sheet(isPresented: $showingAddSheet) {
            SnippetEditorSheet(
                store: store,
                snippet: nil,
                defaultCategoryId: store.selectedCategoryId ?? store.categories.first?.id ?? UUID()
            )
        }
        .sheet(item: $editingSnippet) { item in
            SnippetEditorSheet(
                store: store,
                snippet: item,
                defaultCategoryId: item.categoryId
            )
        }
        .sheet(isPresented: $showingCategoryManager) {
            CategoryManagerSheet(store: store)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.9), Color.orange.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: .orange.opacity(0.35), radius: 4, y: 2)
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text("贴贴便利贴")
                        .font(.system(size: 14, weight: .bold))
                    Text("⌥V")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
                }
                Text("\(store.snippets.count) 条 · 点击即复制")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                showingCategoryManager = true
            } label: {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("管理分类")

            Button {
                isPinned.toggle()
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 13))
                    .foregroundColor(isPinned ? .orange : .secondary)
                    .rotationEffect(.degrees(isPinned ? 0 : 35))
            }
            .buttonStyle(.plain)
            .help(isPinned ? "已钉住（点击取消固定）" : "钉住窗口（复制后不自动隐藏）")

            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("新增")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .foregroundColor(.white)
                .shadow(color: .accentColor.opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .help("新增便利贴条目")

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.75))
            }
            .buttonStyle(.plain)
            .help("隐藏 (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSearchFocused ? .accentColor : .secondary)

            TextField("搜索标题或内容…", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isSearchFocused)

            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(isSearchFocused ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(.easeOut(duration: 0.15), value: isSearchFocused)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                CategoryPill(
                    title: "全部",
                    color: .accentColor,
                    isSelected: store.selectedCategoryId == nil,
                    count: store.snippets.count
                ) {
                    store.selectedCategoryId = nil
                }

                ForEach(store.categories) { cat in
                    let count = store.snippets.filter { $0.categoryId == cat.id }.count
                    CategoryPill(
                        title: cat.name,
                        color: cat.color,
                        isSelected: store.selectedCategoryId == cat.id,
                        count: count
                    ) {
                        store.selectedCategoryId = cat.id
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var snippetList: some View {
        Group {
            if store.filteredSnippets.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: store.searchText.isEmpty ? "tray" : "magnifyingglass")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.accentColor.opacity(0.7))
                    }
                    VStack(spacing: 4) {
                        Text(store.searchText.isEmpty ? "该分类下暂无条目" : "未找到匹配的条目")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(store.searchText.isEmpty ? "点右上角「新增」，把常用内容存进来" : "换个关键词试试")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Button("点击新增一条") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.filteredSnippets) { item in
                            SnippetCard(
                                item: item,
                                category: store.category(for: item.categoryId),
                                copiedKey: copiedKey,
                                isHovered: hoveredSnippetId == item.id,
                                onCopyText: { text, key, label in
                                    copyText(text, key: key, label: label, item: item)
                                },
                                onEdit: {
                                    editingSnippet = item
                                },
                                onDelete: {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        store.deleteSnippet(item)
                                    }
                                }
                            )
                            .onHover { hovering in
                                hoveredSnippetId = hovering ? item.id : nil
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func copyText(_ text: String, key: String, label: String, item: SnippetItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        store.recordCopy(item)

        let token = UUID()
        toastToken = token

        withAnimation(.easeOut(duration: 0.15)) {
            copiedKey = key
            let preview = label.count > 16 ? String(label.prefix(16)) + "…" : label
            toastMessage = "已复制「\(preview)」，按 ⌘V 即可粘贴"
        }

        onCopyAndMaybeHide(item)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation {
                if copiedKey == key { copiedKey = nil }
                if toastToken == token { toastMessage = nil }
            }
        }
    }
}

struct CategoryPill: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected ? color.opacity(0.92) : Color.primary.opacity(0.06),
                in: Capsule()
            )
            .shadow(color: isSelected ? color.opacity(0.35) : .clear, radius: 4, y: 2)
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct SnippetCard: View {
    let item: SnippetItem
    let category: CategoryItem?
    let copiedKey: String?
    let isHovered: Bool
    let onCopyText: (_ text: String, _ key: String, _ label: String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var hoveredLineIdx: Int? = nil

    private var lines: [String] {
        item.content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var isMultiLine: Bool { lines.count > 1 }
    private var cardAllKey: String { "\(item.id.uuidString)-all" }
    private var isCardAllCopied: Bool { copiedKey == cardAllKey }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            if isMultiLine {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        let lineKey = "\(item.id.uuidString)-\(idx)"
                        let isLineCopied = (copiedKey == lineKey)
                        let isLineHovered = (hoveredLineIdx == idx)
                        Button {
                            onCopyText(line, lineKey, line)
                        } label: {
                            HStack(spacing: 6) {
                                Text(line)
                                    .font(.system(size: 12))
                                    .foregroundColor(isLineCopied ? .green : .primary.opacity(0.85))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if isLineCopied {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                } else if isLineHovered {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isLineCopied ? Color.green.opacity(0.14) : (isLineHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.03)))
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredLineIdx = hovering ? idx : (hoveredLineIdx == idx ? nil : hoveredLineIdx)
                        }
                    }
                }
            } else {
                Button {
                    onCopyText(item.content, cardAllKey, item.title)
                } label: {
                    Text(item.content)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 11)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCardAllCopied ? Color.green.opacity(0.1) : (isHovered ? Color.primary.opacity(0.07) : Color.primary.opacity(0.04)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isCardAllCopied ? Color.green.opacity(0.45) : Color.primary.opacity(0.07), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            // 左侧分类色条
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(category?.color ?? Color.orange)
                .frame(width: 3.5)
                .padding(.vertical, 10)
                .padding(.leading, 0.5)
                .opacity(isCardAllCopied ? 0.9 : 0.85)
        }
        .shadow(color: isHovered ? .black.opacity(0.08) : .clear, radius: 8, y: 3)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isMultiLine {
                onCopyText(item.content, cardAllKey, item.title)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            if let cat = category {
                Text(cat.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(cat.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(cat.color.opacity(0.14), in: Capsule())
            }

            Text(item.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            if isCardAllCopied {
                Label("已复制", systemImage: "checkmark")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.green)
            } else if isHovered {
                HStack(spacing: 5) {
                    if isMultiLine {
                        Button {
                            onCopyText(item.content, cardAllKey, item.title)
                        } label: {
                            Text("复制全部")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("复制整条全部内容")
                    }

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(4)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("编辑")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.85))
                            .padding(4)
                            .background(Color.red.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("删除")
                }
            } else if !isMultiLine {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.55))
            }
        }
    }
}

struct SnippetEditorSheet: View {
    @ObservedObject var store: SnippetStore
    let snippet: SnippetItem?
    let defaultCategoryId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var categoryId: UUID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(snippet == nil ? "新增便利贴条目" : "编辑便利贴条目")
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("标题（可选，方便检索）")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                TextField("例如：公司税号 / 常用邮箱", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("所属分类")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                Picker("", selection: $categoryId) {
                    ForEach(store.categories) { cat in
                        Text(cat.name).tag(cat.id)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("复制内容")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                TextEditor(text: $content)
                    .font(.system(size: 12.5))
                    .frame(height: 130)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15)))
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    if let s = snippet {
                        store.updateSnippet(s, title: title, content: content, categoryId: categoryId)
                    } else {
                        store.addSnippet(title: title, content: content, categoryId: categoryId)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 330)
        .onAppear {
            if let s = snippet {
                title = s.title
                content = s.content
                categoryId = s.categoryId
            } else {
                categoryId = defaultCategoryId
            }
        }
    }
}

struct CategoryManagerSheet: View {
    @ObservedObject var store: SnippetStore
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""
    @State private var selectedColor: String = "#3B82F6"
    private let palette = ["#3B82F6", "#10B981", "#F59E0B", "#8B5CF6", "#EF4444", "#EC4899", "#06B6D4"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("管理分类")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            HStack(spacing: 8) {
                TextField("新分类名称", text: $newName)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 4) {
                    ForEach(palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex) ?? .blue)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle().stroke(Color.primary, lineWidth: selectedColor == hex ? 1.5 : 0)
                            )
                            .onTapGesture { selectedColor = hex }
                    }
                }

                Button("添加") {
                    store.addCategory(name: newName, colorHex: selectedColor)
                    newName = ""
                }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.categories) { cat in
                        CategoryRow(store: store, category: cat)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(16)
        .frame(width: 340)
    }
}

struct CategoryRow: View {
    @ObservedObject var store: SnippetStore
    let category: CategoryItem
    @State private var name: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(category.color)
                .frame(width: 10, height: 10)

            TextField("分类名", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    store.renameCategory(category, newName: name, colorHex: category.colorHex)
                }

            Button {
                store.deleteCategory(category)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(store.categories.count > 1 ? .red : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(store.categories.count <= 1)
            .help(store.categories.count <= 1 ? "至少保留一个分类" : "删除分类（条目将移至首个分类）")
        }
        .onAppear { name = category.name }
    }
}
