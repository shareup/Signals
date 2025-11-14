import Testing
@testable import Signals

@Test func signalCanBeCreatedWithInitialValue() async throws {
    let signal = Signal(initialValue: 42)
    #expect(signal.value == 42)
}

@Test func signalValueCanBeRead() async throws {
    let signal = Signal(initialValue: "hello")
    let value = signal.value
    #expect(value == "hello")
}

@Test func signalValueCanBeUpdated() async throws {
    let signal = Signal(initialValue: 10)
    signal.value = 20
    #expect(signal.value == 20)
}

@Test func signalOnlyEmitsWhenValueChanges() async throws {
    let signal = Signal(initialValue: 5)

    actor ValueCollector {
        var values: [Int] = []

        func append(_ value: Int) {
            values.append(value)
        }

        func getValues() -> [Int] {
            values
        }

        func count() -> Int {
            values.count
        }
    }

    let collector = ValueCollector()

    let task = Task {
        for await value in signal.values {
            await collector.append(value)
            if await collector.count() >= 2 {
                break
            }
        }
    }

    try await Task.sleep(for: .milliseconds(10))

    // NOTE: Change to new value - should emit
    signal.value = 10

    // NOTE: Set to same value - should NOT emit
    signal.value = 10

    // NOTE: Change to different value - should emit
    signal.value = 15

    try await Task.sleep(for: .milliseconds(50))
    task.cancel()

    let emittedValues = await collector.getValues()
    #expect(emittedValues == [10, 15])
}

@Test func signalSupportsArrayOfSignals() async throws {
    let first = Signal(initialValue: "one")
    let second = Signal(initialValue: "two")
    let arraySignal = Signal(initialValue: [first, second])

    #expect(arraySignal.value == [first, second])

    actor ArrayCollector {
        var values: [[Signal<String>]] = []

        func append(_ value: [Signal<String>]) {
            values.append(value)
        }

        func count() -> Int {
            values.count
        }

        func recorded() -> [[Signal<String>]] {
            values
        }
    }

    let collector = ArrayCollector()

    let task = Task {
        for await value in arraySignal.values {
            await collector.append(value)
            if await collector.count() >= 1 {
                break
            }
        }
    }

    try await Task.sleep(for: .milliseconds(10))

    // NOTE: Equal array (new instance) should not emit
    arraySignal.value = [first, second]

    try await Task.sleep(for: .milliseconds(10))

    let third = Signal(initialValue: "three")
    arraySignal.value = [first, third]

    try await Task.sleep(for: .milliseconds(30))
    task.cancel()

    let recorded = await collector.recorded()
    #expect(recorded.count == 1)
    #expect(recorded[0] == [first, third])
}

@Test func signalSupportsDictionaryOfSignals() async throws {
    let title = Signal(initialValue: "Title")
    let subtitle = Signal(initialValue: "Subtitle")
    let dictionarySignal = Signal(initialValue: ["title": title])

    #expect(dictionarySignal.value == ["title": title])

    actor DictionaryCollector {
        var values: [[String: Signal<String>]] = []

        func append(_ value: [String: Signal<String>]) {
            values.append(value)
        }

        func count() -> Int {
            values.count
        }

        func recorded() -> [[String: Signal<String>]] {
            values
        }
    }

    let collector = DictionaryCollector()

    let task = Task {
        for await value in dictionarySignal.values {
            await collector.append(value)
            if await collector.count() >= 1 {
                break
            }
        }
    }

    try await Task.sleep(for: .milliseconds(10))

    // NOTE: Equal dictionary should not emit
    dictionarySignal.value = ["title": title]

    try await Task.sleep(for: .milliseconds(10))

    dictionarySignal.value = [
        "title": title,
        "subtitle": subtitle,
    ]

    try await Task.sleep(for: .milliseconds(30))
    task.cancel()

    let recorded = await collector.recorded()
    #expect(recorded.count == 1)
    #expect(recorded[0] == [
        "title": title,
        "subtitle": subtitle,
    ])
}

