import SwiftUI
import AppKit

public struct CalendarEmbedBlockView: View {
    @ObservedObject public var store: BlockStore
    public let block: Block

    @State private var payload: CalendarEmbedPayload
    @State private var showSettings: Bool = false
    @State private var newEventTitle: String = ""
    @State private var newEventDate: Date = Date()
    @State private var newEventTag: String = "Study"
    @State private var showAddEvent: Bool = false
    @State private var gCalInput: String = ""

    private let tags = ["Exam", "Assignment", "Lecture", "Study"]

    public init(store: BlockStore, block: Block) {
        self.store = store
        self.block = block
        let p = block.calendarEmbedPayload ?? CalendarEmbedPayload()
        _payload = State(initialValue: p)
        _gCalInput = State(initialValue: p.googleCalendarUrl ?? "")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)

                    Text(payload.calendarTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MedhaTheme.Colors.textPrimary)
                }

                Spacer()

                // Google Calendar Link Button
                if let urlStr = payload.googleCalendarUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                            Text("Google Calendar")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Settings Tray (Google Calendar URL & Title)
            if showSettings {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Calendar Title", text: $payload.calendarTitle)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        TextField("Google Calendar URL (https://calendar.google.com/...)", text: $gCalInput)
                            .textFieldStyle(.roundedBorder)

                        Button("Save") {
                            payload.googleCalendarUrl = gCalInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            saveChanges()
                            showSettings = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Text("Tip: Link your Google Calendar to open your schedule in one click.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            Divider()
                .opacity(0.6)

            // Study Agenda Events
            VStack(spacing: 6) {
                if payload.events.isEmpty {
                    HStack {
                        Spacer()
                        Text("No scheduled study events. Click '+ Add Event' below.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(payload.events) { ev in
                        eventRow(ev)
                    }
                }
            }

            // Add Event Bar
            if showAddEvent {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Event title (e.g. Chapter 4 Quiz, Lab 2)...", text: $newEventTitle)
                            .textFieldStyle(.roundedBorder)

                        DatePicker("", selection: $newEventDate, displayedComponents: [.date])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    HStack {
                        Text("Category:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $newEventTag) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag).tag(tag)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)

                        Spacer()

                        Button("Cancel") {
                            showAddEvent = false
                            newEventTitle = ""
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                        Button("Add") {
                            commitNewEvent()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                Button(action: { showAddEvent = true }) {
                    Label("Add study event or deadline", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    private func eventRow(_ ev: StudyCalendarEvent) -> some View {
        HStack(spacing: 10) {
            Button(action: {
                toggleEventCompletion(ev.id)
            }) {
                Image(systemName: ev.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(ev.isCompleted ? .accentColor : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(ev.title)
                    .font(.system(size: 12, weight: .medium))
                    .strikethrough(ev.isCompleted)
                    .foregroundColor(ev.isCompleted ? .secondary : MedhaTheme.Colors.textPrimary)

                HStack(spacing: 6) {
                    Text(ev.dateString)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    if !ev.timeString.isEmpty {
                        Text("• \(ev.timeString)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            tagBadge(ev.tag)

            Button(action: {
                payload.events.removeAll { $0.id == ev.id }
                saveChanges()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }

    private func tagBadge(_ tag: String) -> some View {
        let (color, bg) = tagColor(tag)
        return Text(tag)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private func tagColor(_ tag: String) -> (Color, Color) {
        switch tag.lowercased() {
        case "exam":
            return (.red, Color.red.opacity(0.15))
        case "assignment":
            return (.orange, Color.orange.opacity(0.15))
        case "lecture":
            return (.blue, Color.blue.opacity(0.15))
        default: // "study"
            return (.green, Color.green.opacity(0.15))
        }
    }

    private func toggleEventCompletion(_ id: String) {
        if let idx = payload.events.firstIndex(where: { $0.id == id }) {
            payload.events[idx].isCompleted.toggle()
            saveChanges()
        }
    }

    private func commitNewEvent() {
        let title = newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: newEventDate)

        let ev = StudyCalendarEvent(
            title: title,
            dateString: dateStr,
            timeString: "All Day",
            tag: newEventTag,
            isCompleted: false
        )

        payload.events.append(ev)
        newEventTitle = ""
        showAddEvent = false
        saveChanges()
    }

    private func saveChanges() {
        store.updateBlockContent(id: block.id, content: payload.serialize())
    }
}
