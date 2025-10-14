import Foundation

struct TaskList: Codable, Identifiable, Sendable {
    let id: String
    let title: String?
    let kind: String?
    let etag: String?
    let updated: String?
    let selfLink: String?
}

struct TasksListResponse: Codable, Sendable {
    let items: [TaskItem]?
}

struct TaskItem: Codable, Identifiable, Sendable {
    let id: String
    let title: String?
    let notes: String?
    let status: String?
    let due: String?
    let completed: String?
    let deleted: Bool?
    let hidden: Bool?
    let links: [TaskLink]?
    let webViewLink: String?
    let parent: String?
    let position: String?
    let selfLink: String?
    let etag: String?
}

struct TaskLink: Codable, Sendable {
    let type: String?
    let description: String?
    let link: String?
}

enum TasksServiceError: Error {
    case unauthorized
    case network(Error)
    case apiError(String)
    case decoding(Error)
}

final class TasksService: @unchecked Sendable {
    private let base = "https://tasks.googleapis.com/tasks/v1"

    init() {}

    func listTaskLists(accessToken: String) async throws -> [TaskList] {
        let urlStr = "https://tasks.googleapis.com/tasks/v1/users/@me/lists"
        guard let url = URL(string: urlStr) else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse else { throw TasksServiceError.network(NSError(domain: "", code: -1)) }
            if httpResp.statusCode == 401 { throw TasksServiceError.unauthorized }

            if let top = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let errObj = top["error"] as? [String: Any] {
                let msg = errObj["message"] as? String ?? "API error"
                throw TasksServiceError.apiError(msg)
            }

            let wrapper = try JSONDecoder().decode(TaskListsResponse.self, from: data)
            return wrapper.items ?? []
        } catch let err as TasksServiceError { throw err }
        catch let err as DecodingError { throw TasksServiceError.decoding(err) }
        catch { throw TasksServiceError.network(error) }
    }

    func listTasks(accessToken: String, tasklistId: String) async throws -> [TaskItem] {
        let urlStr = "https://tasks.googleapis.com/tasks/v1/lists/\(tasklistId)/tasks"
        guard let url = URL(string: urlStr) else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse else { throw TasksServiceError.network(NSError(domain: "", code: -1)) }
            if httpResp.statusCode == 401 { throw TasksServiceError.unauthorized }

            if let top = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let errObj = top["error"] as? [String: Any] {
                let msg = errObj["message"] as? String ?? "API error"
                throw TasksServiceError.apiError(msg)
            }

            let decoded = try JSONDecoder().decode(TasksListResponse.self, from: data)
            return decoded.items ?? []
        } catch let err as TasksServiceError { throw err }
        catch let err as DecodingError { throw TasksServiceError.decoding(err) }
        catch { throw TasksServiceError.network(error) }
    }

    func updateTaskStatus(accessToken: String, tasklistId: String, taskId: String, isCompleted: Bool) async throws -> TaskItem {
        let urlStr = "https://tasks.googleapis.com/tasks/v1/lists/\(tasklistId)/tasks/\(taskId)"
        guard let url = URL(string: urlStr) else { throw TasksServiceError.network(NSError(domain: "", code: -1)) }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "status": isCompleted ? "completed" : "needsAction"
        ]

        if isCompleted {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            payload["completed"] = formatter.string(from: Date())
        } else {
            payload["completed"] = NSNull()
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        return try await performTaskMutation(request: request)
    }

    func deleteTask(accessToken: String, tasklistId: String, taskId: String) async throws {
        let urlStr = "https://tasks.googleapis.com/tasks/v1/lists/\(tasklistId)/tasks/\(taskId)"
        guard let url = URL(string: urlStr) else { throw TasksServiceError.network(NSError(domain: "", code: -1)) }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else { throw TasksServiceError.network(NSError(domain: "", code: -1)) }
            if httpResp.statusCode == 401 { throw TasksServiceError.unauthorized }
            guard (200...299).contains(httpResp.statusCode) else {
                throw TasksServiceError.apiError("Failed to delete task (status: \(httpResp.statusCode))")
            }
        } catch let err as TasksServiceError { throw err }
        catch { throw TasksServiceError.network(error) }
    }

    func createTask(accessToken: String, tasklistId: String, title: String) async throws -> TaskItem {
        let urlStr = "https://tasks.googleapis.com/tasks/v1/lists/\(tasklistId)/tasks"
        guard let url = URL(string: urlStr) else { throw TasksServiceError.network(NSError(domain: "", code: -1)) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "title": title
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        return try await performTaskMutation(request: request)
    }

    private func performTaskMutation(request: URLRequest) async throws -> TaskItem {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else { throw TasksServiceError.network(NSError(domain: "", code: -1)) }
            if httpResp.statusCode == 401 { throw TasksServiceError.unauthorized }

            if !(200...299).contains(httpResp.statusCode) {
                if let top = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let errObj = top["error"] as? [String: Any] {
                    let msg = errObj["message"] as? String ?? "API error"
                    throw TasksServiceError.apiError(msg)
                }
                throw TasksServiceError.apiError("Unexpected status code: \(httpResp.statusCode)")
            }

            return try JSONDecoder().decode(TaskItem.self, from: data)
        } catch let err as TasksServiceError { throw err }
        catch let err as DecodingError { throw TasksServiceError.decoding(err) }
        catch { throw TasksServiceError.network(error) }
    }
}

// Wrapper for tasklists list endpoint
private struct TaskListsResponse: Codable {
    let items: [TaskList]?
}
