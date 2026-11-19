import Foundation

public extension L10n {
    /// Notch Island (feature id `island`).
    enum Island {
        public static var displayName: String { tr("island.displayName", "Notch Island") }
        public static var summary: String {
            tr("island.summary.short", "Turns the notch into a live island for music, your calendar, files and live activities.")
        }
        public static var tagline: String { tr("island.tagline", "Music, calendar and notices in the notch.") }
        public static var hotkey: String { tr("island.hotkey", "Open Notch Island") }
        public static var openTray: String { tr("island.command.tray", "Open Notch Tray") }
        public static var openWidgets: String { tr("island.command.widgets", "Open Notch Widgets") }
        public static var openMirror: String { tr("island.command.mirror", "Open Notch Mirror") }

        // Pages.
        public static var homePage: String { tr("island.page.home", "Home") }
        public static var homeSetting: String { tr("island.settings.home", "Home page") }
        public static var homeHelp: String { tr("island.settings.homeHelp", "Music, your next events and the focus timer together on one page.") }
        public static var previousWidgets: String { tr("island.widgets.previous", "Previous Widgets") }
        public static var nextWidgets: String { tr("island.widgets.next", "Next Widgets") }
        public static var musicPage: String { tr("island.page.music", "Music") }
        public static var calendarPage: String { tr("island.page.calendar", "Calendar") }
        public static var focusPage: String { tr("island.page.focus", "Focus") }
        public static var openFocus: String { tr("island.command.focus", "Open Notch Focus") }
        public static func weekNumber(_ week: Int) -> String { format("island.calendar.week", "W%lld", week) }
        public static var startTimer: String { tr("island.focus.start", "Start Timer") }
        public static var pause: String { tr("island.focus.pause", "Pause") }
        public static var resume: String { tr("island.focus.resume", "Resume") }
        public static var stopwatch: String { tr("island.focus.stopwatch", "Stopwatch") }
        public static var focusPageSetting: String { tr("island.settings.focusPage", "Focus timer") }
        public static var focusPageHelp: String { tr("island.settings.focusPageHelp", "Focus and break timers on a ruler, plus a stopwatch.") }
        public static var trayPage: String { tr("island.page.tray", "Tray") }
        public static var widgetsPage: String { tr("island.page.widgets", "Widgets") }

        // Now Playing.
        public static var nothingPlaying: String { tr("island.music.nothing", "Nothing playing") }
        public static var nothingPlayingHint: String { tr("island.music.hint", "Play something in Music or Spotify.") }
        public static var playPause: String { tr("island.music.playPause", "Play or Pause") }
        public static var next: String { tr("island.music.next", "Next") }
        public static var previous: String { tr("island.music.previous", "Previous") }
        public static var shuffle: String { tr("island.music.shuffle", "Shuffle") }
        public static var output: String { tr("island.music.output", "Audio Output") }
        public static func openApp(_ app: String) -> String { format("island.music.open", "Open %@", app) }

        // Mirror.
        public static var mirror: String { tr("island.mirror", "Mirror") }
        public static var allowCamera: String { tr("island.mirror.allow", "Turn On Camera…") }
        public static var cameraDenied: String {
            tr("island.mirror.denied", "Turn on Camera for All Set in System Settings → Privacy & Security.")
        }
        public static var noCamera: String { tr("island.mirror.none", "No camera found") }

        // Calendar.
        public static var noMoreToday: String { tr("island.calendar.noMore", "No more events today") }
        public static var nothingThatDay: String { tr("island.calendar.nothingThatDay", "Nothing that day") }
        public static func more(_ count: Int) -> String { plural("island.calendar.more", one: "+%lld more", other: "+%lld more", count) }
        public static var allDay: String { tr("island.calendar.allDay", "All day") }
        public static var showCalendar: String { tr("island.calendar.allow", "Show My Events…") }
        public static var calendarDenied: String {
            tr("island.calendar.denied", "Turn on Calendars for All Set in System Settings → Privacy & Security.")
        }
        public static var join: String { tr("island.calendar.join", "Join") }
        public static var now: String { tr("island.calendar.now", "now") }
        public static func inMinutes(_ minutes: Int) -> String { plural("island.calendar.inMinutes", one: "in %lld min", other: "in %lld min", minutes) }

