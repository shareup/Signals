import SwiftUI

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
    let store: EnvCounterStore

    var body: some View {
        GroupBox("Display") {
            Text("\(store.count.value)")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.blue)
        }
    }
}

struct CounterControlsView: View {
    let store: EnvCounterStore

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
    let store: EnvCounterStore

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
                CounterDisplayView(store: counterStore)
                CounterControlsView(store: counterStore)
                CounterStatsView(store: counterStore)
            }
            .padding()
            .navigationTitle("Environment Demo")
        }
    }
}

/**
 # Testing

 The environment pattern makes testing easy:

 ```swift
let prodStore = ProdCounterStore()
MyView(store: prodStore)

let mockStore = MockCounterStore()
MyView(store: mockStore)
```
*/

 /**
 # Typical App Structure

 ```swift
 @main
 struct MyApp: App {
     let appStore = AppStore()
     let themeStore = ThemeStore()
     let dataStore = DataStore()

     var body: some Scene {
         WindowGroup {
             ContentView(
                 appStore: appStore,
                 themeStore: themeStore,
                 dataStore: dataStore
             )
         }
     }
 }

 struct ContentView: View {
     let appStore: AppStore
     let themeStore: ThemeStore
     let dataStore: DataStore

     var body: some View {
         TabView {
             HomeView()
             ProfileView()
             SettingsView()
         }
     }
 }

 struct HomeView: View {
     let appStore: AppStore

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
