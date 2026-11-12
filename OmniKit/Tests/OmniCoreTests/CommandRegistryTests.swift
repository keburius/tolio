@testable import OmniCore
import Testing

@MainActor
struct CommandRegistryTests {
    private func command(_ id: String, _ title: String) -> Command {
        Command(id: id, title: title, symbolName: "circle") {}
    }

    @Test func listsAllCommandsSortedByTitle() {
        let registry = CommandRegistry()
        registry.register(command("b", "Beta"), owner: "x")
        registry.register(command("a", "Alpha"), owner: "y")
        #expect(registry.allCommands.map(\.title) == ["Alpha", "Beta"])
    }

    @Test func reRegisteringSameIDReplaces() {
        let registry = CommandRegistry()
        registry.register(command("a", "Old"), owner: "x")
        registry.register(command("a", "New"), owner: "x")
        #expect(registry.allCommands.map(\.title) == ["New"])
    }

    @Test func unregisterAllRemovesOnlyThatOwner() {
        let registry = CommandRegistry()
        registry.register(command("a", "A"), owner: "x")
        registry.register(command("b", "B"), owner: "y")
        registry.unregisterAll(owner: "x")
        #expect(registry.allCommands.map(\.id) == ["b"])
    }
}
