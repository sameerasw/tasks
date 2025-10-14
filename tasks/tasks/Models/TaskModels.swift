import Foundation

public struct TaskList: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String?
    public let kind: String?
    public let etag: String?
    public let updated: String?
    public let selfLink: String?
}

public struct TasksListResponse: Codable, Sendable {
    public let items: [TaskItem]?
}

public struct TaskItem: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String?
    public let notes: String?
    public let status: String?
    public let due: String?
    public let completed: String?
    public let deleted: Bool?
    public let hidden: Bool?
    public let links: [TaskLink]?
    public let webViewLink: String?
    public let parent: String?
    public let position: String?
    public let selfLink: String?
    public let etag: String?
}

public struct TaskLink: Codable, Sendable {
    public let type: String?
    public let description: String?
    public let link: String?
}

public struct TaskListsResponse: Codable, Sendable {
    public let items: [TaskList]?
}
