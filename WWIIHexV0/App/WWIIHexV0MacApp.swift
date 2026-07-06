#if os(macOS)
import SwiftUI

@main
struct WWIIHexV0MacApp: App {
    @StateObject private var container = AppContainer.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootGameView(container: container)
                .frame(minWidth: 1200, minHeight: 760)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandMenu(commandMenuTitle) {
                Button(endOrdersTitle, action: container.advanceOrRunAI)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!container.canAdvanceOrders)

                Button(newCampaignTitle, action: container.resetGame)
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }

    private var usesNapoleonicVocabulary: Bool {
        container.gameState.activeFaction.usesNapoleonicLogisticsVocabulary
    }

    private var commandMenuTitle: String {
        usesNapoleonicVocabulary ? "Orders" : "Game"
    }

    private var endOrdersTitle: String {
        usesNapoleonicVocabulary ? "End Orders" : "End Turn"
    }

    private var newCampaignTitle: String {
        usesNapoleonicVocabulary ? "New Campaign" : "New Game"
    }
}
#endif
