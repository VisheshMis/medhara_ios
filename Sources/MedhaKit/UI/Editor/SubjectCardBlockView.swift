import SwiftUI
import AppKit

public struct SubjectCardBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block
    public var onSelectDoc: ((String) -> Void)?

    @State private var payload: SubjectCardPayload
    @State private var isEditing: Bool = false
    @State private var newLinkTitle: String = ""
    @State private var showAddLink: Bool = false

    public init(store: BlockStore, block: Block, onSelectDoc: ((String) -> Void)? = nil) {
        self.store = store
        self.block = block
        self.onSelectDoc = onSelectDoc
        _payload = State(initialValue: block.subjectCardPayload ?? SubjectCardPayload())
    }

    private var themeColors: (primary: Color, secondary: Color, bgGradient: LinearGradient) {
        switch payload.colorTheme.lowercased() {
        case "green":
            return (
                Color(red: 0.18, green: 0.65, blue: 0.45),
                Color(red: 0.12, green: 0.45, blue: 0.32),
                LinearGradient(colors: [Color.green.opacity(0.18), Color.mint.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case "purple":
            return (
                Color(red: 0.62, green: 0.42, blue: 0.88),
                Color(red: 0.45, green: 0.28, blue: 0.68),
                LinearGradient(colors: [Color.purple.opacity(0.20), Color.indigo.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case "orange":
            return (
                Color(red: 0.92, green: 0.55, blue: 0.22),
                Color(red: 0.75, green: 0.38, blue: 0.12),
                LinearGradient(colors: [Color.orange.opacity(0.20), Color.yellow.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case "pink":
            return (
                Color(red: 0.90, green: 0.42, blue: 0.62),
                Color(red: 0.70, green: 0.25, blue: 0.45),
                LinearGradient(colors: [Color.pink.opacity(0.20), Color.purple.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        default: // "blue"
            return (
                Color(red: 0.25, green: 0.55, blue: 0.88),
                Color(red: 0.15, green: 0.38, blue: 0.68),
                LinearGradient(colors: [Color.blue.opacity(0.20), Color.teal.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Banner
            ZStack(alignment: .bottomLeading) {
                if let banner = payload.bannerUrl, !banner.isEmpty {
                    AsyncImage(url: URL(string: banner)) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            themeColors.bgGradient
                        }
                    }
                    .frame(height: 70)
                    .clipped()
                } else {
                    themeColors.bgGradient
                        .frame(height: 64)
                }

                // Header Overlay Content
                HStack(alignment: .bottom) {
                    HStack(spacing: 8) {
                        Text(payload.courseCode)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .foregroundColor(themeColors.primary)
                            .cornerRadius(4)

                        Text(payload.status)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusBgColor.opacity(0.2))
                            .foregroundColor(statusTextColor)
                            .cornerRadius(4)
                    }

                    Spacer()

                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "ellipsis.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
            }

            // Card Body
            VStack(alignment: .leading, spacing: 10) {
                // Course Title
                if isEditing {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Course Name", text: $payload.subjectName)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            TextField("Code (e.g. CS 101)", text: $payload.courseCode)
                                .textFieldStyle(.roundedBorder)
                            TextField("Status (Active/Completed)", text: $payload.status)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            TextField("Instructor", text: $payload.instructor)
                                .textFieldStyle(.roundedBorder)
                            TextField("Schedule & Hall", text: $payload.scheduleRoom)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text("Theme:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(["blue", "purple", "green", "orange", "pink"], id: \.self) { col in
                                Button(action: {
                                    payload.colorTheme = col
                                    saveChanges()
                                }) {
                                    Circle()
                                        .fill(colorForName(col))
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: payload.colorTheme == col ? 2 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 4)
                } else {
                    Text(payload.subjectName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MedhaTheme.Colors.textPrimary)

                    // Instructor and Room Details
                    HStack(spacing: 12) {
                        Label(payload.instructor, systemImage: "person.crop.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Label(payload.scheduleRoom, systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .opacity(0.6)

                // Quick Links / Sections
                VStack(alignment: .leading, spacing: 6) {
                    Text("SUBJECT HUBS")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.secondary.opacity(0.8))

                    FlowLayout(spacing: 6) {
                        ForEach(payload.quickLinks) { link in
                            quickLinkPill(link)
                        }

                        if showAddLink {
                            HStack(spacing: 4) {
                                TextField("New hub...", text: $newLinkTitle)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11))
                                    .frame(width: 90)
                                    .onSubmit {
                                        addNewQuickLink()
                                    }
                                Button(action: addNewQuickLink) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(themeColors.primary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        } else {
                            Button(action: { showAddLink = true }) {
                                Label("Add link", systemImage: "plus")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Dedicated Subject Note Page Link
                HStack {
                    Spacer()
                    if let targetDocId = payload.linkedDocId {
                        Button(action: {
                            onSelectDoc?(targetDocId)
                        }) {
                            HStack(spacing: 4) {
                                Text("Open Subject Notebook")
                                    .font(.system(size: 11, weight: .semibold))
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(themeColors.primary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: createDedicatedDoc) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 11))
                                Text("Create Dedicated Notebook")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(themeColors.primary.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .onChange(of: isEditing) { newValue in
            if !newValue {
                saveChanges()
            }
        }
    }

    private func quickLinkPill(_ link: SubjectCardLink) -> some View {
        HStack(spacing: 4) {
            Image(systemName: link.icon)
                .font(.system(size: 10))
                .foregroundColor(themeColors.primary)
            Text(link.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)

            if isEditing {
                Button(action: {
                    payload.quickLinks.removeAll { $0.id == link.id }
                    saveChanges()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .onTapGesture {
            if let docId = link.targetDocId {
                onSelectDoc?(docId)
            }
        }
    }

    private func addNewQuickLink() {
        let title = newLinkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            showAddLink = false
            return
        }
        payload.quickLinks.append(SubjectCardLink(title: title, icon: "doc.text"))
        newLinkTitle = ""
        showAddLink = false
        saveChanges()
    }

    private func createDedicatedDoc() {
        let newDoc = store.createDocument(title: "\(payload.courseCode): \(payload.subjectName)", notebookId: block.notebookId)
        payload.linkedDocId = newDoc.id
        saveChanges()
        onSelectDoc?(newDoc.id)
    }

    private func saveChanges() {
        store.updateBlockContent(id: block.id, content: payload.serialize())
    }

    private var statusBgColor: Color {
        switch payload.status.lowercased() {
        case "active": return .green
        case "completed": return .purple
        case "upcoming": return .blue
        default: return .secondary
        }
    }

    private var statusTextColor: Color {
        switch payload.status.lowercased() {
        case "active": return .green
        case "completed": return .purple
        case "upcoming": return .blue
        default: return .secondary
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return .blue
        }
    }
}

/// Simple flexible wrapping flow layout for quick links
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
