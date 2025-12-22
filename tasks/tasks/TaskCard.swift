import SwiftUI

struct TaskCard: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title ?? "(no title)")
                    .font(.headline)
                Spacer()
                if task.status == "completed" {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack {
                if let due = task.due, let date = due.toDate() {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(.clear)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
