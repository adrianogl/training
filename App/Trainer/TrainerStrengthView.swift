import Insights
import SwiftUI

struct TrainerStrengthView: View {
    @Environment(AppModel.self) private var app
    @State private var editing: TrainerStrengthDraft?

    private var model: TrainerModel { app.trainer }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionLabel(TrainerText.strengthWeekTitle).padding(.vertical, 0)
                        Spacer()
                        Text(TrainerText.strengthSource).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    let rows = model.strengthRows()
                    if rows.isEmpty {
                        Text(TrainerText.strengthEmpty).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                    ForEach(rows) { row in
                        Button { editing = TrainerStrengthDraft(session: row.session, isNew: false) } label: {
                            sessionRow(row)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(TrainerText.strengthAdd) {
                        editing = TrainerStrengthDraft(session: newSession(), isNew: true)
                    }
                    .buttonStyle(TrainerSecondaryButtonStyle())
                }
                .brandCard()
                Text(TrainerText.strengthNote).font(.footnote).foregroundStyle(BrandColors.dim).padding(.horizontal, 2)
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(TrainerText.strengthTitle)
        .sheet(item: $editing) { draft in
            TrainerStrengthEditView(draft: draft) { save($0) }
        }
    }

    private func sessionRow(_ row: TrainerStrengthRow) -> some View {
        HStack(spacing: 10) {
            Text(TrainerText.weekdayName(row.session.weekday - 1))
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
                .frame(width: TrainerConstants.dayDateWidth, alignment: .leading)
            RoundedRectangle(cornerRadius: 3)
                .fill(BrandColors.strength)
                .frame(width: TrainerConstants.dayBarWidth)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.session.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(row.caption).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Spacer(minLength: 6)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func newSession() -> TrainerStrengthSession {
        let used = Set(model.plan?.strength.map(\.weekday) ?? [])
        let weekday = (1...TrainerConstants.weekdayCount).first { !used.contains($0) } ?? 1
        return TrainerStrengthSession(
            weekday: weekday, group: .fullBody, legLoad: TrainerConstants.defaultLoad(for: .fullBody),
            name: TrainerText.groupName(.fullBody)
        )
    }

    private func save(_ result: TrainerStrengthResult) {
        var sessions = model.plan?.strength ?? []
        switch result {
        case .save(let session):
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            } else {
                sessions.append(session)
            }
        case .remove(let id):
            sessions.removeAll { $0.id == id }
        }
        Task { await model.saveStrength(sessions) }
    }
}

struct TrainerStrengthEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: TrainerStrengthSession
    let isNew: Bool
    let onResult: (TrainerStrengthResult) -> Void

    init(draft: TrainerStrengthDraft, onResult: @escaping (TrainerStrengthResult) -> Void) {
        _session = State(initialValue: draft.session)
        isNew = draft.isNew
        self.onResult = onResult
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker(TrainerText.strengthDayLabel, selection: $session.weekday) {
                            ForEach(1...TrainerConstants.weekdayCount, id: \.self) { weekday in
                                Text(TrainerConstants.weekdayFull[weekday - 1].capitalized).tag(weekday)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(BrandColors.text)
                        Picker(TrainerText.strengthGroupLabel, selection: groupBinding) {
                            ForEach(TrainerConstants.strengthGroups, id: \.self) { group in
                                Text(TrainerText.groupName(group)).tag(group)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(BrandColors.text)
                        TextField(TrainerText.strengthNameLabel, text: $session.name)
                            .padding(10)
                            .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .brandCard()
                    Button(TrainerText.strengthSave) {
                        onResult(.save(session))
                        dismiss()
                    }
                    .buttonStyle(TrainerPrimaryButtonStyle())
                    .disabled(session.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !isNew {
                        Button(TrainerText.strengthRemove, role: .destructive) {
                            onResult(.remove(session.id))
                            dismiss()
                        }
                        .buttonStyle(TrainerSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(isNew ? TrainerText.strengthNewTitle : TrainerText.strengthEditTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TrainerText.cancel) { dismiss() } }
            }
        }
    }

    private var groupBinding: Binding<TrainerStrengthGroup> {
        Binding(
            get: { session.group },
            set: { group in
                let wasDefaultName = session.name == TrainerText.groupName(session.group)
                session.group = group
                session.legLoad = TrainerConstants.defaultLoad(for: group)
                if wasDefaultName { session.name = TrainerText.groupName(group) }
            }
        )
    }
}
