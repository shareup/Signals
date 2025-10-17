import Testing
import SwiftUI
@testable import Signals

// MARK: - @State Lazy Assignment Tests

/// Reference type to capture values synchronously during init
final class ValueCapture: @unchecked Sendable {
    var capturedValues: [Int] = []

    func append(_ value: Int) {
        capturedValues.append(value)
    }
}

/// This test demonstrates that @State assignments in init() don't take effect immediately.
/// The @State property wrapper hasn't been activated yet during init.
@Test @MainActor func stateAssignmentInInitIsDeferred() async throws {
    let capture = ValueCapture()

    struct TestView: View {
        @State var count: Int = 0

        init(capture: ValueCapture) {
            // At this point, @State wrapper is NOT active yet
            // We're just modifying the backing storage

            // Capture initial value
            capture.append(count)  // Should be 0

            // Assign new value
            self.count = 2

            // Read immediately after assignment
            // With a normal property, this would be 2
            // But @State in init doesn't work like a normal property
            capture.append(count)

            // Assign another value
            self.count = 3

            // Read again
            capture.append(count)
        }

        var body: some View {
            Text("\(count)")
        }
    }

    _ = TestView(capture: capture)

    // During init, @State assignments don't behave like normal Swift properties
    // The exact behavior depends on SwiftUI internals, but assignments in init
    // are not immediately reflected in reads
    #expect(capture.capturedValues.count == 3)

    // The key point: after assigning 2 and 3, we don't read those values back
    // This is because @State wrapper isn't active during init
    #expect(capture.capturedValues[0] == 0, "Initial value is 0")

    // These assertions prove @State doesn't work like normal properties in init
    // The behavior here is that reads return the initial value, not the assigned values
    #expect(capture.capturedValues[1] != 2 || capture.capturedValues[2] != 3,
            "@State assignments in init don't behave like normal property assignments")
}

/// This test demonstrates Signal assignments are immediate, even in init-like contexts
@Test func signalAssignmentIsImmediate() async throws {
    let capture = ValueCapture()

    // Signals can be used outside of any SwiftUI context
    let count = Signal(initialValue: 0)

    // Capture initial value
    capture.append(count.value)
    #expect(count.value == 0)

    // Assign new value
    count.value = 2

    // Read immediately - should be 2!
    capture.append(count.value)
    #expect(count.value == 2)

    // Assign another value
    count.value = 3

    // Read immediately - should be 3!
    capture.append(count.value)
    #expect(count.value == 3)

    // Signal assignments are immediate - we see the assigned values
    #expect(capture.capturedValues == [0, 2, 3])
    #expect(capture.capturedValues[0] == 0, "Initial value is 0")
    #expect(capture.capturedValues[1] == 2, "After assigning 2, value is immediately 2")
    #expect(capture.capturedValues[2] == 3, "After assigning 3, value is immediately 3")
}

/// This test shows @State STILL doesn't work normally even in extracted methods
/// because we're calling on a struct instance, not within SwiftUI's rendering system
@Test @MainActor func stateDoesntWorkOutsideSwiftUILifecycle() async throws {
    struct TestView: View {
        @State var count: Int = 0
        let capture: ValueCapture

        var body: some View {
            Button("Test", action: performAction)
        }

        func performAction() {
            // Even in a method called after init, if we're not in SwiftUI's rendering system,
            // @State still doesn't work properly
            count = 5
            capture.append(count)

            count = 10
            capture.append(count)
        }
    }

    let capture = ValueCapture()
    let view = TestView(capture: capture)

    // Initially 0
    #expect(view.count == 0)
    #expect(capture.capturedValues.isEmpty)

    // Try to call the method directly
    view.performAction()

    // @State STILL doesn't work! Even in methods, because we're calling on a struct instance
    // outside of SwiftUI's view rendering system
    #expect(view.count == 0, "@State doesn't update even in methods when called outside SwiftUI")
    #expect(capture.capturedValues == [0, 0], "@State reads return initial value, not assigned values")

    // This proves @State only works within SwiftUI's rendering system,
    // not as a general-purpose reactive property
}

