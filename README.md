# Swift Signals

An Observable signals library for Swift and SwiftUI, inspired by Preact Signals.

## Features

- ✅ **Automatic Dependency Tracking** - No manual subscriptions needed
- ✅ **Fine-Grained Reactivity** - Only re-render views that access the signal
- ✅ **Thread-Safe** - Built with concurrency in mind
- ✅ **Type-Safe** - Full Swift type checking
- ✅ **SwiftUI Native** - Seamless integration with SwiftUI views
- ✅ **Works entirely outside SwiftUI** - Does not depend on SwiftUI lifecycle to work
- ✅ **AsyncSequence of values** - Can subscribe to changes anywhere
- ✅ **Computed Signals** - Derive values from other signals automatically
- ✅ **Effects** - Run side effects when signals change

**Benefits:**

- ✅ **No `@State` needed** - Views are pure presentation, values update immediately
- ✅ **Easier testing** - Test stores independently
- ✅ **Better separation** - State separate from UI
- ✅ **Shared naturally** - Multiple views can access the same signals

## The big problem with `@State`

When assigning a new value to an `@State` wrapped property, the value isn't always applied immediately which can be extremely surprising.

```swift
struct CounterView: View {
    @State var count: Int = 0

    init() {
        // Since the count value was initially set to 0, any assignments here in init are scheduled and not applied instantly like a normal variable

        self.count = 2
        print("count: \(count)") // Outputs "count: 0", the value has not been applied yet

        self.count = 3
        print("count: \(count)") // Outputs "count: 0", the value still has not been applied yet

        // @State breaks the normal contract a developer has with property assignment
    }

    var body: some View {
        // ...
    }
}
```

**It doesn't have to be this way.**

`Signal` can do both:

1. Apply the new value right now
2. Schedule a re-render

Assigning variables can continue to make sense and be predictable everywhere without losing any reactive benefits.

## Requirements

- iOS 17+ / macOS 14+ / watchOS 10+ / tvOS 17+
- Swift 6.2+

## Quick Start

### Basic Signal

```swift
import signals

let count = Signal(initialValue: 0)
print(count.value)  // 0

count.value = 5
print(count.value)  // 5
```

### Computed Signal (Automatic Dependency Tracking!)

```swift
let firstName = Signal(initialValue: "John")
let lastName = Signal(initialValue: "Doe")

// Automatically tracks both signals!
let fullName = computed {
    "\(firstName.value) \(lastName.value)"
}

print(fullName.value)  // "John Doe"

firstName.value = "Jane"

print(fullName.value)  // "Jane Doe" ← Automatically updated!
```

### Effects

```swift
let temperature = Signal(initialValue: 20)

let task = effect {
    print("Temperature is now: \(temperature.value)°C")
}
// Prints: "Temperature is now: 20°C"

temperature.value = 25
// Prints: "Temperature is now: 25°C"

// Later, stop the effect
task.cancel()
```

### SwiftUI Integration (Initializer Injection)

```swift
import SwiftUI
import signals

final class CounterStore: Sendable {
    let count: Signal<Int>

    init(initialValue: Int = 0) {
        self.count = Signal(initialValue: initialValue)
    }

    func increment() { count.value += 1 }
}

@main
struct MyApp: App {
    let counterStore = CounterStore()

    var body: some Scene {
        WindowGroup {
            CounterView(store: counterStore)
        }
    }
}

struct CounterView: View {
    let store: CounterStore

    var body: some View {
        VStack(spacing: 16) {
            Text("Count: \(store.count.value)")
            Button("Increment") { store.increment() }
        }
        .padding()
    }
}
```

## Examples with Previews

* [BasicExample.swift](./Sources/Signals/Examples/BasicExample.swift)
* [EnvironmentExample.swift](./Sources/Signals/Examples/EnvironmentExample.swift)
* [TodoListExample.swift](./Sources/Signals/Examples/TodoListExample.swift)