@Test func multipleObserversCanListenToSameSignal() async throws {
    let signal = Signal(initialValue: 0)

    actor ValueCollector {
        var values: [Int] = []

        func append(_ value: Int) {
            values.append(value)
        }

        func getValues() -> [Int] {
            values
        }

        func count() -> Int {
            values.count
        }
    }

    let collector1 = ValueCollector()
    let collector2 = ValueCollector()

    let task1 = Task {
        for await value in signal.values {
            await collector1.append(value)
            if await collector1.count() >= 2 {
                break
            }
        }
    }

    let task2 = Task {
        for await value in signal.values {
            await collector2.append(value)
            if await collector2.count() >= 2 {
                break
            }
        }
    }

    try await Task.sleep(for: .milliseconds(10))

    signal.value = 1
    signal.value = 2

    try await Task.sleep(for: .milliseconds(50))
    task1.cancel()
    task2.cancel()

    let observer1Values = await collector1.getValues()
    let observer2Values = await collector2.getValues()

    #expect(observer1Values == [1, 2])
    #expect(observer2Values == [1, 2])
}

@Test func computedSignalDerivesFromOtherSignals() async throws {
    let count = Signal(initialValue: 5)
    let doubled = computed { count.value * 2 }

    #expect(doubled.value == 10)
}

@Test func computedSignalUpdatesWhenDependencyChanges() async throws {
    let count = Signal(initialValue: 5)
    let doubled = computed { count.value * 2 }

    #expect(doubled.value == 10)

    count.value = 10
    #expect(doubled.value == 20)

    count.value = 15
    #expect(doubled.value == 30)
}

@Test func computedSignalWithTwoDependencies() async throws {
    let firstName = Signal(initialValue: "John")
    let lastName = Signal(initialValue: "Doe")
    let fullName = computed { "\(firstName.value) \(lastName.value)" }

    #expect(fullName.value == "John Doe")

    firstName.value = "Jane"
    #expect(fullName.value == "Jane Doe")

    lastName.value = "Smith"
    #expect(fullName.value == "Jane Smith")
}

@Test func computedSignalEmitsValuesWhenDependenciesChange() async throws {
    let count = Signal(initialValue: 1)
    let doubled = computed { count.value * 2 }

    actor ValueCollector {
        var values: [Int] = []

        func append(_ value: Int) {
            values.append(value)
        }

        func getValues() -> [Int] {
            values
        }

        func count() -> Int {
            values.count
        }
    }

    let collector = ValueCollector()

    let task = Task {
        for await value in doubled.values {
            await collector.append(value)
            if await collector.count() >= 3 {
                break
            }
        }
    }

    try await Task.sleep(for: .milliseconds(60))

    count.value = 2  // NOTE: doubled becomes 4
    try await Task.sleep(for: .milliseconds(60))

    count.value = 3  // NOTE: doubled becomes 6
    try await Task.sleep(for: .milliseconds(60))

    count.value = 4  // NOTE: doubled becomes 8
    try await Task.sleep(for: .milliseconds(60))
    task.cancel()

    let emittedValues = await collector.getValues()
    #expect(emittedValues == [4, 6, 8])
}

@Test func effectWithAutomaticTracking() async throws {
    let count = Signal(initialValue: 0)

    actor EffectTracker {
        var runCount = 0
        var lastValue = 0

        func recordRun(_ value: Int) {
            runCount += 1
            lastValue = value
        }

        func getCount() -> Int {
            runCount
        }

        func getLastValue() -> Int {
            lastValue
        }
    }

    let tracker = EffectTracker()

    let effectTask = effect {
        let value = count.value
        Task {
            await tracker.recordRun(value)
        }
    }

    try await Task.sleep(for: .milliseconds(60))

    count.value = 1
    try await Task.sleep(for: .milliseconds(60))

    count.value = 2
    try await Task.sleep(for: .milliseconds(60))

    // NOTE: Wait a bit more to ensure the Task inside the effect completes
    try await Task.sleep(for: .milliseconds(80))

    effectTask.cancel()

    let runCount = await tracker.getCount()
    let lastValue = await tracker.getLastValue()

    // NOTE: Should run 3 times: initial + 2 changes
    #expect(runCount == 3)
    #expect(lastValue == 2)
}

