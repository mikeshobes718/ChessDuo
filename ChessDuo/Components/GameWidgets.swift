import SwiftUI

/// Chooses 2D or 3D board based on the flag.
struct ChessBoardContainer: View {
    let position: Position
    let interaction: BoardInteraction
    var use3D: Bool
    var onTap: (Square) -> Void
    var onDrop: ((Square, Square) -> Void)? = nil
    @EnvironmentObject private var settings: AppSettings
    @State private var cameraMoved = false
    @State private var cameraResetToken = 0

    var body: some View {
        ZStack {
            if use3D {
                Board3DView(
                    position: position,
                    interaction: interaction,
                    cameraPreset: settings.cameraPreset,
                    onTap: onTap,
                    resetToken: cameraResetToken,
                    onCameraMovedChange: { moved in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { cameraMoved = moved }
                    }
                )
                    .aspectRatio(1, contentMode: .fit)
                    // SceneKit exposes every node to accessibility, which makes the tree huge and slow; the 2D board is the accessible one.
                    .accessibilityHidden(true)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black.opacity(0.08)))
                    .overlay(alignment: .topTrailing) { if cameraMoved { resetViewButton } }
                    .transition(.opacity)
            } else {
                BoardView2D(position: position, interaction: interaction, showCoordinates: settings.showCoordinates, onTap: onTap, onDrop: onDrop)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(settings.boardTheme.frame))
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: use3D)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board")
        .onChange(of: use3D) { _, isThreeD in
            // Going back to 2D and returning should start from the default angle again.
            if !isThreeD { cameraMoved = false; cameraResetToken += 1 }
        }
    }

    /// Appears only once the viewer has orbited or zoomed away from the default camera.
    private var resetViewButton: some View {
        Button {
            cameraResetToken += 1
            Feedback.shared.impact(.light)
        } label: {
            Label(L10n.t("game.resetView"), systemImage: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Duo.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(10)
        .transition(.scale.combined(with: .opacity))
        .accessibilityIdentifier("board.resetView")
    }
}

/// Player strip: name, captured pieces, material balance and clock.
struct PlayerBar: View {
    let name: String
    let color: PieceColor
    let captured: [PieceKind]
    let materialDiff: Int
    var clock: TimeInterval? = nil
    var clockRunning = false
    var isTurn = false
    var isThinking = false
    var subtitle: String? = nil
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color == .white ? Color(red: 0.96, green: 0.94, blue: 0.90) : Color(red: 0.14, green: 0.13, blue: 0.16))
                    .overlay(Circle().strokeBorder(isTurn ? Duo.accent : Duo.cardStroke(scheme), lineWidth: isTurn ? 3 : 1))
                Text(color == .white ? "♔" : "♚").font(.system(size: 20)).foregroundStyle(color == .white ? .black : .white)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if isThinking { ProgressView().controlSize(.mini) }
                }
                HStack(spacing: 1) {
                    ForEach(Array(captured.enumerated()), id: \.offset) { _, kind in
                        Text(Piece(color.opposite, kind).kind.unicodeBlack)
                            .font(.system(size: 13))
                            .foregroundStyle(color.opposite == .white ? Color.primary.opacity(0.55) : Color.primary)
                    }
                    if materialDiff > 0 {
                        Text("+\(materialDiff / 100)").font(.caption2.weight(.bold)).foregroundStyle(Duo.mint).padding(.leading, 3)
                    }
                    if let subtitle, captured.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(Duo.secondaryText(scheme))
                    }
                }
                .frame(height: 16)
            }
            Spacer()
            if let clock {
                Text(ChessClock.format(clock))
                    .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(clockRunning ? (clock < 20 ? Duo.danger : Duo.accent) : (scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(clockRunning ? .white : .primary)
                    .animation(.easeInOut(duration: 0.2), value: clockRunning)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(isTurn ? Duo.accent.opacity(0.6) : Duo.cardStroke(scheme), lineWidth: 1))
    }
}

struct ToastView: View {
    let toast: Toast
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.subheadline.weight(.bold))
            Text(toast.text).font(.subheadline.weight(.semibold)).lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(color, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .padding(.horizontal, 24)
    }
    private var color: Color {
        switch toast.style {
        case .info: return Duo.ink.opacity(0.92)
        case .success: return Duo.mint
        case .warning: return Duo.accentDeep
        case .error: return Duo.danger
        }
    }
    private var icon: String {
        switch toast.style {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct CoachCardView: View {
    let text: String
    var hint: String? = nil
    var onHistory: (() -> Void)? = nil
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "graduationcap.fill").font(.title3).foregroundStyle(Duo.accent).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                if let hint {
                    Text(hint).font(.subheadline.weight(.semibold)).foregroundStyle(Duo.mint)
                }
            }
            Spacer(minLength: 0)
            if let onHistory {
                Button(action: onHistory) { Image(systemName: "clock.arrow.circlepath").font(.subheadline) }.buttonStyle(.plain).foregroundStyle(Duo.secondaryText(scheme))
            }
        }
        .padding(12)
        .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
        .animation(.easeInOut(duration: 0.2), value: text)
    }
}

