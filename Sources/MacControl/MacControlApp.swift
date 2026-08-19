import AppKit
import MacControlCore
import SwiftUI

@main
struct MacControlApp: App {
    @ObservedObject private var model = AppModel()

    var body: some Scene {
        Window(L10n.appName, id: "main") {
            RootView(model: model)
                .frame(minWidth: 860, minHeight: 540)
                .background(Palette.background)
                .onAppear { model.start() }
                .onOpenURL { _ in model.showMainWindow() }
        }
        .defaultSize(width: 980, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(L10n.appName) {
                Button(model.preferences.paused ? L10n.resume : L10n.pause) {
                    model.togglePause()
                }
                .keyboardShortcut("p", modifiers: [.command])
                Button(L10n.copySnapshot) {
                    model.copySnapshot()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                Button(L10n.resetPeaks) {
                    model.resetPeaks()
                }
            }
        }

        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}
