import SwiftUI

struct DeviceSettingsSection: View {
    @Bindable var model: AppModel

    var body: some View {
        Section {
            WatchKindPicker(selection: Binding(get: { model.watchKind ?? .garmin }, set: { model.chooseWatch($0) }))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } footer: {
            Text(WatchKindConstants.settingsFooter)
        }
    }
}