        // Tray.
        public static var airDrop: String { tr("island.tray.airdrop", "AirDrop") }
        public static var airDropHint: String { tr("island.tray.airdropHint", "Drop files here") }
        public static var airDropHelp: String { tr("island.tray.airdropHelp", "Drop files to send them with AirDrop, or click to send the Tray's files.") }
        public static var trayEmpty: String { tr("island.tray.empty", "Drop files here") }
        public static var trayEmptyHint: String { tr("island.tray.emptyHint", "Drag files to the notch to keep them handy, then drag them anywhere.") }
        public static func items(_ count: Int) -> String { plural("island.tray.items", one: "%lld file", other: "%lld files", count) }
        public static func selected(_ count: Int) -> String { plural("island.tray.selected", one: "%lld selected", other: "%lld selected", count) }
        public static var dragAll: String { tr("island.tray.dragAll", "Drag") }
        public static var dragAllHelp: String { tr("island.tray.dragAllHelp", "Drag the selected files (or all of them) out together.") }
        public static var share: String { tr("island.tray.share", "Share…") }
        public static var clearTray: String { tr("island.tray.clear", "Clear Tray") }
        public static var removeSelected: String { tr("island.tray.removeSelected", "Remove Selected") }
        public static var open: String { tr("island.tray.open", "Open") }
        public static var showInFinder: String { tr("island.tray.finder", "Show in Finder") }
        public static var copyPath: String { tr("island.tray.copyPath", "Copy Path") }
        public static var removeFromTray: String { tr("island.tray.remove", "Remove from Tray") }
        public static var droppedImage: String { tr("island.tray.droppedImage", "Image") }

        // Widgets.
        public static var timer: String { tr("island.widget.timer", "Timer") }
        public static var todos: String { tr("island.widget.todos", "To-dos") }
        public static var notes: String { tr("island.widget.notes", "Note") }
        public static var quickActions: String { tr("island.widget.quick", "Quick Actions") }
        public static var shortcuts: String { tr("island.widget.shortcuts", "Shortcuts") }
        public static var stats: String { tr("island.widget.stats", "Stats") }
        public static var noWidgets: String { tr("island.widget.none", "No widgets") }
        public static var addWidget: String { tr("island.widget.add", "Add Widget") }
        public static var editWidgets: String { tr("island.widget.edit", "Edit Widgets") }
        public static var resetWidgets: String { tr("island.widget.reset", "Reset Widgets") }
        public static var removeWidget: String { tr("island.widget.remove", "Remove Widget") }
        public static var moveLeft: String { tr("island.widget.moveLeft", "Move Left") }
        public static var moveRight: String { tr("island.widget.moveRight", "Move Right") }
        public static func widgetPage(_ number: Int) -> String { format("island.widget.page", "Widgets page %lld", number) }

        public static var start: String { tr("island.timer.start", "Start") }
        public static var pomodoro: String { tr("island.timer.pomodoro", "Focus") }
        public static func pomodoroHelp(_ focus: Int, _ rest: Int) -> String {
            format("island.timer.pomodoroHelp", "Pomodoro: %lld minutes of focus, then a %lld-minute break; a longer one every fourth round.", focus, rest)
        }
        public static var addTimer: String { tr("island.timer.add", "Add another timer") }
        public static var stopTimer: String { tr("island.timer.stop", "Stop Timer") }
        public static var focus: String { tr("island.timer.focus", "Focus") }
        public static var rest: String { tr("island.timer.rest", "Break") }
        public static var min: String { tr("island.timer.min", "min") }
        public static func minutes(_ count: Int) -> String { plural("island.timer.minutes", one: "%lld minute", other: "%lld minutes", count) }
        public static var scrollToSet: String { tr("island.timer.scroll", "Scroll to set the minutes.") }
        public static var timeUp: String { tr("island.timer.done", "Time's up") }
        public static var focusDone: String { tr("island.timer.focusDone", "Focus done. Take a break") }
        public static var breakOver: String { tr("island.timer.breakOver", "Break over. Back to focus") }

        public static var addTodo: String { tr("island.todo.add", "Add a to-do") }
        public static func doneOf(_ done: Int, _ total: Int) -> String { format("island.todo.doneOf", "%lld of %lld", done, total) }
        public static var delete: String { tr("island.todo.delete", "Delete") }
        public static var clearDone: String { tr("island.todo.clearDone", "Clear Completed") }

