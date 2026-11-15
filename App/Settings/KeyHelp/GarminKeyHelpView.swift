import SwiftUI

private typealias C = GarminKeyHelpConstants

struct GarminKeyHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                GarminKeyHelpContent()
                    .padding(BrandConstants.screenPadding)
            }
            .background(BrandBackground())
            .navigationTitle(C.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(C.done) { dismiss() } }
            }
        }
    }
}

struct GarminKeyHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.title3)
                    .foregroundStyle(BrandColors.onAccent)
                    .frame(width: 40, height: 40)
                    .background(BrandColors.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(C.intro).font(.subheadline).foregroundStyle(BrandColors.text)
            }
            VStack(alignment: .leading, spacing: 16) {
                ForEach(C.steps) { step in stepRow(step) }
            }
            Text(C.caption).font(.caption2).foregroundStyle(BrandColors.dim)
            Link(destination: AppConstants.createKeyURL) {
                Label(C.openButton, systemImage: "arrow.up.forward.app")
                    .font(.headline)
                    .foregroundStyle(BrandColors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BrandColors.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(C.facts, id: \.self) { fact in
                    Label {
                        Text(fact).font(.footnote).foregroundStyle(BrandColors.text)
                    } icon: {
                        Image(systemName: "checkmark").foregroundStyle(BrandColors.accent)
                    }
                }
            }
            .brandCard()
        }
    }

    private func stepRow(_ step: GarminKeyHelpStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(step.number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(BrandColors.accent)
                .frame(width: C.numberSize, height: C.numberSize)
                .background(BrandColors.accentGlow, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(step.detail).font(.footnote).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                GarminKeyHelpIllustrationView(illustration: step.illustration).padding(.top, 4)
            }
        }
    }
}
