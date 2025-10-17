#if canImport(SwiftUI)
import SwiftUI
import Testing
@testable import Signals

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit) || canImport(AppKit)

@MainActor
@Test("Injected stores keep SwiftUI views reactive")
func injectedStoreKeepsSwiftUIViewReactive() async throws {
    let store = DemoInjectionStore()
    let recorder = RenderRecorder()

    let rootView = DemoInjectionProbeView(store: store, recorder: recorder)

    let hostingController: AnyObject
    #if canImport(UIKit)
    let controller = UIHostingController(rootView: rootView)
    _ = controller.view
    hostingController = controller
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    #elseif canImport(AppKit)
    let controller = NSHostingController(rootView: rootView)
    _ = controller.view
    hostingController = controller
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentViewController = controller
    window.makeKeyAndOrderFront(nil)
    defer { window.close() }
    #endif

    try await waitForSnapshots(in: recorder, minimumCount: 1)
    #expect(recorder.snapshots.first?.title == "Idle")
    #expect(recorder.snapshots.first?.count == 0)

    store.title.value = "Processing"
    store.count.value = 42

    try await waitForSnapshots(in: recorder, minimumCount: 2)
    guard let last = recorder.snapshots.last else {
        Issue.record("Missing render snapshots after updating signals")
        return
    }

    #expect(last.title == "Processing")
    #expect(last.count == 42)

    withExtendedLifetime(hostingController) {}
}

#endif

// MARK: - Test helpers

private final class DemoInjectionStore: @unchecked Sendable {
    let title = Signal(initialValue: "Idle")
    let count = Signal(initialValue: 0)
}

@MainActor
private final class RenderRecorder {
    struct Snapshot: Sendable, Equatable {
        let title: String
        let count: Int
    }

    private(set) var snapshots: [Snapshot] = []

    func recordSnapshot(title: String, count: Int) {
        snapshots.append(.init(title: title, count: count))
    }
}

private struct DemoInjectionProbeView: View {
    let store: DemoInjectionStore
    let recorder: RenderRecorder

    var body: some View {
        recorder.recordSnapshot(title: store.title.value, count: store.count.value)

        return VStack(spacing: 8) {
            Text(store.title.value)
                .font(.headline)
            Text("Count: \(store.count.value)")
        }
        .padding()
    }
}

@MainActor
private func waitForSnapshots(in recorder: RenderRecorder, minimumCount: Int) async throws {
    let timeout: Duration = .seconds(2)
    let pollInterval: Duration = .milliseconds(20)
    var elapsed: Duration = .zero

    while recorder.snapshots.count < minimumCount {
        guard elapsed < timeout else {
            Issue.record("Timed out waiting for \(minimumCount) renders; captured \(recorder.snapshots.count)")
            return
        }

        try await Task.sleep(for: pollInterval)
        elapsed += pollInterval
    }
}
#endif // canImport(SwiftUI)
