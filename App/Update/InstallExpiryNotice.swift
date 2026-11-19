import SwiftUI

struct InstallExpiryNotice: View {
    let title: String
    let text: String

    var body: some View {
        DSNotice(tone: .error, title: title, text: text)
    }
}
