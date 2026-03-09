import SwiftUI

struct TaskCard: View {
    let taskItem: TaskItem
    var onToggleCompletion: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Group {
                    if taskItem.status == "completed" {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.trailing, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggleCompletion?()
                }

                Text(taskItem.title ?? "(no title)")
                    .font(.headline)
            }

            if let notes = taskItem.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack {
                if let due = taskItem.due, let date = due.toDate() {
                    Label {
                        Text(date, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .padding(4)
                    .glassEffect()
//                    .clipShape(Capsule())
                }
                Spacer()
            }
        }
        .padding()
        .background(.clear)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