@Test func effectTracksMultipleSignals() async throws {
    let firstName = Signal(initialValue: "John")
    let lastName = Signal(initialValue: "Doe")

    actor EffectTracker {
        var fullNames: [String] = []

        func add(_ name: String) {
            fullNames.append(name)
        }

        func getNames() -> [String] {
            fullNames
        }
    }

    let tracker = EffectTracker()

    let effectTask = effect {
        let full = "\(firstName.value) \(lastName.value)"
        Task {
            await tracker.add(full)
        }
    }

    try await Task.sleep(for: .milliseconds(20))

    firstName.value = "Jane"
    try await Task.sleep(for: .milliseconds(20))

    lastName.value = "Smith"
    try await Task.sleep(for: .milliseconds(20))

    effectTask.cancel()

    let names = await tracker.getNames()
    // NOTE: Should have: initial, after firstName change, after lastName change
    #expect(names.count == 3)
    #expect(names[0] == "John Doe")
    #expect(names[1] == "Jane Doe")
    #expect(names[2] == "Jane Smith")
}

@Test func effectCanBeCancelled() async throws {
    let count = Signal(initialValue: 0)

    actor EffectTracker {
        var runCount = 0

        func increment() {
            runCount += 1
        }

        func getCount() -> Int {
            runCount
        }
    }

    let tracker = EffectTracker()

    let effectTask = effect {
        Task {
            await tracker.increment()
        }
        _ = count.value  // NOTE: Track the signal
    }

    try await Task.sleep(for: .milliseconds(20))

    count.value = 1
    try await Task.sleep(for: .milliseconds(20))

    effectTask.cancel()

    // NOTE: Wait for cancellation to take effect
    try await Task.sleep(for: .milliseconds(20))

    let countBeforeChange = await tracker.getCount()

    // NOTE: Change value after cancellation - should not trigger effect
    count.value = 2
    count.value = 3
    count.value = 4
    try await Task.sleep(for: .milliseconds(50))

    let countAfterChange = await tracker.getCount()

    // NOTE: Count should not increase after cancellation
    #expect(countAfterChange == countBeforeChange)
}

@Test func signalThreadSafeConcurrentReads() async throws {
    let signal = Signal(initialValue: 42)

    await withTaskGroup(of: Int.self) { group in
        for _ in 0..<100 {
            group.addTask {
                signal.value
            }
        }

        for await value in group {
            #expect(value == 42)
        }
    }
}

@Test func signalThreadSafeConcurrentWrites() async throws {
    let signal = Signal(initialValue: 0)

    await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask {
                signal.value = i
            }
        }
    }

    #expect(signal.value >= 0 && signal.value < 100)
}

@Test func signalThreadSafeMixedReadWrite() async throws {
    let signal = Signal(initialValue: 0)

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<50 {
            group.addTask {
                _ = signal.value  // Read
            }
        }

        for i in 0..<50 {
            group.addTask {
                signal.value = i  // Write
            }
        }
    }

    // NOTE: Should complete without crashes
    #expect(true)
}

@Test func computedSignalThreadSafeConcurrentAccess() async throws {
    let count = Signal(initialValue: 0)
    let doubled = computed { count.value * 2 }

    await withTaskGroup(of: Int.self) { group in
        for i in 0..<50 {
            group.addTask {
                count.value = i
                return doubled.value
            }
        }

        for await value in group {
            #expect(value >= 0 && value < 100)
        }
    }
}

@Test func multipleSignalsConcurrentUpdates() async throws {
    let signal1 = Signal(initialValue: 0)
    let signal2 = Signal(initialValue: 0)
    let signal3 = Signal(initialValue: 0)

    await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask { signal1.value = i }
            group.addTask { signal2.value = i }
            group.addTask { signal3.value = i }
        }
    }

    #expect(signal1.value >= 0 && signal1.value < 100)
    #expect(signal2.value >= 0 && signal2.value < 100)
    #expect(signal3.value >= 0 && signal3.value < 100)
}
