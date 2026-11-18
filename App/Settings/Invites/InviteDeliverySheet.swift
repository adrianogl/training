import RemoteSync
import SwiftUI
import UIKit

struct InviteDeliverySheet: View {
    let delivery: InviteDelivery
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private typealias C = InvitesConstants

    var body: some View {
        NavigationStack {
            Form {
                if delivery.mailed, let email = delivery.invite.email {
                    Section { Text(String(format: C.mailedFormat, email)) }
                } else {
                    Section {
                        Text(delivery.message).textSelection(.enabled)
                    } footer: {
                        Text(copied ? C.copied : C.shareText)
                    }
                    Section {
                        ShareLink(item: delivery.message) { Label(C.share, systemImage: "square.and.arrow.up") }
                        Button(C.copy) {
                            UIPasteboard.general.string = delivery.message
                            copied = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandBackground())
            .navigationTitle(C.shareTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(C.done) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
