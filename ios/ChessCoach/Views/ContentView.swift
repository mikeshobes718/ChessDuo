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
    }
}
