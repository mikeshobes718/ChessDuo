import Foundation

@MainActor
enum SharedGameModel {
    static weak var shared: GameViewModel?
}
