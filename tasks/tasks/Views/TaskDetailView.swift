import SwiftUI

struct TaskDetailView: View {
    @State private var taskItem: TaskItem
    let listId: String
    let viewModel: TaskListViewModel
    let auth: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isEditing = false
    
    // Draft states for editing
    @State private var draftTitle = ""
    @State private var draftNotes = ""
    @State private var draftDue: Date? = nil
    @State private var draftStatus = ""
    @State private var isSaving = false

    init(task: TaskItem, listId: String, viewModel: TaskListViewModel, auth: AuthenticationManager) {
        _taskItem = State(initialValue: task)
        self.listId = listId
        self.viewModel = viewModel
        self.auth = auth
    }

    var body: some View {
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading details...")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await fetchDetails() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if isEditing {
                                editForm
                            } else {
                                displayContent
                            }
                        }
                        .padding(24)
                    }
                    .padding(0)
                    .disabled(isSaving)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "Task Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Save") {
                            Task { await saveChanges() }
                        }
                        .disabled(isSaving || draftTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.glassProminent)
                    } else {
                        Button("Done") { dismiss() }
                            .buttonStyle(.glassProminent)
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Cancel") {
                            cancelEditing()
                        }
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
            }
            .onAppear {
                Task { await fetchDetails() }
            }
        .frame(minWidth: 450, minHeight: 600)
    }

    private var displayContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            
            VStack(spacing: 16) {
                if let updated = taskItem.updated, let date = ISO8601DateFormatter().date(from: updated) {
                    detailSection(title: "Last Updated", content: date.formatted(date: .long, time: .shortened), icon: "arrow.clockwise.circle")
                }

                if let notes = taskItem.notes, !notes.isEmpty {
                    detailSection(title: "Notes", content: notes, icon: "note.text")
                }
                
                if let due = taskItem.due, let date = ISO8601DateFormatter().date(from: due) {
                    detailSection(title: "Due Date", content: date.formatted(date: .long, time: .omitted), icon: "calendar")
                }
                
                if let completed = taskItem.completed, let date = ISO8601DateFormatter().date(from: completed) {
                    detailSection(title: "Completed", content: date.formatted(date: .long, time: .shortened), icon: "checkmark.circle.fill", color: .green)
                }
                
                statusSection
                flagsSection
                linksSection
                assignmentSection
                webLinkSection
            }
        }
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Title").font(.caption).foregroundColor(.secondary)
                TextField("Task Title", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $draftNotes)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Due Date").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if draftDue != nil {
                        Button("Clear") { draftDue = nil }
                            .font(.caption)
                    }
                }
                
                DatePicker("Pick a date", selection: Binding(get: { draftDue ?? Date() }, set: { draftDue = $0 }), displayedComponents: .date)
                    .labelsHidden()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(get: { draftStatus == "completed" }, set: { draftStatus = $0 ? "completed" : "needsAction" })) {
                    Text("Mark as Completed")
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private func startEditing() {
        draftTitle = taskItem.title ?? ""
        draftNotes = taskItem.notes ?? ""
        if let due = taskItem.due {
            draftDue = ISO8601DateFormatter().date(from: due)
        } else {
            draftDue = nil
        }
        draftStatus = taskItem.status ?? "needsAction"
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
    }

    private func saveChanges() async {
        isSaving = true
        errorMessage = nil
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dueStr = draftDue.map { formatter.string(from: $0) }
        
        let updatedTask = TaskItem(
            id: taskItem.id,
            title: draftTitle,
            notes: draftNotes,
            status: draftStatus,
            due: dueStr,
            completed: taskItem.completed, // usually set by API
            updated: nil, // set by API
            deleted: taskItem.deleted,
            hidden: taskItem.hidden,
            links: taskItem.links,
            webViewLink: taskItem.webViewLink,
            parent: taskItem.parent,
            position: taskItem.position,
            selfLink: taskItem.selfLink,
            etag: taskItem.etag,
            assignmentInfo: taskItem.assignmentInfo
        )
        
        do {
            let result = try await viewModel.updateTask(updatedTask, listId: listId, auth: auth)
            await MainActor.run {
                self.taskItem = result
                self.isEditing = false
                self.isSaving = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save changes: \(error.localizedDescription)"
                self.isSaving = false
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
        VStack(alignment: .leading, spacing: 8) {
            Text(taskItem.title ?? "(No Title)")
                .font(.title)
                .fontWeight(.bold)
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

    private func fetchDetails() async {
        isLoading = true
        errorMessage = nil
        do {
            let updatedTask = try await viewModel.fetchTaskDetails(listId: listId, taskId: taskItem.id, auth: auth)
            await MainActor.run {
                self.taskItem = updatedTask
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch full details: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
