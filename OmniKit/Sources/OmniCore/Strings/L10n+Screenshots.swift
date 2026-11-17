import Foundation

public extension L10n {
    /// Screenshots & Recording: captures, the editor, pins and screen recording.
    enum Screenshots {
        public static var displayName: String { tr("screenshots.displayName", "Screenshots & Recording") }
        public static var summary: String {
            tr("screenshots.summary", "Capture, mark up and pin screenshots, copy text from images and record the screen.")
        }

        // MARK: Shortcuts (sentence case, as in the shortcuts table)

        public static var hotkeyArea: String { tr("screenshots.hotkey.area", "Capture area or window") }
        public static var hotkeyScreen: String { tr("screenshots.hotkey.screen", "Capture screen") }
        public static var hotkeyText: String { tr("screenshots.hotkey.text", "Capture text") }
        public static var hotkeyRecord: String { tr("screenshots.hotkey.record", "Start or stop screen recording") }
        public static var hotkeyScrolling: String { tr("screenshots.hotkey.scrolling", "Scrolling capture (experimental)") }

        // MARK: Commands and menus (title case)

        public static var captureArea: String { tr("screenshots.command.area", "Capture Area or Window") }
        public static var captureScreen: String { tr("screenshots.command.screen", "Capture Screen") }
        public static var recordOrStop: String { tr("screenshots.command.record", "Record Screen / Stop Recording") }
        public static var scrollingCapture: String { tr("screenshots.command.scrolling", "Scrolling Capture (Experimental)") }
        public static var turnOnScrolling: String {
            tr("screenshots.scrolling.turnOn", "Turn on scrolling capture in Screenshots & Recording settings")
        }

        // MARK: Quick access

        public static var screenshotTitle: String { tr("screenshots.quick.screenshot", "Screenshot") }
        public static var screenshotClickHint: String { tr("screenshots.quick.screenshot.hint", "capture an area") }
        public static var recordingTitle: String { tr("screenshots.quick.recording", "Screen Recording") }
        public static var recordingClickHint: String { tr("screenshots.quick.recording.hint", "start recording") }
        public static var recordScreen: String { tr("screenshots.menu.recordScreen", "Record Screen") }
        public static var recordScreenEllipsis: String { tr("screenshots.menu.recordScreenEllipsis", "Record Screen…") }
        public static var stopRecording: String { tr("screenshots.menu.stopRecording", "Stop Recording") }
        public static var afterCapturingMenu: String { tr("screenshots.menu.afterCapturing", "After Capturing") }
        public static var openScreenshotsFolder: String { tr("screenshots.menu.openScreenshotsFolder", "Open Screenshots Folder") }
        public static var openRecordingsFolder: String { tr("screenshots.menu.openRecordingsFolder", "Open Recordings Folder") }
        public static var frameRateMenu: String { tr("screenshots.menu.frameRate", "Frame Rate") }
        public static var showPointerMenu: String { tr("screenshots.menu.showPointer", "Show the Pointer") }
        public static var systemAudioMenu: String { tr("screenshots.menu.systemAudio", "Record System Audio") }
        public static var microphoneMenu: String { tr("screenshots.menu.microphone", "Record the Microphone") }

        // MARK: After capturing (menu titles / settings labels)

        public static var afterEditorMenu: String { tr("screenshots.after.editor.menu", "Open in Editor") }
        public static var afterCopyMenu: String { tr("screenshots.after.copy.menu", "Copy") }
        public static var afterSaveMenu: String { tr("screenshots.after.save.menu", "Save") }
        public static var afterPinMenu: String { tr("screenshots.after.pin.menu", "Pin on Screen") }
        public static var afterEditor: String { tr("screenshots.after.editor", "Open in the editor") }
        public static var afterCopy: String { tr("screenshots.after.copy", "Copy to the clipboard") }
        public static var afterSave: String { tr("screenshots.after.save", "Save to the folder") }
        public static var afterPin: String { tr("screenshots.after.pin", "Pin on screen") }

        // MARK: Settings

