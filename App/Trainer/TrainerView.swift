import Insights
import SwiftUI
import TrainingCore

struct TrainerView: View {
    @Environment(AppModel.self) private var app
    @State private var showsNewPlan = false
    @State private var showsRequest = false
    @State private var confirmsDelete = false

    private var model: TrainerModel { app.trainer }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TrainerText.title).font(.largeTitle.weight(.bold)).foregroundStyle(BrandColors.text)
                    TrainerBetaBadge()
                }
                if let plan = model.plan {
                    planContent(plan)
                } else if model.isLoaded {
                    emptyState
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.plan != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(TrainerText.deleteMenu, role: .destructive) { confirmsDelete = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(TrainerText.deleteTitle, isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button(TrainerText.deleteConfirm, role: .destructive) { model.deletePlan() }
            Button(TrainerText.cancel, role: .cancel) {}
        } message: {
            Text(TrainerText.deleteMessage)
        }
        .navigationDestination(for: TrainerRoute.self) { route in
            switch route {
            case .day(let iso): TrainerDayView(iso: iso)
            case .changes: TrainerChangesView()
            case .strength: TrainerStrengthView()
            }
        }
        .sheet(isPresented: $showsNewPlan) { TrainerNewPlanView() }
        .sheet(isPresented: $showsRequest) { TrainerRequestView() }
        .task { await model.load() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TrainerText.emptyTitle).font(.headline).foregroundStyle(BrandColors.text)
            Text(TrainerText.emptyBody).font(.footnote).foregroundStyle(BrandColors.dim)
            Button(TrainerText.cardCreate) { showsNewPlan = true }
                .buttonStyle(TrainerPrimaryButtonStyle())
        }
        .brandCard()
    }

    @ViewBuilder
    private func planContent(_ plan: TrainerPlan) -> some View {
        goalCard(plan)
        if model.hasUnseenVersion, let version = model.latestVersion {
            NavigationLink(value: TrainerRoute.changes) {
                HStack(spacing: 8) {
                    Text("⟳").foregroundStyle(BrandColors.accent)
                    (Text(TrainerText.updatedBanner).fontWeight(.bold).foregroundStyle(BrandColors.accent)
                        + Text(" \(TrainerText.triggerText(version.trigger))").foregroundStyle(BrandColors.text))
                        .font(.footnote)
                    Spacer(minLength: 6)
                    Text(TrainerText.updatedAction).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(BrandColors.accentGlow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BrandColors.accent.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        strengthCard(plan)
        TrainerWeekStrip(cells: model.weekCells, weeksText: weeksText)
        SectionLabel(TrainerText.upcoming)
        ForEach(model.weekGroups) { group in
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(group.title).font(.caption.weight(.medium)).tracking(1).textCase(.uppercase).foregroundStyle(BrandColors.dim)
                    Spacer()
                    Text(group.caption).font(.caption).foregroundStyle(BrandColors.dim)
                }
                .padding(.horizontal, 2)
                ForEach(group.rows) { row in
                    NavigationLink(value: TrainerRoute.day(row.id)) {
                        TrainerDayRowView(row: row, isToday: row.workout.day == model.currentDay)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        Button { showsRequest = true } label: {
            Label(TrainerText.askButton, systemImage: "square.and.pencil")
        }
        .buttonStyle(TrainerSecondaryButtonStyle())
        .padding(.top, 6)
        if model.saveFailed {
            Text(TrainerText.saveError).font(.footnote).foregroundStyle(BrandColors.danger)
        }
    }

    private func strengthCard(_ plan: TrainerPlan) -> some View {
        NavigationLink(value: TrainerRoute.strength) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TrainerText.strengthTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Text(plan.strength.isEmpty ? TrainerText.strengthCardEmpty : TrainerText.strengthSummary(plan.strength))
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(BrandColors.dim)
            }
            .brandCard()
        }
        .buttonStyle(.plain)
    }

    private func goalCard(_ plan: TrainerPlan) -> some View {
        HStack(spacing: 10) {
            Text(TrainerText.goalGlyph(plan.target))
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(BrandColors.race)
                .frame(width: TrainerConstants.goalIconSize, height: TrainerConstants.goalIconSize)
                .background(BrandColors.raceGlow, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(TrainerText.targetTitle(plan.target)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(TrainerText.goalCaption(plan: plan, weeks: model.weeksToTarget)).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Spacer(minLength: 0)
        }
        .brandCard()
    }

    private var weeksText: String {
        guard let index = model.currentWeekIndex, let total = model.plan?.weeks.count else { return "" }
        return "semana \(index) de \(total)"
    }
}

struct TrainerPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(BrandColors.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct TrainerSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(BrandColors.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(BrandColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BrandColors.cardBorder, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