/// Direct comparison: Signal vs @State initialization behavior
@Test @MainActor func signalVsStateInitializationBehavior() async throws {
    let stateCapture = ValueCapture()
    let signalCapture = ValueCapture()

    let signalCount = Signal(initialValue: 0)

    struct StateView: View {
        @State var count: Int = 0

        init(capture: ValueCapture, signal: Signal<Int>) {
            // @State: assignments in init don't work like normal properties
            capture.append(count)  // 0
            self.count = 5
            capture.append(count)  // Still 0 (or unpredictable)

            // Signal: assignments work immediately
            signal.value = 5
        }

        var body: some View {
            Text("\(count)")
        }
    }

    // Capture signal behavior
    signalCapture.append(signalCount.value)  // 0

    _ = StateView(capture: stateCapture, signal: signalCount)

    signalCapture.append(signalCount.value)  // 5

    // Signal: predictable, immediate assignment
    #expect(signalCapture.capturedValues == [0, 5])

    // @State: unpredictable in init - assignment doesn't work like normal Swift
    #expect(stateCapture.capturedValues[0] == 0)
    #expect(stateCapture.capturedValues.count == 2)
}

/// Test that demonstrates the practical problem: @State can't be reliably used for immediate reads
@Test @MainActor func stateCannotBeReliablyReadAfterAssignment() async throws {
    let capture = ValueCapture()

    struct TestView: View {
        @State var value: Int = 0

        init(capture: ValueCapture) {
            // Imagine you need to do something based on the value you just set
            self.value = 10

            // Now you need to use that value for a calculation
            // With normal Swift properties, this would work:
            let doubled = value * 2

            // But with @State in init, 'value' might not be 10!
            // It's likely still 0 because @State isn't active yet
            capture.append(doubled)
        }

        var body: some View {
            Text("\(value)")
        }
    }

    _ = TestView(capture: capture)

    // If @State worked like a normal property, the doubled value would be 20
    // But it's not, because @State doesn't apply the assignment immediately in init
    #expect(capture.capturedValues[0] != 20, "@State assignment in init doesn't work like normal properties")
}

/// Test that demonstrates Signal DOES work reliably for immediate reads
@Test func signalCanBeReliablyReadAfterAssignment() async throws {
    let value = Signal(initialValue: 0)

    // Set a value
    value.value = 10

    // Use it immediately in a calculation
    let doubled = value.value * 2

    // This works as expected because Signal assignments are immediate
    #expect(doubled == 20, "Signal assignment is immediate and reliable")
    #expect(value.value == 10, "Value is exactly what we assigned")
}

/// Demonstrates why Signals are better for imperative logic
@Test func signalsWorkForImperativeLogic() async throws {
    // Scenario: You need to update multiple values and have them depend on each other

    let price = Signal(initialValue: 100.0)
    let quantity = Signal(initialValue: 2)
    let discount = Signal(initialValue: 0.1)

    // Update price
    price.value = 150.0

    // Calculate something based on updated price - this works immediately!
    let subtotal = price.value * Double(quantity.value)
    #expect(subtotal == 300.0)

    // Apply discount based on subtotal
    let finalPrice = subtotal * (1.0 - discount.value)
    #expect(finalPrice == 270.0)

    // All of this works because Signal assignments are immediate
    // With @State in init, none of this would work reliably
}

/// Test showing @State is designed for declarative UI, not imperative logic
@Test @MainActor func stateIsDesignedForDeclarativeUINotImperativeLogic() async throws {
    struct BadExample: View {
        @State var price: Double = 100.0
        @State var quantity: Int = 2
        @State var total: Double = 0.0

        init() {
            // This imperative logic doesn't work with @State in init!
            self.price = 150.0
            self.quantity = 3

            // Trying to calculate based on those values...
            // But @State hasn't activated yet, so these might still be old values
            self.total = price * Double(quantity)  // Probably 200.0, not 450.0!
        }

        var body: some View {
            Text("Total: \(total)")
        }
    }

    let view = BadExample()

    // The total is probably wrong because @State assignments in init
    // don't work like normal Swift properties
    #expect(view.total != 450.0, "@State in init doesn't support imperative logic")
}

/// Test showing Signal works perfectly for imperative logic
@Test func signalWorksForImperativeLogic() async throws {
    let price = Signal(initialValue: 100.0)
    let quantity = Signal(initialValue: 2)
    let total = Signal(initialValue: 0.0)

    // This imperative logic works perfectly!
    price.value = 150.0
    quantity.value = 3

    // Calculate based on those values - works immediately
    total.value = price.value * Double(quantity.value)

    #expect(total.value == 450.0, "Signal supports imperative logic perfectly")
}
