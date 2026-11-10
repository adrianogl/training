import Storage
import SwiftUI
import TrainingCore
import UniformTypeIdentifiers

struct RaceEditorSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let raceId: UUID?
    @State private var model: RaceEditorModel?
    @State private var importsGPX = false
    @State private var confirmsDelete = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let model, model.isLoaded {
                    form(model)
                } else {
                    ProgressView()
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandBackground())
            .navigationTitle(raceId == nil ? RacesConstants.editorTitleNew : RacesConstants.editorTitleEdit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(RacesConstants.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(RacesConstants.save) { save() }
                        .disabled(model?.canSave != true)
                }
            }
        }
        .task {
            let loaded = RaceEditorModel(container: app.container, raceId: raceId, today: Day.today())
            await loaded.load()
            model = loaded
        }
    }

    private func form(_ model: RaceEditorModel) -> some View {
        @Bindable var model = model
        return Form {
            Section {
                TextField(RacesConstants.fieldName, text: $model.name)
                DatePicker(RacesConstants.fieldDate, selection: $model.date, displayedComponents: .date)
                Toggle(RacesConstants.fieldHasStart, isOn: $model.hasStartTime)
                if model.hasStartTime {
                    DatePicker(RacesConstants.fieldStart, selection: $model.startTime, displayedComponents: .hourAndMinute)
                }
                TextField(RacesConstants.fieldCity, text: $model.city)
            }
            Section(RacesConstants.fieldDistance) {
                Picker(RacesConstants.fieldDistance, selection: $model.distanceOption) {
                    ForEach(RaceDistanceOption.allCases) { option in
                        Text(RacesConstants.distanceTitles[option] ?? "").tag(option)
                    }
                }
                .pickerStyle(.segmented)
                if model.distanceOption == .other {
                    TextField(RacesConstants.fieldCustomKm, text: $model.customKm)
                        .keyboardType(.decimalPad)
                }
            }
            Section {
                TextField(RacesConstants.fieldGoal, text: $model.goalText)
                    .keyboardType(.numbersAndPunctuation)
                if let assessment = model.assessment {
                    Text(String(format: RacesConstants.targetPaceFormat, assessment.targetPaceText))
                        .font(.footnote)
                    if assessment.referenceSeconds > 0, let goal = model.goalSeconds {
                        Text(String(
                            format: RacesConstants.currentPredictionFormat,
                            TodayText.goalClock(assessment.referenceSeconds),
                            RacesText.signedClock(goal, minus: assessment.referenceSeconds) ?? ""
                        ))
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
                    }
                    Text(assessment.sentence)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(color(assessment))
                    if let compared = assessment.comparedText {
                        Text(compared)
                            .font(.caption2)
                            .foregroundStyle(BrandColors.dim)
                    }
                }
            }
            .task(id: model.evaluationKey) {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await model.evaluate()
            }
            Section(RacesConstants.fieldPriority) {
                Picker(RacesConstants.fieldPriority, selection: $model.priority) {
                    ForEach(RacePriority.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Button(model.gpxData == nil ? RacesConstants.gpxImport : RacesConstants.gpxReplace) { importsGPX = true }
                if let summary = model.gpxSummary {
                    Text(summary).font(.footnote).foregroundStyle(BrandColors.dim)
                    Button(RacesConstants.gpxRemove, role: .destructive) { model.removeGPX() }
                }
                if let error = model.gpxError {
                    Text(error).font(.footnote).foregroundStyle(BrandColors.danger)
                }
            }
            if let saveError {
                Text(saveError).foregroundStyle(BrandColors.danger)
            }
            if !model.isNew {
                Section {
                    Button(RacesConstants.delete, role: .destructive) { confirmsDelete = true }
                }
            }
        }
        .environment(\.locale, WorkoutConstants.locale)
        .fileImporter(isPresented: $importsGPX, allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml]) { result in
            if case .success(let url) = result { model.importGPX(from: url) }
        }
        .confirmationDialog(RacesConstants.deleteConfirm, isPresented: $confirmsDelete) {
            Button(RacesConstants.delete, role: .destructive) {
                try? model.delete()
                dismiss()
            }
        }
    }

    private func color(_ assessment: EditorAssessment) -> Color {
        switch assessment.level {
        case .easy: BrandColors.accent
        case .challenging: BrandColors.form
        case .aggressive: BrandColors.danger
        case nil: BrandColors.dim
        }
    }

    private func save() {
        do {
            try model?.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
