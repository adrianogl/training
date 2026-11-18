import SwiftUI

struct ClaudeSourceChip: View {
    var body: some View {
        DSChip(text: DSAIMarkConstants.symbol + " " + ClaudeText.source, tone: .claude)
    }
}
