import Foundation
import Observation

@Observable
public final class Signal<T: Equatable & Sendable>: Sendable {
    private let lock = NSLock()
    private let _value: Box<T>
    private let continuations: Box<[UUID: AsyncStream<T>.Continuation]>

    public var value: T {
        get {
            access(keyPath: \.value)
            lock.lock()
            defer { lock.unlock() }
            return _value.value
        }
        set {
            withMutation(keyPath: \.value) {
                lock.lock()
                let oldValue = _value.value
                let shouldEmit = newValue != oldValue
                _value.value = newValue
                let currentContinuations = continuations.value
                lock.unlock()

                if shouldEmit {
                    for continuation in currentContinuations.values {
                        continuation.yield(newValue)
                    }
                }
            }
        }
    }

    public init(initialValue: T) {
        self._value = Box(initialValue)
        self.continuations = Box([:])
    }

    public var values: AsyncStream<T> {
        AsyncStream { continuation in
            let id = UUID()

            self.lock.lock()
            self.continuations.value[id] = continuation
            self.lock.unlock()

            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuations.value.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }
}

public protocol ReadOnlySignal<T>: Sendable {
    associatedtype T: Equatable & Sendable
    var value: T { get }
    var values: AsyncStream<T> { get }
}

extension Signal: ReadOnlySignal {}

@Observable
public final class ComputedSignal<T: Equatable & Sendable>: ReadOnlySignal, Sendable {
    private let lock = NSLock()
    private let _value: Box<T>
    private let continuations: Box<[UUID: AsyncStream<T>.Continuation]>
    private let compute: @Sendable () -> T
    private let subscriptionTask: Box<Task<Void, Never>?>

    public var value: T {
        access(keyPath: \.value)

        let newValue = compute()

        lock.lock()
        let oldValue = _value.value
        let shouldEmit = newValue != oldValue
        _value.value = newValue
        let currentContinuations = continuations.value
        lock.unlock()

        if shouldEmit {
            for continuation in currentContinuations.values {
                continuation.yield(newValue)
            }
        }

        return newValue
    }

    public var values: AsyncStream<T> {
        AsyncStream { continuation in
            let id = UUID()

            self.lock.lock()
            self.continuations.value[id] = continuation
            self.lock.unlock()

            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuations.value.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    fileprivate init<S: ReadOnlySignal>(dependencies: [S], compute: @escaping @Sendable () -> T) where S.T == T {
        let initialValue = compute()
        self._value = Box(initialValue)
        self.continuations = Box([:])
        self.compute = compute
        self.subscriptionTask = Box(nil)

        // NOTE: Subscribe to all dependencies
        self.subscriptionTask.value = Task { @Sendable [weak self] in
            await withTaskGroup(of: Void.self) { group in
                for dependency in dependencies {
                    group.addTask { @Sendable [weak self] in
                        for await _ in dependency.values {
                            guard let self else { break }
                            self.recompute()
                        }
                    }
                }
            }
        }
    }

    fileprivate init(compute: @escaping @Sendable () -> T, subscribe: @escaping @Sendable (@escaping @Sendable () -> Void) -> Task<Void, Never>) {
        let initialValue = compute()
        self._value = Box(initialValue)
        self.continuations = Box([:])
        self.compute = compute
        self.subscriptionTask = Box(nil)

        self.subscriptionTask.value = subscribe { [weak self] in
            self?.recompute()
        }
    }

    private nonisolated func recompute() {
        let newValue = compute()

        lock.lock()
        let oldValue = _value.value
        let shouldEmit = newValue != oldValue
        _value.value = newValue
        let currentContinuations = continuations.value
        lock.unlock()

        if shouldEmit {
            for continuation in currentContinuations.values {
                continuation.yield(newValue)
            }
        }
    }

    deinit {
        subscriptionTask.value?.cancel()
    }
}

public func computed<T: Equatable & Sendable>(_ compute: @escaping @Sendable () -> T) -> ComputedSignal<T> {
    ComputedSignal(compute: compute) { onChange in
        Task { @Sendable in
            let (stream, continuation) = AsyncStream.makeStream(of: Void.self)

            func trackChanges() {
                withObservationTracking {
                    // NOTE: Access the compute function to track its dependencies
                    _ = compute()
                } onChange: {
                    continuation.yield(())
                }
            }

            trackChanges()

            for await _ in stream {
                guard !Task.isCancelled else { break }
                onChange()
                trackChanges()
            }

            continuation.finish()
        }
    }
}

@discardableResult
public func effect(_ action: @escaping @Sendable () -> Void) -> Task<Void, Never> {
    Task { @Sendable in
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)

        func runWithTracking() {
            withObservationTracking {
                action()
            } onChange: {
                continuation.yield(())
            }
        }

        runWithTracking()

        for await _ in stream {
            guard !Task.isCancelled else { break }
            runWithTracking()
        }

        continuation.finish()
    }
}

private final class Box<T>: @unchecked Sendable {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}
