import EventKit
import SwiftUI
import UIKit

struct WatchCalendarRow: View {
    private typealias C = WatchCalendarConstants
    @State private var status = WatchCalendar.status

    var body: some View {
        switch status {
        case .fullAccess:
            LabeledContent(C.rowTitle, value: C.rowOn)
        case .notDetermined:
            Button(C.rowEnable) {
                Task {
                    _ = await WatchCalendar.requestAccess()
                    status = WatchCalendar.status
                }
            }
        default:
            Button(C.rowDenied) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }
    }
}
