import SwiftUI

private typealias C = GarminKeyHelpConstants

struct GarminKeyHelpIllustrationView: View {
    let illustration: GarminKeyHelpIllustration

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if illustration == .openPage { browserBar }
            content.padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(illustration == .pasteInApp ? BrandColors.card : C.paper, in: RoundedRectangle(cornerRadius: C.illustrationRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: C.illustrationRadius, style: .continuous).strokeBorder(BrandColors.line, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var browserBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in Circle().fill(BrandColors.dim.opacity(0.4)).frame(width: 6, height: 6) }
            Text(C.host)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(C.field, in: Capsule())
                .padding(.leading, 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.field)
    }

    @ViewBuilder
    private var content: some View {
        switch illustration {
        case .openPage:
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(C.settingsTitle).font(.caption2).foregroundStyle(BrandColors.dim)
                    Text(C.pageTitle).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.text)
                }
                Spacer(minLength: 8)
                pageButton(C.createKey, filled: true, tapped: true)
            }
        case .chooseExpiry:
            VStack(alignment: .leading, spacing: 6) {
                Text(C.createTitle).font(.caption.weight(.bold)).foregroundStyle(BrandColors.text)
                Text(C.expiryLabel).font(.caption2).foregroundStyle(BrandColors.dim)
                HStack {
                    Text("\(C.expiryValue) ▾")
                        .font(.caption)
                        .foregroundStyle(BrandColors.text)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(C.field, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(alignment: .bottomTrailing) { tapMark }
                    Spacer(minLength: 8)
                    pageButton(C.create, filled: true, tapped: false)
                }
            }
        case .acceptTerms:
            VStack(alignment: .leading, spacing: 6) {
                Text(C.termsTitle).font(.caption.weight(.bold)).foregroundStyle(BrandColors.text)
                placeholderLine(0.7)
                placeholderLine(0.45)
                HStack(spacing: 8) {
                    Spacer()
                    pageButton(C.reject, filled: false, tapped: false)
                    pageButton(C.accept, filled: true, tapped: true)
                }
            }
        case .copyKey:
            HStack {
                Text(C.maskedKey).font(.caption.monospaced()).foregroundStyle(BrandColors.text)
                Spacer(minLength: 8)
                pageButton(C.copy, filled: false, tapped: true)
            }
        case .pasteInApp:
            VStack(alignment: .leading, spacing: 8) {
                Text(C.pastedKey)
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(C.field, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                HStack {
                    Text(C.saveKey).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                        .padding(.trailing, 8)
                        .overlay(alignment: .bottomTrailing) { tapMark }
                    Spacer()
                    Text(C.testConnection).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                }
            }
        }
    }

    private func pageButton(_ title: String, filled: Bool, tapped: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(filled ? Color.white : BrandColors.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? C.pageBlue : C.field, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: .bottomTrailing) { if tapped { tapMark } }
    }

    private func placeholderLine(_ share: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule().fill(C.field).frame(width: proxy.size.width * share, height: 6)
        }
        .frame(height: 6)
    }

    private var tapMark: some View {
        Circle()
            .fill(BrandColors.accent.opacity(0.35))
            .overlay(Circle().strokeBorder(BrandColors.accent, lineWidth: 2))
            .frame(width: C.tapSize, height: C.tapSize)
            .offset(x: 5, y: 7)
    }
}
