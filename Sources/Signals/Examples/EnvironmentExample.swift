import SwiftUI

@Observable
final class EnvCounterStore: Sendable {
    let count: Signal<Int>
    let doubled: ComputedSignal<Int>

    init(initialValue: Int = 0) {
        let count = Signal(initialValue: initialValue)
        let doubled = computed { count.value * 2 }

        self.count = count
        self.doubled = doubled
    }

    func increment() { count.value += 1 }
    func decrement() { count.value -= 1 }
    func reset() { count.value = 0 }
}

struct CounterDisplayView: View {
    @Environment(EnvCounterStore.self) var store

    var body: some View {
        GroupBox("Display") {
            Text("\(store.count.value)")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.blue)
        }
    }
}

struct CounterControlsView: View {
    @Environment(EnvCounterStore.self) var store

    var body: some View {
        GroupBox("Controls") {
            HStack(spacing: 15) {
                Button("−") { store.decrement() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                Button("Reset") { store.reset() }
                    .buttonStyle(.bordered)

                Button("+") { store.increment() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            }
            .font(.title)
        }
    }
}

struct CounterStatsView: View {
    @Environment(EnvCounterStore.self) var store

    var body: some View {
        GroupBox("Stats") {
            VStack(spacing: 10) {
                HStack {
                    Text("Count:")
                    Spacer()
                    Text("\(store.count.value)")
                        .foregroundColor(.blue)
                }

                HStack {
                    Text("Doubled:")
                    Spacer()
                    Text("\(store.doubled.value)")
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

struct EnvironmentDemo: View {
    let counterStore: EnvCounterStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                CounterDisplayView()
                CounterControlsView()
                CounterStatsView()
            }
            .padding()
            .navigationTitle("Environment Demo")
        }
        .environment(counterStore)
    }
}

/**
 # Testing

 The environment pattern makes testing easy:

 ```swift
 // Production
 MyView()
   .environment(ProdStore())

 // Testing
 MyView()
   .environment(MockStore())
 ```
 */

/**
 # Typical App Structure

 ```swift
 @main
 struct MyApp: App {
     // Create stores at app level
     let appStore = AppStore()
     let themeStore = ThemeStore()
     let dataStore = DataStore()

     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environment(appStore)
                 .environment(themeStore)
                 .environment(dataStore)
         }
     }
 }

 struct ContentView: View {
     // Any child view can access via @Environment
     @Environment(AppStore.self) var appStore
     @Environment(ThemeStore.self) var themeStore

     var body: some View {
         TabView {
             HomeView()
             ProfileView()
             SettingsView()
         }
     }
 }

 struct HomeView: View {
     // Only request what you need
     @Environment(AppStore.self) var appStore

     var body: some View {
         Text("Welcome, \(appStore.displayName.value)")
     }
 }
 ```
 */

// MARK: - Previews

#Preview("Counter") {
    EnvironmentDemo(counterStore: EnvCounterStore())
}

#Preview("Custom Store") {
    let customStore = EnvCounterStore(initialValue: 100)
    EnvironmentDemo(counterStore: customStore)
}
