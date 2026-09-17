import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    let onResume: (GameRecord) -> Void
    @State private var filter = 0
    @State private var selected: GameRecord?
    @State private var shareItems: [Any]?
    @State private var reviewing: GameRecord?
    @State private var reviewProgress: Double = 0
    @State private var reviewedRecord: GameRecord?
    @State private var showClear = false
    @State private var onlineArchives: [OnlineArchive] = []
    private let engine = ChessEngine()

    private var filtered: [GameRecord] {
        history.records.filter { r in
            switch filter {
            case 1: return r.result?.winner != nil && r.result?.winner == r.humanColor
            case 2: return r.result?.winner != nil && r.humanColor != nil && r.result?.winner != r.humanColor
            case 3: return r.result != nil && r.result?.winner == nil
            default: return true
            }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $filter) {
                    Text(L10n.t("history.filter.all")).tag(0)
                    Text(L10n.t("history.filter.wins")).tag(1)
                    Text(L10n.t("history.filter.losses")).tag(2)
                    Text(L10n.t("history.filter.draws")).tag(3)
                }.pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if filtered.isEmpty {
                Text(L10n.t("history.empty")).foregroundStyle(.secondary).listRowBackground(Color.clear)
            }
            ForEach(filtered) { record in
                Button { selected = record } label: { row(record) }
                    .swipeActions {
                        Button(role: .destructive) { history.delete(record) } label: { Label(L10n.t("delete"), systemImage: "trash") }
                        Button { shareItems = [record.pgn] } label: { Label(L10n.t("game.share"), systemImage: "square.and.arrow.up") }.tint(Duo.sky)
                    }
                    .listRowBackground(Duo.card(scheme))
            }
        }
        .scrollContentBackground(.hidden)
        .duoBackground()
        .navigationTitle(L10n.t("history.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !history.records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { Button(role: .destructive) { showClear = true } label: { Image(systemName: "trash") } }
            }
        }
        .alert(L10n.t("settings.clearHistory.confirm"), isPresented: $showClear) {
            Button(L10n.t("cancel"), role: .cancel) {}
            Button(L10n.t("delete"), role: .destructive) { history.deleteAll() }
        }
        .sheet(item: $selected) { record in detail(record) }
        .sheet(item: $reviewedRecord) { record in
            if let review = record.review { ReviewView(record: record, review: review) }
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) { if let items = shareItems { ShareSheet(items: items) } }
    }

    private func row(_ record: GameRecord) -> some View {
        HStack(spacing: 12) {
            MiniBoard(fen: record.moves.last?.fenAfter ?? record.startFEN, orientation: record.humanColor ?? .white).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(record.whiteName) \(L10n.t("history.vs")) \(record.blackName)").font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(record.resultText).font(.caption).foregroundStyle(resultColor(record)).lineLimit(2)
                HStack(spacing: 6) {
                    Text(record.mode.title).font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.secondary.opacity(0.15), in: Capsule())
                    Text(L10n.t("over.moves", record.moveCount)).font(.caption2).foregroundStyle(.secondary)
                    Text(record.startedAt, style: .date).font(.caption2).foregroundStyle(.secondary)
                    if let r = record.review, let me = record.humanColor {
                        Text("\(me == .white ? r.white.accuracy : r.black.accuracy)%").font(.caption2.weight(.bold)).foregroundStyle(GameOverSheet.accuracyColor(me == .white ? r.white.accuracy : r.black.accuracy))
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func resultColor(_ r: GameRecord) -> Color {
        guard let result = r.result else { return Duo.accent }
        guard let me = r.humanColor else { return .secondary }
        if result.winner == me { return Duo.mint }
        if result.winner == nil { return .secondary }
        return Duo.danger
    }

    private func detail(_ record: GameRecord) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ReplayBoard(record: record)
                    Text(record.resultText).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        if !record.isFinished && (record.mode == .local || record.mode == .computer) {
                            Button(L10n.t("home.resume")) { selected = nil; onResume(record) }.buttonStyle(DuoPrimaryButtonStyle(tint: Duo.mint))
                        }
                        if let review = record.review {
                            Button { selected = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { reviewedRecord = record } } label: { Label(L10n.t("game.review"), systemImage: "chart.line.uptrend.xyaxis") }.buttonStyle(DuoPrimaryButtonStyle())
                            let _ = review
                        } else if !record.moves.isEmpty {
                            Button {
                                reviewing = record
                                Task {
                                    let summary = await Reviewer.review(record: record, engine: engine, progress: { p in Task { @MainActor in reviewProgress = p } })
                                    var updated = record
                                    updated.review = summary
                                    history.upsert(updated)
                                    reviewing = nil
                                    selected = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { reviewedRecord = updated }
                                }
                            } label: {
                                if reviewing?.id == record.id { ProgressView(value: reviewProgress).tint(.white).padding(.horizontal) } else { Label(L10n.t("game.review"), systemImage: "chart.line.uptrend.xyaxis") }
                            }.buttonStyle(DuoPrimaryButtonStyle()).disabled(reviewing != nil)
                        }
                        NavigationLink { AnalysisView(record: record) } label: { Label(L10n.t("home.analysis"), systemImage: "magnifyingglass") }.buttonStyle(DuoSecondaryButtonStyle())
                        HStack {
                            Button { shareItems = [record.pgn] } label: { Label(L10n.t("game.sharePGN"), systemImage: "square.and.arrow.up") }.buttonStyle(DuoSecondaryButtonStyle())
                            Button { UIPasteboard.general.string = record.pgn } label: { Label(L10n.t("game.copyPGN"), systemImage: "doc.on.doc") }.buttonStyle(DuoSecondaryButtonStyle())
                        }
                        Button(role: .destructive) { history.delete(record); selected = nil } label: { Label(L10n.t("delete"), systemImage: "trash") }.buttonStyle(DuoSecondaryButtonStyle())
                    }
                    .padding(.horizontal)
                    Text(record.game.pgnMoveText).font(.caption.monospaced()).foregroundStyle(.secondary).padding().frame(maxWidth: .infinity, alignment: .leading).duoCard(padding: 0).padding(.horizontal)
                }
                .padding(.vertical)
            }
            .duoBackground()
            .navigationTitle("\(record.whiteName) \(L10n.t("history.vs")) \(record.blackName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.t("close")) { selected = nil } } }
        }
    }
}