        public static var sectionScreenshots: String { tr("screenshots.settings.section.screenshots", "Screenshots") }
        public static var sectionRecording: String { tr("screenshots.settings.section.recording", "Screen Recording") }
        public static var sectionExperimental: String { tr("screenshots.settings.section.experimental", "Experimental") }
        public static var afterCapturing: String { tr("screenshots.settings.afterCapturing", "After capturing") }
        public static var saveTo: String { tr("screenshots.settings.saveTo", "Save to") }
        public static var choose: String { tr("screenshots.settings.choose", "Choose…") }
        public static var useMacOSSetting: String { tr("screenshots.settings.useMacOSSetting", "Use macOS Setting") }
        public static var windowShadow: String { tr("screenshots.settings.windowShadow", "Include the shadow when capturing a window") }
        public static var resolutionNote: String {
            tr("screenshots.settings.resolutionNote", "Screenshots keep your display's full sharpness and open at their real size.")
        }
        public static var frameRate: String { tr("screenshots.settings.frameRate", "Frame rate") }
        public static func fps(_ value: Int) -> String { format("screenshots.settings.fps", "%lld fps", value) }
        public static var videoFormat: String { tr("screenshots.settings.format", "Format") }
        public static var codecH264: String { tr("screenshots.settings.codec.h264", "H.264 (plays everywhere)") }
        public static var codecHEVC: String { tr("screenshots.settings.codec.hevc", "HEVC (smaller files)") }
        public static var showPointer: String { tr("screenshots.settings.showPointer", "Show the pointer") }
        public static var systemAudio: String { tr("screenshots.settings.systemAudio", "Record system audio") }
        public static var microphone: String { tr("screenshots.settings.microphone", "Record the microphone (macOS 15 or later)") }
        public static var recordingNote: String {
            tr("screenshots.settings.recordingNote", "Recordings are saved as MP4 videos in the same folder. System audio and the microphone are saved as two audio tracks. To stop, press the recording shortcut again or click the recording timer in the menu bar.")
        }
        public static var scrollingToggle: String { tr("screenshots.settings.scrolling", "Scrolling capture") }
        public static var scrollingNote: String {
            tr("screenshots.settings.scrollingNote", "Select the part of a window that scrolls; Tolio scrolls it and joins the pages into one tall image. Needs the Accessibility permission. Works best on plain documents and web pages; content that moves or changes while scrolling can't be joined.")
        }

        // MARK: Selection overlay

        public static var hintScreenshot: String { tr("screenshots.overlay.screenshot", "Drag to capture an area, or click a window. Esc cancels.") }
        public static var hintText: String { tr("screenshots.overlay.text", "Drag over the text to copy, or click a window. Esc cancels.") }
        public static var hintRecord: String {
            tr("screenshots.overlay.record", "Drag to record an area, or click to record the whole screen. Esc cancels.")
        }
        public static var hintScrolling: String {
            tr("screenshots.overlay.scrolling", "Drag over the part that scrolls. Tolio will scroll it and join the pages. Esc cancels.")
        }
        public static func sizeLabel(_ width: Int, _ height: Int) -> String {
            format("screenshots.overlay.size", "%lld × %lld px", width, height)
        }

        // MARK: Messages

        public static var screenshotCopied: String { tr("screenshots.hud.screenshotCopied", "Screenshot copied") }
        public static var copied: String { tr("screenshots.hud.copied", "Copied") }
        public static func savedTo(_ folder: String) -> String { format("screenshots.hud.savedTo", "Saved to %@", folder) }
        public static func couldntSave(_ reason: String) -> String { format("screenshots.hud.couldntSave", "Couldn't save: %@", reason) }
        public static var recognizingText: String { tr("screenshots.hud.recognizingText", "Recognizing text…") }
        public static var noTextFound: String { tr("screenshots.hud.noTextFound", "No text found") }
        public static var textRecognitionFailed: String { tr("screenshots.hud.textRecognitionFailed", "Text recognition failed") }
        public static var scrolling: String { tr("screenshots.hud.scrolling", "Scrolling… hold Esc to stop") }
        public static func joinedPages(_ count: Int, reason: String) -> String {
            let pages = plural("screenshots.hud.joinedPages", one: "Joined %lld page", other: "Joined %lld pages", count)
            return format("screenshots.hud.joinedPagesReason", "%@: %@", pages, reason)
        }

        // MARK: Scrolling capture outcomes

        public static var reasonPageLimit: String { tr("screenshots.scroll.pageLimit", "reached the page limit") }
        public static var reasonStopped: String { tr("screenshots.scroll.stopped", "stopped with Esc") }
        public static var reasonUnmatched: String { tr("screenshots.scroll.unmatched", "the page changed in a way that couldn't be matched") }
        public static var reasonEnd: String { tr("screenshots.scroll.end", "reached the end") }
        public static var reasonSizeLimit: String { tr("screenshots.scroll.sizeLimit", "reached the size limit") }

        // MARK: Recording

        public static var micNeedsMacOS15: String { tr("screenshots.recording.micNeedsMacOS15", "Microphone recording needs macOS 15") }
        public static var micNoPermission: String {
            tr("screenshots.recording.micNoPermission", "Recording without the microphone (not allowed)")
        }
        public static func couldntStartRecording(_ reason: String) -> String {
            format("screenshots.recording.couldntStart", "Couldn't start recording: %@", reason)
        }
        public static var recordingSaved: String { tr("screenshots.recording.saved", "Recording saved") }
        public static func recordingFailed(_ reason: String) -> String {
            format("screenshots.recording.failed", "Recording failed: %@", reason)
        }

