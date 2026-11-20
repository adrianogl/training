import Storage
import SwiftData
import SwiftUI
import TrainingCore

struct GoalEditorView: View {
    let goalId: UUID?
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft = GoalDraft()
    @State private var loaded = false
    @State private var error: String?
    @State private var confirmsDelete = false

    private typealias C = GoalsConstants

    private var goal: GoalRecord? {
        guard let goalId else { return nil }
        var descriptor = FetchDescriptor<GoalRecord>(predicate: #Predicate { $0.id == goalId })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    var body: some View {
        Form {
            if goalId == nil {
                Section {
                    Picker(C.kindLabel, selection: $draft.kind) {
                        ForEach(GoalKind.allCases, id: \.self) { kind in
                            Text(C.kindTitles[kind] ?? "").tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(C.kindHints[draft.kind] ?? "").font(.caption).foregroundStyle(BrandColors.dim)
                } header: {
                    DSSectionTitle(C.kindLabel)
                }
            }
            Section {
                switch draft.kind {
                case .time:
                    Picker(C.distanceLabel, selection: $draft.distanceKm) {
                        ForEach(C.distances, id: \.km) { item in Text(item.label).tag(item.km) }
                    }
                    Picker(C.targetLabel, selection: $draft.targetMode) {
                        ForEach(GoalTargetMode.allCases, id: \.self) { mode in Text(C.targetModeTitles[mode] ?? "").tag(mode) }
                    }
                    .pickerStyle(.segmented)
                    switch draft.targetMode {
                    case .time:
                        LabeledContent(C.timeLabel) {
                            TextField(C.timePlaceholder, text: $draft.time).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation)
                        }
                    case .pace:
                        LabeledContent(C.paceLabel) {
                            TextField(C.pacePlaceholder, text: $draft.targetPace).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation)
                        }
                    }
                    if let derived = GoalDraftParser.derived(draft) {
                        LabeledContent(draft.targetMode == .time ? C.derivedPaceLabel : C.derivedTimeLabel) {
                            Text(derived).fontWeight(.semibold).foregroundStyle(BrandColors.accent).monospacedDigit()
                        }
                    }
                    Toggle(C.hasDeadline, isOn: $draft.hasDeadline)
                    if draft.hasDeadline {
                        DatePicker(C.deadlineLabel, selection: $draft.deadline, in: Date.now..., displayedComponents: .date)
                    }
                case .continuousLong:
                    LabeledContent(C.longDistanceLabel) {
                        TextField(C.longDistancePlaceholder, text: $draft.longDistance).multilineTextAlignment(.trailing).keyboardType(.decimalPad)
                    }
                    LabeledContent(C.paceLabel) {
                        TextField(C.pacePlaceholder, text: $draft.pace).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation)
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(C.kindScopes[draft.kind] ?? "")
                    if draft.kind == .time { Text(C.derivedHints[draft.targetMode] ?? "") }
                    if let error { Text(error).foregroundStyle(BrandColors.danger) }
                }
            }
            Section {
                Button(C.save) { save() }.fontWeight(.semibold)
                if let goal {
                    Button(goal.archived ? C.unarchive : C.archive) { toggleArchive(goal) }
                    Button(C.delete, role: .destructive) { confirmsDelete = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrandBackground())
        .navigationTitle(goalId == nil ? C.editorTitleNew : C.editorTitleEdit)
        .confirmationDialog(C.deleteQuestion, isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button(C.delete, role: .destructive) { delete() }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            draft = GoalDraftParser.draft(goal)
        }
    }

    private func save() {
        switch GoalDraftParser.values(draft, today: Day.today()) {
        case .failure(let failure):
            error = GoalDraftParser.message(failure)
        case .success(let values):
            let now = Date.now
            let target = goal ?? {
                let created = GoalRecord(kind: values.kind, distanceKm: values.distanceKm, createdAt: now, updatedAt: now)
                context.insert(created)
                return created
            }()
            GoalDraftParser.apply(values, to: target, now: now)
            commit()
        }
    }

    private func toggleArchive(_ goal: GoalRecord) {
        goal.archived.toggle()
        goal.updatedAt = .now
        commit()
    }

    private func delete() {
        guard let goal else { return }
        let now = Date.now
        goal.deletedAt = now
        goal.updatedAt = now
        commit()
    }

    private func commit() {
        guard (try? context.save()) != nil else { return }
        app.remoteSync.scheduleSync()
        dismiss()
    }
}
