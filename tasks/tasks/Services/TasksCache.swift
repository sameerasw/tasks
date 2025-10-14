import Foundation

struct CachedValue<T: Codable>: Codable {
    let storedAt: Date
    let value: T
}

final class TasksCache {
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
    private let queue = DispatchQueue(label: "com.sameerasw.tasks.cache", qos: .utility, attributes: [], autoreleaseFrequency: .inherit, target: nil)

    init() {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        directoryURL = baseDirectory.appendingPathComponent(Constants.directoryName, isDirectory: true)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        ensureDirectoryExists()
    }

    func cachedTaskLists() -> CachedValue<[TaskList]>? {
        loadValue(from: Constants.taskListsFile)
    }

    func saveTaskLists(_ lists: [TaskList]) {
        let payload = CachedValue(storedAt: Date(), value: lists)
        storeValue(payload, to: Constants.taskListsFile)
    }

    func cachedTasks(for listId: String) -> CachedValue<[TaskItem]>? {
        loadValue(from: tasksFileName(for: listId))
    }

    func saveTasks(_ tasks: [TaskItem], for listId: String) {
        let payload = CachedValue(storedAt: Date(), value: tasks)
        storeValue(payload, to: tasksFileName(for: listId))
    }

    func invalidateTasks(for listId: String) {
        let file = directoryURL.appendingPathComponent(tasksFileName(for: listId))
        queue.sync {
            try? fileManager.removeItem(at: file)
        }
    }

    func invalidateAll() {
        queue.sync {
            try? fileManager.removeItem(at: directoryURL)
            ensureDirectoryExists()
        }
    }


    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private func loadValue<T: Codable>(from fileName: String) -> CachedValue<T>? {
        let url = directoryURL.appendingPathComponent(fileName)
        return queue.sync {
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(CachedValue<T>.self, from: data)
        }
    }

    private func storeValue<T: Codable>(_ value: CachedValue<T>, to fileName: String) {
        let url = directoryURL.appendingPathComponent(fileName)
        queue.sync {
            guard let data = try? encoder.encode(value) else { return }
            try? data.write(to: url, options: [.atomic])
        }
    }

    private func tasksFileName(for listId: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.")
        let sanitizedScalars = listId.unicodeScalars.map { allowedCharacters.contains($0) ? Character($0) : "_" }
        let sanitized = String(sanitizedScalars)
        return Constants.tasksPrefix + sanitized + Constants.tasksSuffix
    }
}
