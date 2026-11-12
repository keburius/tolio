import OmniCore
import SwiftUI

public extension SettingsStore {
    /// A SwiftUI binding that reads and writes one setting.
    func binding<Value>(_ key: SettingKey<Value>) -> Binding<Value> {
        Binding(get: { self.value(key) }, set: { self.set($0, for: key) })
    }
}
