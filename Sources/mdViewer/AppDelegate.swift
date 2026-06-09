import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var pendingOpenFileURLs: [URL] = []
    private var quitArmedUntil: Date?
    private let quitPromptDuration: TimeInterval = 3

    static func consumePendingOpenFileURLs() -> [URL] {
        defer { pendingOpenFileURLs.removeAll() }
        return pendingOpenFileURLs
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        setDockIcon()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        queueOpenFileURLs([URL(fileURLWithPath: filename).standardizedFileURL])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        queueOpenFileURLs(filenames.map { URL(fileURLWithPath: $0).standardizedFileURL })
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        queueOpenFileURLs(urls.map(\.standardizedFileURL))
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let quitArmedUntil, Date() <= quitArmedUntil {
            return .terminateNow
        }

        quitArmedUntil = Date().addingTimeInterval(quitPromptDuration)
        NotificationCenter.default.post(name: .showQuitHoldPrompt, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + quitPromptDuration) { [weak self] in
            guard let self, let quitArmedUntil = self.quitArmedUntil, Date() >= quitArmedUntil else { return }
            self.quitArmedUntil = nil
        }

        return .terminateCancel
    }

    private func queueOpenFileURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Self.pendingOpenFileURLs.append(contentsOf: urls)
        notifyPendingOpenFiles()
    }

    private func notifyPendingOpenFiles() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openMarkdownFilesCommand, object: nil)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(name: .openMarkdownFilesCommand, object: nil)
        }
    }

    private func setDockIcon() {
        guard let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: iconURL) else {
            return
        }

        NSApp.applicationIconImage = image
    }
}
