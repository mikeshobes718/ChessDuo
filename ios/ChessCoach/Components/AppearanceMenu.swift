// Board colors matched to Hinge settings https://mobbin.com/screens/fd70e2d2-81d3-4808-8d4b-efc87e0e6662

import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: return L10n.t(.appearanceSystem)
        case .light: return L10n.t(.appearanceLight)
        case .dark: return L10n.t(.appearanceDark)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct BoardColorSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("boardTheme") private var boardTheme = BoardTheme.classic.rawValue
    @AppStorage("customLightHex") private var customLightHex = "EDE3C7"
    @AppStorage("customDarkHex") private var customDarkHex = "73915E"

    @State private var light = Color(red: 0.93, green: 0.89, blue: 0.78)
    @State private var dark = Color(red: 0.45, green: 0.57, blue: 0.37)

    var body: some View {
        NavigationStack {
            ZStack {
                DuoBackground()
                Form {
                    Section {
                        ForEach(BoardTheme.allCases.filter { $0 != .custom }) { theme in
                            Button {
                                boardTheme = theme.rawValue
                            } label: {
                                HStack {
                                    themeSwatch(theme)
                                    Text(theme.title)
                                    Spacer()
                                    if boardTheme == theme.rawValue {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(DuoAccent.base)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("PRESETS")
                    }

                    Section {
                        ColorPicker("Light squares", selection: $light, supportsOpacity: false)
                        ColorPicker("Dark squares", selection: $dark, supportsOpacity: false)
                        Button(L10n.t(.useCustomColors)) {
                            customLightHex = light.hexRGB
                            customDarkHex = dark.hexRGB
                            boardTheme = BoardTheme.custom.rawValue
                        }
                    } header: {
                        Text("CUSTOM SQUARES")
                    }

                    Section {
                        HStack(spacing: 0) {
                            Rectangle().fill(previewLight)
                            Rectangle().fill(previewDark)
                            Rectangle().fill(previewLight)
                            Rectangle().fill(previewDark)
                        }
                        .frame(height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(L10n.t(.piecesStandardized))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .tint(DuoAccent.base)
            }
            .navigationTitle(L10n.t(.boardColorsTitle))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.done)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                light = Color(hexRGB: customLightHex) ?? light
                dark = Color(hexRGB: customDarkHex) ?? dark
            }
        }
    }

    private var previewLight: Color {
        boardTheme == BoardTheme.custom.rawValue
            ? light
            : (BoardTheme(rawValue: boardTheme) ?? .classic).lightSquare(custom: .default)
    }

    private var previewDark: Color {
        boardTheme == BoardTheme.custom.rawValue
            ? dark
            : (BoardTheme(rawValue: boardTheme) ?? .classic).darkSquare(custom: .default)
    }

    private func themeSwatch(_ theme: BoardTheme) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(theme.lightSquare(custom: .default))
            Rectangle().fill(theme.darkSquare(custom: .default))
        }
        .frame(width: 36, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

extension Color {
    var hexRGB: String {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }

    init?(hexRGB: String) {
        let cleaned = hexRGB.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