        // MARK: Errors

        public static var errorNoPermission: String {
            tr("screenshots.error.noPermission", "Tolio needs Screen Recording permission to capture the screen.")
        }
        public static var errorNothingToCapture: String { tr("screenshots.error.nothingToCapture", "That area isn't on any display.") }
        public static func errorFailed(_ reason: String) -> String { format("screenshots.error.failed", "Capture failed: %@", reason) }
        public static var errorNeedsAccessibility: String {
            tr("screenshots.error.needsAccessibility", "scrolling capture needs the Accessibility permission")
        }
        public static var errorReadPixels: String { tr("screenshots.error.readPixels", "couldn't read the image") }
        public static var errorJoinPages: String { tr("screenshots.error.joinPages", "joining the pages failed") }
        public static func errorEncoderSize(_ width: Int, _ height: Int) -> String {
            format("screenshots.error.encoderSize", "this Mac can't record a video of %lld × %lld pixels", width, height)
        }
        public static var errorStartFile: String { tr("screenshots.error.startFile", "couldn't start the file") }
        public static var errorNoFrames: String { tr("screenshots.error.noFrames", "no frames were recorded") }
        public static var errorFinishFile: String { tr("screenshots.error.finishFile", "the file couldn't be finished") }
        public static var errorEmptyWindow: String { tr("screenshots.error.emptyWindow", "the window came out empty") }
        public static var errorOutOfMemory: String { tr("screenshots.error.outOfMemory", "out of memory") }
        public static var errorCompositing: String { tr("screenshots.error.compositing", "the screens couldn't be combined") }
        public static var errorEncoding: String { tr("screenshots.error.encoding", "the image couldn't be saved as PNG") }

        // MARK: Editor

