import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: GameViewModel

    var body: some View {
        Group {
            if model.session == nil {
                LobbyView()
            } else {
                GameView()
            }
        }
#if DEBUG
        .onAppear(perform: applyVisualPreviewIfNeeded)
#endif
    }

#if DEBUG
    private func applyVisualPreviewIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-previewWaiting") {
            model.loadVisualPreview("waiting")
        } else if args.contains("-previewPlaying") {
            model.loadVisualPreview("playing")
        } else if args.contains("-previewReview") {
            model.loadVisualPreview("review")
        } else if args.contains("-previewPromotion") {
            model.loadVisualPreview("promotion")
        } else if args.contains("-previewTurnAlert") {
            model.loadVisualPreview("turnalert")
        }
    }
#endif
}
