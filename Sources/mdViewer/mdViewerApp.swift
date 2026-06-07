import SwiftUI

@main
struct MdViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(initialFileURL: initialFileURL)
                .frame(minWidth: 1220, minHeight: 820)
                .background(AppColor.windowBackground)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .defaultSize(width: 1380, height: 900)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

    private var initialFileURL: URL? {
        CommandLine.arguments.dropFirst().first.map {
            URL(fileURLWithPath: $0).standardizedFileURL
        }
    }
}
