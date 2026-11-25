import Foundation
import SwiftUI

struct CategoryItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String = "#F59E0B"

    var color: Color {
        Color(hex: colorHex) ?? .orange
    }
}

struct SnippetItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var categoryId: UUID
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var copyCount: Int = 0
}

struct QuickNoteData: Codable {
    var categories: [CategoryItem]
    var snippets: [SnippetItem]
}

@MainActor
final class SnippetStore: ObservableObject {
    @Published var categories: [CategoryItem] = []
    @Published var snippets: [SnippetItem] = []
    @Published var selectedCategoryId: UUID? = nil // nil means "全部"
    @Published var searchText: String = ""
    @Published var loadWarningMessage: String? = nil

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("QuickNote", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            NSLog("[QuickNote] Failed to create AppSupport dir: %@", error.localizedDescription)
        }
        self.fileURL = dir.appendingPathComponent("snippets.json")
        load()
    }

    var filteredSnippets: [SnippetItem] {
        snippets.filter { item in
            let matchesCategory = (selectedCategoryId == nil) || (item.categoryId == selectedCategoryId)
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty { return matchesCategory }
            return matchesCategory && (
                item.title.localizedCaseInsensitiveContains(q) ||
                item.content.localizedCaseInsensitiveContains(q)
            )
        }
    }

    func category(for id: UUID) -> CategoryItem? {
        categories.first { $0.id == id }
    }

    func addSnippet(title: String, content: String, categoryId: UUID) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = SnippetItem(
            title: cleanTitle.isEmpty ? String(trimmedContent.prefix(20)) : cleanTitle,
            content: content,
            categoryId: categoryId
        )
        snippets.insert(item, at: 0)
        save()
    }

    func updateSnippet(_ item: SnippetItem, title: String, content: String, categoryId: UUID) {
        guard let idx = snippets.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        snippets[idx].title = cleanTitle.isEmpty ? String(trimmedContent.prefix(20)) : cleanTitle
        snippets[idx].content = content
        snippets[idx].categoryId = categoryId
        snippets[idx].updatedAt = Date()
        save()
    }

    func deleteSnippet(_ item: SnippetItem) {
        snippets.removeAll { $0.id == item.id }
        save()
    }

    func recordCopy(_ item: SnippetItem) {
        guard let idx = snippets.firstIndex(where: { $0.id == item.id }) else { return }
        snippets[idx].copyCount += 1
        save()
    }

    func addCategory(name: String, colorHex: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let cat = CategoryItem(name: clean, colorHex: colorHex)
        categories.append(cat)
        save()
    }

    func renameCategory(_ cat: CategoryItem, newName: String, colorHex: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let idx = categories.firstIndex(where: { $0.id == cat.id }) else { return }
        categories[idx].name = clean
        categories[idx].colorHex = colorHex
        save()
    }

    func deleteCategory(_ cat: CategoryItem) {
        guard categories.count > 1 else { return }
        categories.removeAll { $0.id == cat.id }
        if selectedCategoryId == cat.id {
            selectedCategoryId = nil
        }
        if let fallback = categories.first {
            for i in snippets.indices where snippets[i].categoryId == cat.id {
                snippets[i].categoryId = fallback.id
            }
        }
        save()
    }

    func save() {
        let data = QuickNoteData(categories: categories, snippets: snippets)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[QuickNote] Failed to save snippets to %@: %@", fileURL.path, error.localizedDescription)
        }
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            seedDefaults()
            return
        }

        do {
            let raw = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(QuickNoteData.self, from: raw)
            if decoded.categories.isEmpty {
                throw NSError(domain: "QuickNote", code: 1, userInfo: [NSLocalizedDescriptionKey: "Categories array is empty"])
            }
            self.categories = decoded.categories
            self.snippets = decoded.snippets
        } catch {
            NSLog("[QuickNote] Failed to load snippets.json: %@", error.localizedDescription)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let stamp = formatter.string(from: Date())
            let backupURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent("snippets.json.corrupt-\(stamp)")
            do {
                try fm.copyItem(at: fileURL, to: backupURL)
                NSLog("[QuickNote] Backed up corrupt file to %@", backupURL.path)
            } catch {
                NSLog("[QuickNote] Failed to back up corrupt file: %@", error.localizedDescription)
            }
            self.categories = [CategoryItem(name: "默认", colorHex: "#3B82F6")]
            self.snippets = []
            self.loadWarningMessage = "数据文件解析失败，原文件已备份为 \(backupURL.lastPathComponent)"
        }
    }

    private func seedDefaults() {
        let work = CategoryItem(name: "工作常用", colorHex: "#3B82F6")
        let account = CategoryItem(name: "账号邮箱", colorHex: "#10B981")
        let address = CategoryItem(name: "地址电话", colorHex: "#F59E0B")
        let reply = CategoryItem(name: "快捷回复", colorHex: "#8B5CF6")

        self.categories = [work, account, address, reply]
        self.snippets = [
            SnippetItem(title: "示例：常用邮箱", content: "example@company.com", categoryId: account.id),
            SnippetItem(title: "示例：收货地址", content: "北京市朝阳区建国路 88 号（请点击右侧编辑替换为你的真实信息）", categoryId: address.id),
            SnippetItem(title: "示例：会议回复", content: "收到，我先确认一下相关材料，稍后同步给您。", categoryId: reply.id),
            SnippetItem(title: "示例：项目备注", content: "点击任意一条便利贴，内容会立即复制到剪贴板，切回目标窗口按 ⌘V 即可粘贴。", categoryId: work.id)
        ]
        save()
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb), hexSanitized.count == 6 else { return nil }
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