        public static var notePlaceholder: String { tr("island.note.placeholder", "Jot something down…") }
        public static func characters(_ count: Int) -> String { plural("island.note.characters", one: "%lld char", other: "%lld chars", count) }

        public static var wifi: String { tr("island.quick.wifi", "Wi-Fi") }
        public static var darkMode: String { tr("island.quick.dark", "Dark Mode") }
        public static var keepAwake: String { tr("island.quick.keepAwake", "Keep Awake") }
        public static var screenshot: String { tr("island.quick.screenshot", "Screenshot") }
        public static var newNote: String { tr("island.quick.note", "New Sticky Note") }
        public static var sleepDisplay: String { tr("island.quick.sleep", "Sleep Display") }

        public static var loading: String { tr("island.shortcuts.loading", "Loading…") }
        public static var noShortcuts: String { tr("island.shortcuts.none", "No shortcuts in the Shortcuts app") }
        public static var chooseShortcuts: String { tr("island.shortcuts.choose", "Choose Shortcuts") }
        public static var shortcutsHint: String { tr("island.shortcuts.hint", "Press + to pin shortcuts here.") }
        public static var removeShortcut: String { tr("island.shortcuts.remove", "Unpin") }

        public static var cpu: String { tr("island.stats.cpu", "CPU") }
        public static var memory: String { tr("island.stats.memory", "Memory") }

        // Notices and activities.
        public static var charging: String { tr("island.notice.charging", "Charging") }
        public static var fullyCharged: String { tr("island.notice.full", "Fully charged") }
        public static var onBattery: String { tr("island.notice.onBattery", "On battery") }
        public static var lowBattery: String { tr("island.notice.lowBattery", "Low battery") }
        public static func connected(_ name: String) -> String { format("island.notice.connected", "%@ connected", name) }
        public static func disconnected(_ name: String) -> String { format("island.notice.disconnected", "%@ disconnected", name) }
        public static var muted: String { tr("island.volume.muted", "Muted") }
        public static var recording: String { tr("island.activity.recording", "Recording") }
        public static func downloading(_ name: String) -> String { format("island.activity.downloading", "Downloading %@", name) }
        public static func downloaded(_ name: String) -> String { format("island.activity.downloaded", "Downloaded %@", name) }

        // Settings.
        public static var showCalendarSetting: String { tr("island.settings.calendar", "Calendar") }
        public static var calendarHelp: String {
            tr("island.settings.calendarHelp", "Your week from the Calendar app. Google and Exchange accounts added in macOS show too.")
        }
        public static var mirrorSetting: String { tr("island.settings.mirror", "Camera mirror") }
        public static var mirrorHelp: String { tr("island.settings.mirrorHelp", "Check how you look before a call. The camera runs only while the mirror is showing.") }

        public static var traySection: String { tr("island.settings.traySection", "Tray") }
        public static var traySetting: String { tr("island.settings.tray", "Tray for files and AirDrop") }
        public static var trayHelp: String { tr("island.settings.trayHelp", "The Tray keeps a link to each file, not a copy.") }
        public static var dragOpensTray: String { tr("island.settings.dragOpens", "Open the Tray when files are dragged to the notch") }
        public static var removeAfterDrag: String { tr("island.settings.removeAfterDrag", "Remove files from the Tray after dragging them out") }

        public static var hideSpacesOnDrag: String { tr("island.settings.hideSpaces", "Don't show Spaces when dragging to the top edge") }

        public static var widgetsSection: String { tr("island.settings.widgetsSection", "Widgets") }
        public static var widgetsSetting: String { tr("island.settings.widgets", "Widgets page") }
        public static var timerSound: String { tr("island.settings.timerSound", "Play a sound when a timer ends") }

        public static var liveActivities: String { tr("island.settings.live", "Live activities") }
        public static var meetingCountdown: String { tr("island.settings.meetings", "Count down to the next meeting") }
        public static var meetingHelp: String { tr("island.settings.meetingsHelp", "Shows in the notch 10 minutes before an event starts.") }
        public static var batteryNotices: String { tr("island.settings.battery", "Charging and low battery") }
        public static var bluetoothNotices: String { tr("island.settings.bluetooth", "AirPods and other Bluetooth devices") }
        public static var volumeHelp: String { tr("island.settings.volumeHelp", "macOS still shows its own volume overlay too.") }
        public static var downloadsSetting: String { tr("island.settings.downloads", "Downloads") }

