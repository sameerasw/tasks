import SwiftUI

struct TaskDetailDisplayView: View {
    let taskItem: TaskItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            
            VStack(spacing: 16) {

                if let completed = taskItem.completed, let date = completed.toDate() {
                    detailSection(title: "Completed", content: date.formatted(date: .long, time: .shortened), icon: "checkmark.circle.fill", color: .green)
                } else {
                    statusSection
                }

                if let due = taskItem.due, let date = due.toDate() {
                    detailSection(title: "Due Date", content: date.formatted(date: .long, time: .omitted), icon: "calendar")
                }

                if let notes = taskItem.notes, !notes.isEmpty {
                    detailSection(title: "Notes", content: notes, icon: "note.text")
                }

                if let updated = taskItem.updated, let date = updated.toDate() {
                    detailSection(title: "Last Updated", content: date.formatted(date: .long, time: .shortened), icon: "arrow.clockwise.circle")
                }

                flagsSection
                linksSection
                assignmentSection
                webLinkSection
            }
        }
    }

    private var flagsSection: some View {
        Group {
            if taskItem.deleted == true || taskItem.hidden == true {
                HStack(spacing: 12) {
                    if taskItem.deleted == true {
                        Label("Deleted", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                    if taskItem.hidden == true {
                        Label("Hidden", systemImage: "eye.slash.fill")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .font(.subheadline)
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }

    private var linksSection: some View {
        Group {
            if let links = taskItem.links, !links.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.secondary)
                        Text("Related Links")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                    
                    ForEach(links.indices, id: \.self) { index in
                        let item = links[index]
                        if let urlStr = item.link, let url = URL(string: urlStr) {
                            Link(destination: url) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.description ?? "Link")
                                            .font(.body)
                                        Text(item.type ?? "URL")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                }
                                .padding(10)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }

    private var assignmentSection: some View {
        Group {
            if let info = taskItem.assignmentInfo {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.badge.key")
                            .foregroundColor(.secondary)
                        Text("Assignment Info")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }

                    if let type = info.surfaceType {
                        Text("From: \(type)")
                            .font(.headline)
                    }

                    if let link = info.linkToTask, let url = URL(string: link) {
                        Link(destination: url) {
                            Label("Open Source Document", systemImage: "doc.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private var webLinkSection: some View {
        Group {
            if let webLink = taskItem.webViewLink, let url = URL(string: webLink) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Open in Google Tasks Web")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(taskItem.title ?? "(No Title)")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
        }
    }

    private var statusSection: some View {
        HStack {
            Label(taskItem.status == "completed" ? "Completed" : "In Progress", 
                  systemImage: taskItem.status == "completed" ? "checkmark.circle.fill" : "circle")
                .foregroundColor(taskItem.status == "completed" ? .green : .orange)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private func detailSection(title: String, content: String, icon: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}
