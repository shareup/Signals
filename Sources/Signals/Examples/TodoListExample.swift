import SwiftUI

/// NOTE: Demonstrates stable identity + per-item signals

/// NOTE: Each todo item is a plain reference type with its own signals for granular reactivity.
/// NOTE: The UUID provides stable identity for efficient SwiftUI list updates and automatic caching.
final class TodoItem: Sendable, Identifiable {
    let id: UUID
    let text: Signal<String>
    let completed: Signal<Bool>

    init(id: UUID = UUID(), text: String, completed: Bool = false) {
        self.id = id
        self.text = Signal(initialValue: text)
        self.completed = Signal(initialValue: completed)
    }

    func toggle() {
        completed.value.toggle()
    }
}

// NOTE: TodoItems are equal if they have the same ID (stable identity)
extension TodoItem: Equatable {
    static func == (lhs: TodoItem, rhs: TodoItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// NOTE: The store holds a Signal<[TodoItem]> where each item has stable identity.
/// NOTE: Computed signals aggregate across the array efficiently.
final class TodoStore: Sendable {
    let items: Signal<[TodoItem]>
    let totalCount: ComputedSignal<Int>
    let completedCount: ComputedSignal<Int>
    let activeCount: ComputedSignal<Int>
    let allCompleted: ComputedSignal<Bool>

    init() {
        let items = Signal<[TodoItem]>(initialValue: [
            TodoItem(text: "Build signals library", completed: true),
            TodoItem(text: "Add automatic dependency tracking", completed: true),
            TodoItem(text: "Write comprehensive tests", completed: true),
            TodoItem(text: "Create TodoList demo", completed: false),
            TodoItem(text: "Ship to production", completed: false),
        ])

        self.items = items

        self.totalCount = computed {
            items.value.count
        }

        self.completedCount = computed {
            items.value.filter { $0.completed.value }.count
        }

        self.activeCount = computed {
            items.value.filter { !$0.completed.value }.count
        }

        self.allCompleted = computed {
            !items.value.isEmpty && items.value.allSatisfy { $0.completed.value }
        }
    }

    func addItem(text: String) {
        let newItem = TodoItem(text: text)
        items.value.append(newItem)
    }

    func removeItems(at offsets: IndexSet) {
        items.value.remove(atOffsets: offsets)
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        items.value.move(fromOffsets: source, toOffset: destination)
    }

    func toggleAll() {
        let shouldComplete = !allCompleted.value
        for item in items.value {
            item.completed.value = shouldComplete
        }
    }

    func clearCompleted() {
        items.value.removeAll { $0.completed.value }
    }
}

/// NOTE: This view only re-renders when its specific item's signals change.
/// NOTE: Toggling one item doesn't cause other rows to re-render!
struct TodoRowView: View {
    let item: TodoItem

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { item.toggle() }) {
                Image(systemName: item.completed.value ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.completed.value ? .green : .gray)
            }
            .buttonStyle(.plain)

            TextField("Todo", text: Binding(
                get: { item.text.value },
                set: { item.text.value = $0 }
            ))
            .textFieldStyle(.plain)
            .strikethrough(item.completed.value)
            .foregroundStyle(item.completed.value ? .secondary : .primary)
        }
        .padding(.vertical, 4)
    }
}

struct TodoStatsView: View {
    let store: TodoStore

    var body: some View {
        HStack(spacing: 20) {
            StatLabel(title: "Total", value: store.totalCount.value, color: .blue)
            StatLabel(title: "Active", value: store.activeCount.value, color: .orange)
            StatLabel(title: "Done", value: store.completedCount.value, color: .green)
        }
        .padding()
        .background(.quaternary)
        .cornerRadius(12)
    }
}

struct StatLabel: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }
}

struct TodoListView: View {
    let store: TodoStore
    @State private var newTodoText = ""
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("Smart Todo List")
                    .font(.largeTitle.bold())

                TodoStatsView(store: store)

                HStack {
                    TextField("Add a new todo...", text: $newTodoText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isAddFieldFocused)
                        .onSubmit(addTodo)

                    Button(action: addTodo) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()

            Divider()

            // NOTE: ForEach uses item.id for stable identity - views are reused efficiently
            List {
                ForEach(store.items.value) { item in
                    TodoRowView(item: item)
                }
                .onDelete { offsets in
                    store.removeItems(at: offsets)
                }
                .onMove { source, destination in
                    store.moveItems(from: source, to: destination)
                }
            }
            .listStyle(.plain)

            if !store.items.value.isEmpty {
                Divider()

                HStack {
                    Button("Toggle All") {
                        store.toggleAll()
                    }

                    Spacer()

                    Button("Clear Completed") {
                        store.clearCompleted()
                    }
                    .disabled(store.completedCount.value == 0)
                }
                .padding()
                .background(.quaternary)
            }
        }
        .toolbar {
            #if os(iOS)
            EditButton()
            #endif
        }
    }

    private func addTodo() {
        let text = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        store.addItem(text: text)
        newTodoText = ""
        isAddFieldFocused = true
    }
}

struct TodoListDemo: View {
    let todoStore = TodoStore()

    var body: some View {
        NavigationStack {
            TodoListView(store: todoStore)
        }
    }
}

#Preview("Smart Todo List") {
    TodoListDemo()
}
