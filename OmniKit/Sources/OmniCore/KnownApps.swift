/// App lists shared by features.
public enum KnownApps {
    /// Password managers. Clipboard history never stores their copies and the
    /// text selection popup never reads selections in them. Users can't remove these.
    public static let passwordManagers: Set<String> = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.agilebits.onepassword-osx",
        "org.keepassxc.keepassxc", "com.bitwarden.desktop", "com.lastpass.LastPass",
        "com.dashlane.dashlanephonefinal", "com.dashlane.Dashlane", "com.apple.Passwords",
        "com.apple.keychainaccess", "in.sinew.Enpass-Desktop", "com.nordpass.macos.NordPass",
        "com.proton.pass.electron",
    ]
}
