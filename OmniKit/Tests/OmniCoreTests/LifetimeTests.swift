@testable import OmniCore
import Testing

@MainActor
struct LifetimeTests {
    @Test func cancelsInReverseOrderAndEmpties() {
        let lifetime = Lifetime()
        var order: [Int] = []
        lifetime.add { order.append(1) }
        lifetime.add { order.append(2) }
        #expect(lifetime.activeCount == 2)
        lifetime.cancelAll()
        #expect(order == [2, 1])
        #expect(lifetime.activeCount == 0)
    }
}
