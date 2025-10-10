import Foundation

struct TaskList: Codable, Identifiable {
    let id: String
    let title: String?
    let kind: String?
    let etag: String?
    let updated: String?
    let selfLink: String?
}

struct TasksListResponse: Codable {
    let items: [TaskItem]?
}

struct TaskItem: Codable, Identifiable {
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

struct TaskLink: Codable {
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

final class TasksService {
    private let base = "https://tasks.googleapis.com/tasks/v1"

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
}

// Wrapper for tasklists list endpoint
private struct TaskListsResponse: Codable {
    let items: [TaskList]?
}
