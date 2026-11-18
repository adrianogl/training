import SwiftUI

struct DeviceSettingsSection: View {
    @Bindable var model: AppModel

    var body: some View {
        Section {
            WatchKindPicker(selection: Binding(get: { model.watchKind ?? .garmin }, set: { model.chooseWatch($0) }))
                .dsCardRow()
        } footer: {
            Text(WatchKindConstants.settingsFooter)
        }
    }
}