/// Horizontal scrolling move list with tap-to-jump.
struct MoveStrip: View {
    let moves: [MoveRecord]
    let viewingPly: Int?
    var qualities: [Int: MoveQuality] = [:]
    let onJump: (Int) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if moves.isEmpty {
                        Text(L10n.t("game.startHint")).font(.caption).foregroundStyle(Duo.secondaryText(scheme)).padding(.horizontal, 6)
                    }
                    ForEach(moves) { m in
                        HStack(spacing: 3) {
                            if m.color == .white { Text("\(m.moveNumber).").font(.caption.monospacedDigit()).foregroundStyle(Duo.secondaryText(scheme)) }
                            Button {
                                onJump(m.ply)
                            } label: {
                                HStack(spacing: 2) {
                                    Text(m.san).font(.subheadline.weight(.semibold).monospaced())
                                    if let q = qualities[m.ply], q != .good, q != .book { Text(q.symbol).font(.caption2.weight(.bold)).foregroundStyle(qualityColor(q)) }
                                    if m.assisted { Image(systemName: "cpu").font(.system(size: 9)) }
                                }
                                .padding(.horizontal, 7).padding(.vertical, 4)
                                .background((viewingPly ?? moves.count) == m.ply ? Duo.accent.opacity(0.3) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                        .id(m.ply)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 34)
            .accessibilityIdentifier("moveStrip")
            .accessibilityValue("\(moves.count)")
            .onChange(of: moves.count) { _, _ in
                if let last = moves.last { withAnimation { proxy.scrollTo(last.ply, anchor: .trailing) } }
            }
            .onChange(of: viewingPly) { _, ply in
                if let ply { withAnimation { proxy.scrollTo(ply, anchor: .center) } }
            }
        }
    }

    static func color(for q: MoveQuality) -> Color {
        switch q {
        case .book: return Duo.sky
        case .best: return Duo.mint
        case .good: return Duo.teal
        case .inaccuracy: return Duo.accent
        case .mistake: return .orange
        case .blunder: return Duo.danger
        }
    }
    private func qualityColor(_ q: MoveQuality) -> Color { Self.color(for: q) }
}

/// Small vertical eval bar (white advantage grows from the bottom).
struct EvalBar: View {
    let evalWhite: Int?
    var orientation: PieceColor = .white
    var body: some View {
        GeometryReader { geo in
            let fraction = fractionWhite
            ZStack(alignment: orientation == .white ? .bottom : .top) {
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.16, green: 0.15, blue: 0.18))
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.95, green: 0.94, blue: 0.90)).frame(height: geo.size.height * fraction)
            }
            .overlay(alignment: .center) {
                Text(label).font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(.gray).rotationEffect(.degrees(-90)).fixedSize()
            }
            .animation(.easeInOut(duration: 0.4), value: fraction)
        }
        .frame(width: 12)
    }
    private var fractionWhite: CGFloat {
        guard let e = evalWhite else { return 0.5 }
        if abs(e) > Search.mateScore - 1000 { return e > 0 ? 1 : 0 }
        let x = Double(e) / 100
        return CGFloat(1 / (1 + exp(-x * 0.55)))
    }
    private var label: String {
        guard let e = evalWhite else { return "" }
        if abs(e) > Search.mateScore - 1000 { return "M" }
        return String(format: "%+.1f", Double(e) / 100)
    }
}

struct PromotionSheet: View {
    let color: PieceColor
    let onPick: (PieceKind) -> Void
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        VStack(spacing: 16) {
            Text(L10n.t("game.promotion")).font(.title3.weight(.bold))
            HStack(spacing: 14) {
                ForEach([PieceKind.queen, .rook, .bishop, .knight], id: \.self) { kind in
                    Button { onPick(kind) } label: {
                        VStack(spacing: 6) {
                            PieceView(piece: Piece(color, kind), style: settings.pieceStyle, size: 56)
                                .padding(8)
                                .background(settings.darkSquare.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                            Text(L10n.t("game.promote.\(["queen", "rook", "bishop", "knight"][[PieceKind.queen, .rook, .bishop, .knight].firstIndex(of: kind)!])")).font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("promote.\(kind.letter)")
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = Duo.accent
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(Duo.secondaryText(scheme)).tracking(0.8)
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(value).font(.title3.weight(.bold).monospacedDigit())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Duo.cardStroke(scheme), lineWidth: 1))
    }
}

/// Shows a modal-like banner for offers (draw/undo) with accept/decline.
struct OfferBanner: View {
    let text: String
    let acceptTitle: String
    let declineTitle: String
    let onAccept: () -> Void
    let onDecline: () -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 10) {
            Text(text).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button(acceptTitle, action: onAccept).buttonStyle(DuoPrimaryButtonStyle(tint: Duo.mint))
                Button(declineTitle, action: onDecline).buttonStyle(DuoSecondaryButtonStyle())
            }
        }
        .padding(14)
        .background(Duo.card(scheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Duo.accent.opacity(0.6), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