        public static var editorWindowTitle: String { tr("screenshots.editor.windowTitle", "Screenshot") }
        public static var toolSelect: String { tr("screenshots.tool.select", "Select and move (V)") }
        public static var captureText: String { tr("screenshots.captureText", "Capture Text") }
        public static var captureTextSubtitle: String { tr("screenshots.captureText.subtitle", "Copy the text, QR code or barcode in part of the screen") }
        public static func copiedCharacters(_ count: Int) -> String {
            plural("screenshots.captureText.copied", one: "Copied %lld character", other: "Copied %lld characters", count)
        }
        public static func appendedCharacters(_ added: Int, _ total: Int) -> String {
            format("screenshots.captureText.appended", "Added %lld more (%lld characters in total)", added, total)
        }
        public static func copiedLink(_ host: String) -> String { format("screenshots.captureText.copiedLink", "Copied a link to %@", host) }
        public static func copiedCode(_ count: Int) -> String {
            plural("screenshots.captureText.copiedCode", one: "Copied a code (%lld character)", other: "Copied a code (%lld characters)", count)
        }
        public static var open: String { tr("screenshots.captureText.open", "Open") }
        public static var captureTextSummary: String {
            tr("capturetext.summary", "Copy the text, QR code or barcode from any part of the screen.")
        }
        public static var captureTextClickHint: String { tr("screenshots.captureText.clickHint", "capture text") }
        public static var appendHint: String { tr("screenshots.captureText.appendHint", "Hold ⇧ when you finish selecting to add to your previous capture") }
        public static var sectionCaptureText: String { tr("screenshots.section.captureText", "Capture Text") }
        public static var lineBreaks: String { tr("screenshots.captureText.lineBreaks", "Line breaks") }
        public static var lineBreaksKeep: String { tr("screenshots.captureText.lineBreaks.keep", "Keep them") }
        public static var lineBreaksJoin: String { tr("screenshots.captureText.lineBreaks.join", "Join into one paragraph") }
        public static var recognitionLanguages: String { tr("screenshots.captureText.languages", "Recognition languages") }
        public static var languagesMatchMac: String { tr("screenshots.captureText.languages.matchMac", "Same as your Mac's languages") }
        public static func languagesMatchMacSummary(_ list: String) -> String { format("screenshots.captureText.languages.matchMacSummary", "Same as your Mac (%@)", list) }
        public static var autoLanguage: String { tr("screenshots.captureText.autoLanguage", "Detect the language automatically") }
        public static var autoLanguageNote: String {
            tr("screenshots.captureText.autoLanguageNote", "Helps with mixed languages but can make recognition much slower on some macOS versions.")
        }
        public static var speakAloud: String { tr("screenshots.captureText.speak", "Read captured text aloud") }
        public static var captureTextNote: String {
            tr("screenshots.captureText.note", "Hold ⇧ when you finish the selection to add the text to your previous capture. QR codes and barcodes are copied too; for a link you get an Open button. Everything is recognized on this Mac.")
        }
        public static var toolBrush: String { tr("screenshots.tool.brush", "Brush (P)") }
        public static var deleteSelected: String { tr("screenshots.deleteSelected", "Delete the selected mark, or the last one you drew (⌫)") }
        public static var delete: String { tr("screenshots.delete", "Delete") }
        public static var barMicrophone: String { tr("screenshots.bar.mic", "Microphone") }
        public static var barSystemAudio: String { tr("screenshots.bar.systemAudio", "System Audio") }
        public static var barPointer: String { tr("screenshots.bar.pointer", "Pointer") }
        public static var barRecord: String { tr("screenshots.bar.record", "Record") }
        public static var barPause: String { tr("screenshots.bar.pause", "Pause") }
        public static var barResume: String { tr("screenshots.bar.resume", "Resume") }
        public static var barMute: String { tr("screenshots.bar.mute", "Mute Mic") }
        public static var barUnmute: String { tr("screenshots.bar.unmute", "Unmute Mic") }
        public static var barMicHelp: String { tr("screenshots.bar.micHelp", "Turn the microphone off and on while recording") }
        public static var barMicOffHelp: String { tr("screenshots.bar.micOffHelp", "Turn on Microphone before you start recording to use this") }
        public static var barStop: String { tr("screenshots.bar.stop", "Stop") }
        public static var barDiscard: String { tr("screenshots.bar.discard", "Stop and throw the recording away (moved to the Trash)") }
        public static var recordingDiscarded: String { tr("screenshots.recordingDiscarded", "Recording moved to the Trash") }
        public static var fps30: String { tr("screenshots.bar.fps30", "30 fps") }
        public static var fps60: String { tr("screenshots.bar.fps60", "60 fps") }
        public static var deleteScreenshot: String { tr("screenshots.deleteScreenshot", "Delete this screenshot and close the window (it isn't saved)") }
        public static var screenshotDeleted: String { tr("screenshots.screenshotDeleted", "Screenshot deleted") }
        public static var toolArrow: String { tr("screenshots.tool.arrow", "Arrow (A)") }
        public static var toolBox: String { tr("screenshots.tool.box", "Box (R)") }
        public static var toolText: String { tr("screenshots.tool.text", "Text (T)") }
        public static var toolHighlight: String { tr("screenshots.tool.highlight", "Highlight (H)") }
        public static var toolBlur: String { tr("screenshots.tool.blur", "Blur (B)") }
        public static var toolStep: String { tr("screenshots.tool.step", "Numbered step (N)") }
        public static var toolCrop: String { tr("screenshots.tool.crop", "Crop (C)") }
        public static var undo: String { tr("screenshots.editor.undo", "Undo") }
        public static var redo: String { tr("screenshots.editor.redo", "Redo") }
        public static var resetCrop: String { tr("screenshots.editor.resetCrop", "Reset Crop") }
        public static var copyText: String { tr("screenshots.editor.copyText", "Copy Text") }
        public static var copyTextHelp: String {
            tr("screenshots.editor.copyText.help", "Recognize text in the image (on this Mac) and copy it")
        }
        public static var pin: String { tr("screenshots.editor.pin", "Pin") }
        public static var pinHelp: String { tr("screenshots.editor.pin.help", "Keep the image floating above other windows") }
        public static var copy: String { tr("screenshots.editor.copy", "Copy") }
        public static var save: String { tr("screenshots.editor.save", "Save") }
        public static var textPlaceholder: String { tr("screenshots.editor.textPlaceholder", "Text") }
        public static func color(_ name: String) -> String { format("screenshots.editor.color", "Color: %@", name) }
        public static var colorRed: String { tr("screenshots.color.red", "red") }
        public static var colorOrange: String { tr("screenshots.color.orange", "orange") }
        public static var colorYellow: String { tr("screenshots.color.yellow", "yellow") }
        public static var colorGreen: String { tr("screenshots.color.green", "green") }
        public static var colorBlue: String { tr("screenshots.color.blue", "blue") }
        public static var colorBlack: String { tr("screenshots.color.black", "black") }
        public static var colorWhite: String { tr("screenshots.color.white", "white") }

        // MARK: Pinned image

        public static var closePinHelp: String { tr("screenshots.pin.closeHelp", "Close (Esc)") }
        public static var edit: String { tr("screenshots.pin.edit", "Edit…") }
        public static var opacity: String { tr("screenshots.pin.opacity", "Opacity") }
        public static func percent(_ value: Int) -> String { format("screenshots.pin.percent", "%lld%%", value) }

        // MARK: Files (names like macOS's own)

        public static var fileScreenshot: String { tr("screenshots.file.screenshot", "Screenshot") }
        public static var fileRecording: String { tr("screenshots.file.recording", "Screen Recording") }
    }
}
