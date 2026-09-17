import SwiftUI

struct AnalysisView: View {
    @StateObject private var session: AnalysisSession
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @State private var showFENInput = false
    @State private var fenInput = ""
    @State private var showPGNInput = false
    @State private var pgnInput = ""
    @State private var playFromHere: GameSession?
    @State private var shareItems: [Any]?

    init(fen: String = Position.startFEN) { _session = StateObject(wrappedValue: AnalysisSession(fen: fen)) }
    init(record: GameRecord) { _session = StateObject(wrappedValue: AnalysisSession(record: record)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    EvalBar(evalWhite: session.evalWhite, orientation: session.orientation).frame(height: 320)
                    ChessBoardContainer(position: session.position, interaction: session.interaction, use3D: session.use3D, onTap: { session.tap($0) }, onDrop: { session.drop(from: $0, to: $1) })
                }
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Toggle(isOn: $session.engineOn) { Text(L10n.t("analysis.engineOn")).font(.subheadline.weight(.semibold)) }.toggleStyle(.switch).labelsHidden()
                            Text(L10n.t("analysis.engineOn")).font(.subheadline.weight(.semibold))
                            if session.engineOn {
                                if let m = session.mateIn { Text(L10n.t("game.mateIn", abs(m))).font(.subheadline.weight(.bold)).foregroundStyle(Duo.rose) }
                                else if let e = session.evalWhite { Text(String(format: "%+.2f", Double(e) / 100)).font(.subheadline.weight(.bold).monospacedDigit()) }
                                Text(L10n.t("analysis.depth", session.depth)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if !session.bestLine.isEmpty { Text(session.bestLine.joined(separator: " ")).font(.caption.monospaced()).foregroundStyle(Duo.secondaryText(scheme)).lineLimit(2) }
                    }
                    Spacer()
                }
                .duoCard(padding: 12)
                .onChange(of: session.engineOn) { _, _ in session.analyze() }

                if session.isEditing { palette }

                HStack(spacing: 8) {
                    Button { session.step(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(DuoIconButtonStyle()).accessibilityIdentifier("analysis.back")
                    Button { session.step(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(DuoIconButtonStyle()).accessibilityIdentifier("analysis.forward")
                    Button { session.undo() } label: { Image(systemName: "arrow.uturn.backward") }.buttonStyle(DuoIconButtonStyle()).disabled(session.game.history.isEmpty).accessibilityIdentifier("analysis.undo")
                    Button { session.flipped.toggle(); session.refreshInteraction() } label: { Image(systemName: "arrow.up.arrow.down") }.buttonStyle(DuoIconButtonStyle()).accessibilityIdentifier("analysis.flip")
                    Button { session.use3D.toggle() } label: { Text(session.use3D ? "2D" : "3D").font(.caption.weight(.bold)) }.buttonStyle(DuoIconButtonStyle(active: session.use3D)).accessibilityIdentifier("analysis.3d")
                    Button { session.isEditing.toggle(); session.refreshInteraction() } label: { Image(systemName: "pencil") }.buttonStyle(DuoIconButtonStyle(active: session.isEditing)).accessibilityIdentifier("analysis.edit")
                    Spacer()
                    Menu {
                        Button { session.reset() } label: { Label(L10n.t("analysis.startPos"), systemImage: "arrow.counterclockwise") }
                        Button { session.clearBoard() } label: { Label(L10n.t("analysis.clear"), systemImage: "trash") }
                        Button { session.setSideToMove(.white) } label: { Label("\(L10n.t("analysis.sideToMove")): \(L10n.t("game.white"))", systemImage: "circle") }
                        Button { session.setSideToMove(.black) } label: { Label("\(L10n.t("analysis.sideToMove")): \(L10n.t("game.black"))", systemImage: "circle.fill") }
                        Divider()
                        Button { fenInput = UIPasteboard.general.string ?? ""; showFENInput = true } label: { Label(L10n.t("analysis.pasteFEN"), systemImage: "doc.on.clipboard") }
                        Button { pgnInput = UIPasteboard.general.string ?? ""; showPGNInput = true } label: { Label(L10n.t("analysis.pastePGN"), systemImage: "doc.on.clipboard") }
                        Button { UIPasteboard.general.string = session.fen; session.presentToast(L10n.t("game.copied"), style: .success) } label: { Label(L10n.t("game.copyFEN"), systemImage: "doc.on.doc") }
                        Button { shareItems = [session.pgn] } label: { Label(L10n.t("game.sharePGN"), systemImage: "square.and.arrow.up") }
                    } label: { Image(systemName: "ellipsis.circle") }.buttonStyle(DuoIconButtonStyle()).accessibilityIdentifier("analysis.menu")
                }
                MoveStrip(moves: session.game.history, viewingPly: session.viewingPly) { ply in session.viewingPly = ply >= session.game.history.count ? nil : ply; session.refreshInteraction(); session.analyze() }.duoCard(padding: 4)
                Button {
                    let me = settings.displayName
                    let cpu = "\(L10n.t("game.computer")) · \(L10n.t("computer.level\(settings.computerLevel.rawValue)"))"
                    let human = session.position.sideToMove
                    playFromHere = GameSession(kind: .computer(settings.computerLevel, human: human), whiteName: human == .white ? me : cpu, blackName: human == .white ? cpu : me, timeControl: .none, fen: session.position.fen)
                } label: { Label(L10n.t("analysis.play"), systemImage: "play.fill") }
                .buttonStyle(DuoPrimaryButtonStyle())
                .disabled(session.position.legalMoves().isEmpty)
                Text(session.fen).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
            }
            .padding()
        }
        .duoBackground()
        .navigationTitle(L10n.t("analysis.title"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) { if let t = session.toast { ToastView(toast: t).padding(.top, 8) } }
        .alert(L10n.t("analysis.pasteFEN"), isPresented: $showFENInput) {
            TextField("FEN", text: $fenInput)
            Button(L10n.t("ok")) { if !session.loadFEN(fenInput) { session.presentToast(L10n.t("analysis.invalidFEN"), style: .error) } }
            Button(L10n.t("cancel"), role: .cancel) {}
        }
        .alert(L10n.t("analysis.pastePGN"), isPresented: $showPGNInput) {
            TextField("PGN", text: $pgnInput)
            Button(L10n.t("ok")) { if !session.loadPGN(pgnInput) { session.presentToast(L10n.t("analysis.invalidFEN"), style: .error) } }
            Button(L10n.t("cancel"), role: .cancel) {}
        }
        .sheet(item: $session.pendingPromotion) { p in PromotionSheet(color: p.color) { session.completePromotion($0) } }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) { if let items = shareItems { ShareSheet(items: items) } }
        .fullScreenCover(item: $playFromHere) { s in LocalGameView(session: s) { playFromHere = nil }.environmentObject(settings) }
    }

    private var palette: some View {
        VStack(spacing: 6) {
            Text(L10n.t("analysis.editing", session.editPiece.map { L10n.pieceName($0.kind) } ?? L10n.t("analysis.erase"))).font(.caption).foregroundStyle(.secondary)
            ForEach([PieceColor.white, .black], id: \.self) { color in
                HStack(spacing: 6) {
                    ForEach([PieceKind.king, .queen, .rook, .bishop, .knight, .pawn], id: \.self) { kind in
                        let piece = Piece(color, kind)
                        Button { session.editPiece = piece } label: {
                            PieceView(piece: piece, style: settings.pieceStyle, size: 34).padding(4)
                                .background(session.editPiece == piece ? Duo.accent.opacity(0.4) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).accessibilityIdentifier("palette.\(piece.fenChar)")
                    }
                    if color == .black {
                        Button { session.editPiece = nil } label: {
                            Image(systemName: "eraser.fill").frame(width: 34, height: 34).padding(4)
                                .background(session.editPiece == nil ? Duo.accent.opacity(0.4) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .duoCard(padding: 10)
    }
}
