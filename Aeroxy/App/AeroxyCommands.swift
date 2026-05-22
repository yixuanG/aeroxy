import SwiftUI

struct AeroxyCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open HTML...") {
                model.showOpenPanel()
            }
            .keyboardShortcut("o")

            Button("Close Tab") {
                model.closeSelectedTab()
            }
            .keyboardShortcut("w")
            .disabled(model.selectedTab == nil)

            Button("Print HTML...") {
                model.printSelectedTab()
            }
            .keyboardShortcut("p")
            .disabled(model.selectedTab == nil)

            Button("Export as PDF...") {
                model.exportSelectedTabAsPDF()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(model.selectedTab == nil)
        }

        CommandMenu("History") {
            if model.history.items.isEmpty {
                Text("No Recent Files")
            } else {
                ForEach(model.history.items) { item in
                    Button(item.displayName) {
                        model.openHistoryItem(item)
                    }
                }

                Divider()

                Button("Clear History") {
                    model.history.clear()
                }
            }
        }

        CommandMenu("Tabs") {
            Button("Previous Tab") {
                model.selectPreviousTab()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .disabled(model.tabs.count < 2)

            Button("Next Tab") {
                model.selectNextTab()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .disabled(model.tabs.count < 2)
        }
    }
}
