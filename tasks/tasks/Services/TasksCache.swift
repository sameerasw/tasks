import Foundation

struct CachedValue<T: Codable>: Codable {
    let storedAt: Date
    let value: T
}

actor TasksCache {
    private enum Constants {
        static let directoryName = "tasks-cache"
        static let taskListsFile = "tasklists.json"
        static let tasksPrefix = "tasks_"
        static let tasksSuffix = ".json"
    }

    private let fileManager = FileManager.default
    private let directoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let applicationSupportURLs = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        if let first = applicationSupportURLs.first {
            directoryURL = first.appendingPathComponent(Constants.directoryName, isDirectory: true)
        } else {
            directoryURL = fileManager.temporaryDirectory.appendingPathComponent(Constants.directoryName, isDirectory: true)
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }


    func cachedTaskLists() async -> CachedValue<[TaskList]>? {
        await loadValue(from: Constants.taskListsFile)
    }

    func saveTaskLists(_ lists: [TaskList]) async {
        let payload = CachedValue(storedAt: Date(), value: lists)
        await storeValue(payload, to: Constants.taskListsFile)
    }

    func cachedTasks(for listId: String) async -> CachedValue<[TaskItem]>? {
        await loadValue(from: tasksFileName(for: listId))
    }

    func saveTasks(_ tasks: [TaskItem], for listId: String) async {
        let payload = CachedValue(storedAt: Date(), value: tasks)
        await storeValue(payload, to: tasksFileName(for: listId))
    }

    func invalidateTasks(for listId: String) {
        let file = directoryURL.appendingPathComponent(tasksFileName(for: listId))
        try? fileManager.removeItem(at: file)
    }

    func invalidateAll() {
        try? fileManager.removeItem(at: directoryURL)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }


    private func loadValue<T: Codable>(from fileName: String) async -> CachedValue<T>? {
        let url = directoryURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }

        return await MainActor.run {
            do {
                return try self.decoder.decode(CachedValue<T>.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                return nil
            }
        }
    }

    private func storeValue<T: Codable>(_ value: CachedValue<T>, to fileName: String) async {
        let url = directoryURL.appendingPathComponent(fileName)

        let data: Data? = await MainActor.run {
            do {
                return try self.encoder.encode(value)
            } catch {
                print("Encoding error: \(error)")
                return nil
            }
        }

        guard let data else { return }

        try? data.write(to: url, options: .atomic)
    }

    private func tasksFileName(for listId: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.")
        let sanitizedScalars = listId.unicodeScalars.map { allowedCharacters.contains($0) ? Character($0) : "_" }
        let sanitized = String(sanitizedScalars)
        return Constants.tasksPrefix + sanitized + Constants.tasksSuffix
    }
}
