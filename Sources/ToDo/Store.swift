import Foundation
import Combine

/// One written line of the list.
struct Line: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var done = false
    var pinned = false
    /// The day the line was written. Kept on disk, but nothing reads it: the
    /// app does not mark carried-over items as overdue.
    var written = Date()
    var finished: Date?

}

struct Note: Codable {
    var lines: [Line] = []
    var paper: Tk.Paper = .chalk
}

@MainActor
final class Store: ObservableObject {
    @Published private(set) var lines: [Line] = []
    @Published var paper: Tk.Paper = .chalk { didSet { save() } }

    /// Lines still to do.
    var openCount: Int { lines.filter { !$0.done }.count }
    var doneCount: Int { lines.filter(\.done).count }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Store.defaultFileURL()
        load()
    }

    // MARK: Editing

    /// Append the line and reset the field yourself, so an empty or
    /// whitespace-only entry is dropped silently rather than added as a blank row.
    func add(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        lines.append(Line(text: t))
        save()
    }

    func toggle(_ id: Line.ID) {
        guard let i = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[i].done.toggle()
        lines[i].finished = lines[i].done ? Date() : nil
        // Keep struck lines in place until the person clears them — seeing the
        // strike is the reward, so nothing reorders or fades out here.
        save()
    }

    /// Rewrites an item in place. An empty rewrite keeps the old words — a
    /// line wiped by accident should not vanish; delete is on the menu.
    func rename(_ id: Line.ID, to text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = lines.firstIndex(where: { $0.id == id }),
              lines[i].text != t else { return }
        lines[i].text = t
        save()
    }

    /// Any number of lines can be pinned; each pin is independent, as
    /// `TodoItem`'s card says.
    func togglePin(_ id: Line.ID) {
        guard let i = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[i].pinned.toggle()
        save()
    }

    /// Deleting is immediate — no dialog, which is right for a sticky note, but
    /// only because it is reversible. The footer owes the person an undo for a
    /// few seconds afterwards.
    @Published private(set) var undoableDelete: Line?
    private var undoIndex = 0
    private var undoExpiry: Task<Void, Never>?

    func delete(_ id: Line.ID) {
        guard let i = lines.firstIndex(where: { $0.id == id }) else { return }
        undoIndex = i
        undoableDelete = lines.remove(at: i)
        save()

        undoExpiry?.cancel()
        undoExpiry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.undoableDelete = nil
        }
    }

    /// Puts the line back where it was.
    func undoDelete() {
        guard let line = undoableDelete else { return }
        lines.insert(line, at: min(undoIndex, lines.count))
        undoableDelete = nil
        undoExpiry?.cancel()
        save()
    }

    func clearDone() {
        lines.removeAll(\.done)
        save()
    }

    // MARK: Storage

    private static func defaultFileURL() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("to do", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("note.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let note = try? JSONDecoder().decode(Note.self, from: data)
        else { return }
        lines = note.lines
        paper = note.paper
    }

    private func save() {
        let note = Note(lines: lines, paper: paper)
        guard let data = try? JSONEncoder().encode(note) else { return }
        // Atomic, so a crash mid-write never leaves a half-written list.
        try? data.write(to: fileURL, options: .atomic)
    }
}

private extension Array {
    mutating func removeAll(_ keyPath: KeyPath<Element, Bool>) {
        removeAll { $0[keyPath: keyPath] }
    }
}
