import SwiftUI

struct GarminZonesSection: View {
    @Bindable var model: GarminZonesModel
    let retry: () -> Void
    private typealias C = GarminZonesConstants

    var body: some View {
        Section {
            Toggle(C.toggle, isOn: $model.enabled)
            if let threshold = model.threshold {
                LabeledContent(C.threshold, value: String(format: C.bpmFormat, threshold))
                ForEach(model.ranges(), id: \.name) { zone in
                    LabeledContent(zone.name, value: zone.text)
                        .monospacedDigit()
                }
                if model.enabled {
                    if model.failed {
                        Button(action: retry) {
                            LabeledContent {
                                Text(C.retry)
                            } label: {
                                Text(C.failed).foregroundStyle(BrandColors.danger)
                            }
                        }
                        .disabled(model.isWorking)
                    } else {
                        LabeledContent(C.updated, value: model.updatedAt.map { $0.formatted(.relative(presentation: .named)) } ?? C.never)
                    }
                }
            } else {
                Text(C.noThreshold).foregroundStyle(BrandColors.dim)
            }
        } header: {
            DSSectionTitle(C.sectionTitle)
        } footer: {
            Text(C.note)
        }
    }
}
