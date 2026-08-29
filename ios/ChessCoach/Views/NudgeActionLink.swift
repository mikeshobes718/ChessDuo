// Nudge text action under the waiting pill, matched to Flo partner pairing
// https://mobbin.com/screens/00e033f2-fd01-4841-be97-ca1d9c7e69fc
// Cooldown copy follows Paired https://mobbin.com/screens/95b9bb85-b1cc-4518-8f5a-35d079f0e5c5

import SwiftUI

struct NudgeActionLink: View {
    @ObservedObject var controller: NudgeController
    let action: () -> Void

    var body: some View {
        if controller.isVisible {
            Button(action: action) {
                Text(controller.titleText)
                    .font(controller.isEnabled ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(controller.isEnabled ? DuoAccent.ink : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
            }
            .buttonStyle(.plain)
            .disabled(!controller.isEnabled)
            .accessibilityLabel(controller.titleText)
        }
    }
}
