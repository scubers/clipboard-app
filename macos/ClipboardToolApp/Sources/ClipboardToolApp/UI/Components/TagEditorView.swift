import SwiftUI

struct TagEditorView: View {
    let itemID: String
    @ObservedObject var vm: MainPanelViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Callback when tags are modified (added or removed)
    var onTagsChanged: ((String) -> Void)? = nil
    
    @State private var tags: [ItemTag] = []
    @State private var newTagName: String = ""
    @State private var allTags: [TagWithCount] = []
    @State private var error: String?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Edit Tags")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("×") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 18, weight: .semibold))
            }
            
            // Existing tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags) { tag in
                        TagChip(tag: tag, onRemove: {
                            removeTag(tag)
                        })
                    }
                }
            }
            
            // Add new tag input
            HStack(spacing: 8) {
                TextField("Add tag...", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        addNewTag()
                    }
                
                Button("Add") {
                    addNewTag()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Suggestions (show matching existing tags)
            let suggestions = matchingTags()
            if !suggestions.isEmpty && !newTagName.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Existing tags:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(suggestions) { tag in
                            Button(tag.name) {
                                addExistingTag(tag)
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 11))
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            if let error = error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            loadTags()
            loadAllTags()
            isInputFocused = true
        }
    }
    
    private func loadTags() {
        Task {
            do {
                print("[TagEditor] Loading tags for item: \(itemID)")
                tags = try await repoGetTags(itemID: itemID)
                print("[TagEditor] Loaded \(tags.count) tags")
            } catch {
                print("[TagEditor] Failed to load tags: \(error)")
                self.error = "Failed to load tags: \(error)"
            }
        }
    }
    
    private func loadAllTags() {
        Task {
            do {
                print("[TagEditor] Loading all tags")
                allTags = try await repoListTags()
                print("[TagEditor] Loaded \(allTags.count) total tags")
            } catch {
                print("[TagEditor] Failed to load all tags: \(error)")
                // Silently fail for suggestions
            }
        }
    }
    
    private func matchingTags() -> [TagWithCount] {
        let query = newTagName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        
        return allTags.filter { tag in
            !tags.contains(where: { $0.id == tag.id }) &&
            tag.name.lowercased().contains(query)
        }.prefix(5).map { $0 }
    }
    
    private func addNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        // Check if tag already exists on this item
        if tags.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            error = "Tag '\(name)' already exists"
            return
        }
        
        Task {
            do {
                try await repoAddTag(itemID: itemID, tagName: name)
                newTagName = ""
                error = nil
                loadTags()
                loadAllTags()
                // Notify parent to refresh tags for this item
                onTagsChanged?(itemID)
            } catch {
                self.error = "Failed to add tag: \(error)"
            }
        }
    }
    
    private func addExistingTag(_ tag: TagWithCount) {
        Task {
            do {
                try await repoAddTag(itemID: itemID, tagName: tag.name)
                newTagName = ""
                error = nil
                loadTags()
                // Notify parent to refresh tags for this item
                onTagsChanged?(itemID)
            } catch {
                self.error = "Failed to add tag: \(error)"
            }
        }
    }
    
    private func removeTag(_ tag: ItemTag) {
        Task {
            do {
                try await repoRemoveTag(itemID: itemID, tagID: tag.id)
                loadTags()
                // Notify parent to refresh tags for this item
                onTagsChanged?(itemID)
            } catch {
                self.error = "Failed to remove tag: \(error)"
            }
        }
    }
    
    // MARK: - Repository Helpers
    
    private func repoGetTags(itemID: String) async throws -> [ItemTag] {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try vm.repo.getTags(itemID: itemID)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func repoListTags() async throws -> [TagWithCount] {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try vm.repo.listTags()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func repoAddTag(itemID: String, tagName: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    try vm.repo.addTag(itemID: itemID, tagName: tagName)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func repoRemoveTag(itemID: String, tagID: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    try vm.repo.removeTag(itemID: itemID, tagID: tagID)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Tag Chip Component

struct TagChip: View {
    let tag: ItemTag
    let onRemove: (() -> Void)?
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.system(size: 11, weight: .semibold))
            
            if isHovering && onRemove != nil {
                Button("×") {
                    onRemove?()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .bold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: tag.colorHex)?.opacity(0.15) ?? Color.gray.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(hex: tag.colorHex)?.opacity(0.3) ?? Color.gray.opacity(0.3), lineWidth: 1)
        )
        .foregroundStyle(Color(hex: tag.colorHex) ?? .gray)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
