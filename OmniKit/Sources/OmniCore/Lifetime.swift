/// Collects teardown closures for everything a feature starts while enabled
/// (timers, event taps, observers, watchers).
///
/// `FeatureRegistry` cancels the lifetime after calling `disable()`, so a
/// disabled feature holds no live resources even if `disable()` forgets one.
@MainActor
public final class Lifetime {
    private var cancellations: [@MainActor () -> Void] = []

    public init() {}

    /// Number of resources still registered.
    public var activeCount: Int { cancellations.count }

    /// Registers a teardown closure. Closures run in reverse order of addition.
    public func add(_ cancel: @escaping @MainActor () -> Void) {
        cancellations.append(cancel)
    }

    public func cancelAll() {
        let pending = cancellations
        cancellations.removeAll()
        for cancel in pending.reversed() { cancel() }
    }
}
