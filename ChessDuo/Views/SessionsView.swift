import SwiftUI

/// Every device signed in to this account, from `GET /auth/sessions`. Signing one out takes effect
/// immediately: its access tokens stop working and its refresh chain is revoked.
struct SessionsView: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.colorScheme) private var scheme
    @State private var pending: AccountDevice?
    @State private var confirmEverywhere = false

    var body: some View {
        List {
            if !account.devicesLoaded {
                HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
            } else if account.devices.isEmpty {
                Text(L10n.t("account.sessions.empty")).foregroundStyle(Duo.secondaryText(scheme))
            } else {
                Section {
                    ForEach(account.devices) { device in
                        DeviceRow(device: device)
                            .swipeActions {
                                Button(L10n.t("account.sessions.signOut"), role: .destructive) { pending = device }
                            }
                            .contextMenu {
                                Button(L10n.t("account.sessions.signOut"), role: .destructive) { pending = device }
                            }
                    }
                } footer: {
                    Text(L10n.t("account.sessions.footer"))
                }
            }
            if let failure = account.failure {
                AuthNotice(failure: failure).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            Section {
                Button(L10n.t("account.signOutEverywhere"), role: .destructive) { confirmEverywhere = true }
                    .disabled(account.isBusy)
                    .accessibilityIdentifier("sessions.signOutEverywhere")
            }
        }
        .scrollContentBackground(.hidden)
        .duoBackground()
        .navigationTitle(L10n.t("account.sessions"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await account.loadDevices() }
        .refreshable { await account.loadDevices() }
        .confirmationDialog(pending.map { $0.isCurrent ? L10n.t("account.sessions.signOutThis") : L10n.t("account.sessions.signOutOther", $0.deviceName) } ?? "",
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            Button(L10n.t("account.sessions.signOut"), role: .destructive) {
                if let device = pending { Task { await account.revoke(device) } }
                pending = nil
            }
            Button(L10n.t("cancel"), role: .cancel) { pending = nil }
        }
        .confirmationDialog(L10n.t("account.signOutEverywhere.confirm"), isPresented: $confirmEverywhere, titleVisibility: .visible) {
            Button(L10n.t("account.signOutEverywhere"), role: .destructive) { Task { await account.signOut(everywhere: true) } }
            Button(L10n.t("cancel"), role: .cancel) {}
        } message: { Text(L10n.t("account.signOutEverywhere.note")) }
    }
}

private struct DeviceRow: View {
    @Environment(\.colorScheme) private var scheme
    let device: AccountDevice

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: device.deviceName.contains("iPad") ? "ipad" : "iphone")
                .font(.title3).foregroundStyle(Duo.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.deviceName).font(.body.weight(.semibold))
                    if device.isCurrent {
                        Text(L10n.t("account.sessions.thisDevice"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Duo.mint.opacity(0.18), in: Capsule())
                            .foregroundStyle(Duo.mint)
                    }
                }
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(alignment: .leading, spacing: 2) {
                        if let last = device.lastRefreshAt {
                            Text(L10n.t("account.sessions.active", RelativeTime.label(for: last, now: context.date)))
                        }
                        if let signedIn = device.signedInAt {
                            Text(L10n.t("account.sessions.signedIn", signedIn.formatted(date: .abbreviated, time: .shortened)))
                        }
                        if let ip = device.ip { Text(ip) }
                    }
                }
                .font(.caption)
                .foregroundStyle(Duo.secondaryText(scheme))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(device.isCurrent ? "sessions.current" : "sessions.row")
    }
}
