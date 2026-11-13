import SwiftUI

struct IntroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsIcon = false
    @State private var pulseProgress: CGFloat = 0
    @State private var showsWordmark = false
    @State private var showsTagline = false

    private typealias C = BrandConstants

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: C.introSpacing) {
                AIIcon(size: C.introIconSize)
                    .scaleEffect(showsIcon ? 1 : C.introIconStartScale)
                    .opacity(showsIcon ? 1 : 0)
                PulseLine()
                    .trim(from: 0, to: pulseProgress)
                    .stroke(BrandColors.accentFill, style: StrokeStyle(lineWidth: C.introPulseLineWidth, lineCap: .round, lineJoin: .round))
                    .frame(width: C.introPulseWidth, height: C.introPulseHeight)
                Logo(showsTagline: false, showsIcon: false, fontSize: C.introWordmarkSize)
                    .opacity(showsWordmark ? 1 : 0)
                Text(C.tagline)
                    .font(.system(size: C.introTaglineSize))
                    .foregroundStyle(BrandColors.dim)
                    .opacity(showsTagline ? 1 : 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("trAIning")
        .onAppear(perform: start)
    }

    private func start() {
        guard !reduceMotion else {
            showsIcon = true
            pulseProgress = 1
            showsWordmark = true
            showsTagline = true
            return
        }
        withAnimation(.spring(duration: C.introIconSeconds, bounce: 0.3)) { showsIcon = true }
        withAnimation(.easeOut(duration: C.introPulseSeconds).delay(C.introPulseDelay)) { pulseProgress = 1 }
        withAnimation(.easeOut(duration: C.introTextSeconds).delay(C.introWordmarkDelay)) { showsWordmark = true }
        withAnimation(.easeOut(duration: C.introTextSeconds).delay(C.introTaglineDelay)) { showsTagline = true }
    }
}