        public static var look: String { tr("island.settings.look", "Look") }
        public static var style: String { tr("island.settings.style", "Style") }
        public static var lookBlack: String { tr("island.settings.black", "Black") }
        public static var lookGlass: String { tr("island.settings.glass", "Glass") }
        public static var noNotchStyle: String { tr("island.settings.noNotchStyle", "Screens without a notch") }
        public static var noNotchShape: String { tr("island.settings.noNotchShape", "Notch shape") }
        public static var noNotchHandle: String { tr("island.settings.noNotchHandle", "Small handle") }
        public static var allDisplays: String { tr("island.settings.allDisplays", "Show on every display") }
        public static var allDisplaysHelp: String { tr("island.settings.allDisplaysHelp", "Each display gets its own island.") }
        public static var virtualNotch: String { tr("island.settings.virtual", "Show on the main display when no screen has a notch") }

        public static var openOnHover: String { tr("island.settings.hover", "Open when the pointer rests on the notch") }
        public static var hoverDelay: String { tr("island.settings.hoverDelay", "Opens after") }
        public static var delayShort: String { tr("island.settings.delayShort", "A moment") }
        public static var delayNormal: String { tr("island.settings.delayNormal", "A short pause") }
        public static var delayLong: String { tr("island.settings.delayLong", "A longer pause") }
        public static var musicSwipes: String { tr("island.settings.swipes", "Swipe on the closed notch to skip songs") }
        public static var musicSwipesHelp: String { tr("island.settings.swipesHelp", "Two fingers left for the next song, right for the previous one.") }
        public static var noNotchHere: String {
            tr("island.settings.noNotch", "This screen has no notch, so the island is a small black shape at the top middle.")
        }
        // Settings page (All Set design).
        public static var tabNook: String { tr("island.settings.tab.nook", "Nook") }
        public static var tabLookBehavior: String { tr("island.settings.tab.look", "Look and behavior") }
        public static var nowPlaying: String { tr("island.settings.nowPlaying", "Now Playing") }
        public static var nowPlayingHelp: String {
            tr("island.settings.nowPlayingHelp", "Music and Spotify. The first time, macOS asks to let All Set control them.")
        }
        public static var hideSpacesHelpShort: String {
            tr("island.settings.hideSpacesHelpShort", "macOS shows your desktops when you drag to the top, which covers the notch. This changes a Desktop & Dock setting, and the Dock restarts once.")
        }
        public static var widgetsDragHelp: String {
            tr("island.settings.widgetsDragHelp", "Drag to reorder. Or right-click the open island to add, move or remove widgets.")
        }
        public static var focusLengthTitle: String { tr("island.settings.focusLength", "Focus length") }
        public static var breakLengthTitle: String { tr("island.settings.breakLength", "Break length") }
        public static func minutesValue(_ minutes: Int) -> String { plural("island.settings.minutesValue", one: "%lld min", other: "%lld min", minutes) }
        public static var moreFocus: String { tr("island.settings.moreFocus", "More focus time") }
        public static var lessFocus: String { tr("island.settings.lessFocus", "Less focus time") }
        public static var moreBreak: String { tr("island.settings.moreBreak", "More break time") }
        public static var lessBreak: String { tr("island.settings.lessBreak", "Less break time") }
        public static var volumeChanges: String { tr("island.settings.volumeChanges", "Volume changes") }
        public static var bluetoothHelpAllSet: String { tr("island.settings.bluetoothHelp2", "macOS asks once to let All Set see Bluetooth devices.") }
        public static var downloadsHelpAllSet: String {
            tr("island.settings.downloadsHelp2", "Shows files a browser is saving to Downloads. macOS asks once to let All Set see that folder.")
        }
        public static var openOnHoverHelpShort: String {
            tr("island.settings.hoverHelpShort", "Otherwise click the notch, or swipe down on it with two fingers.")
        }
        public static var heroSong: String { tr("island.settings.hero.song", "Song title") }
        public static var heroArtist: String { tr("island.settings.hero.artist", "Artist") }
        public static var heroDescription: String {
            tr("island.settings.hero.a11y", "Example: the notch opened as an island showing the song that is playing")
        }
    }
}