/// Auto/manual replay of a saved game.
struct ReplayBoard: View {
    let record: GameRecord
    @State private var ply: Int
    @State private var playing = false
    @State private var use3D = false
    @EnvironmentObject private var settings: AppSettings

    init(record: GameRecord) {
        self.record = record
        _ply = State(initialValue: record.moves.count)
    }

    private var position: Position { record.game.position(atPly: ply) }
    private var interaction: BoardInteraction {
        var i = BoardInteraction()
        i.orientation = record.humanColor ?? .white
        i.interactive = false
        if ply > 0 { let m = record.moves[ply - 1].move; i.lastMove = (m.from, m.to) }
        i.checkSquare = position.isInCheck ? position.king(of: position.sideToMove) : nil
        return i
    }

    var body: some View {
        VStack(spacing: 10) {
            ChessBoardContainer(position: position, interaction: interaction, use3D: use3D, onTap: { _ in }).padding(.horizontal, 12)
            HStack(spacing: 10) {
                Button { ply = 0 } label: { Image(systemName: "backward.end.fill") }.buttonStyle(DuoIconButtonStyle())
                Button { ply = max(0, ply - 1); Feedback.shared.selectionChanged() } label: { Image(systemName: "chevron.left") }.buttonStyle(DuoIconButtonStyle())
                Button { playing.toggle(); if playing && ply >= record.moves.count { ply = 0 } } label: { Image(systemName: playing ? "pause.fill" : "play.fill") }.buttonStyle(DuoIconButtonStyle(active: playing)).accessibilityIdentifier("replay.play")
                Button { ply = min(record.moves.count, ply + 1); Feedback.shared.selectionChanged() } label: { Image(systemName: "chevron.right") }.buttonStyle(DuoIconButtonStyle())
                Button { ply = record.moves.count } label: { Image(systemName: "forward.end.fill") }.buttonStyle(DuoIconButtonStyle())
                Button { use3D.toggle() } label: { Text(use3D ? "2D" : "3D").font(.caption.weight(.bold)) }.buttonStyle(DuoIconButtonStyle(active: use3D))
            }
            MoveStrip(moves: record.moves, viewingPly: ply, qualities: Dictionary(uniqueKeysWithValues: (record.review?.moves ?? []).map { ($0.ply, $0.quality) })) { ply = $0 }.duoCard(padding: 4).padding(.horizontal, 12)
        }
        .task(id: playing) {
            guard playing else { return }
            while playing && ply < record.moves.count {
                try? await Task.sleep(nanoseconds: 900_000_000)
                if Task.isCancelled { return }
                ply += 1
                Feedback.shared.play(.move)
            }
            playing = false
        }
    }
}
