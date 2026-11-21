import GarminAPI
import Insights
import MFIT
import SwiftUI
import TrainingCore

struct TodayStrengthCard<Label: View>: View {
    @Environment(AppModel.self) private var app
    var showsLabel: Bool
    @ViewBuilder var label: () -> Label
    @State private var workout: StrengthWorkout?

    var body: some View {
        let today = Day.today()
        let mfit = app.trainer.replacesMFIT(on: today) ? nil : workout
        let planned = app.trainer.trainerSessions(on: today).first.flatMap { session in
            app.trainer.strengthWorkout(sessionId: session.id, day: today).map { (session: session, generated: $0) }
        }
        Group {
            if !app.trainer.strengthDone(on: today), mfit != nil || planned != nil {
                if showsLabel { label() }
                if let mfit { mfitCard(mfit) }
                if let planned { planCard(session: planned.session, generated: planned.generated, day: today) }
            }
        }
        .task(id: app.mfitAccount.revision) {
            await app.mfitAccount.adoptTeacherWithProgram()
            guard let client = app.mfitAccount.client else { workout = nil; return }
            let today = Day.today()
            let store = StrengthProgramStore()
            let schedule = StrengthSchedule()
            workout = schedule.workouts(store.load().program, from: today, through: today).first
            guard let fetched = try? await client.currentProgram(today: today.iso) as MFITProgram?? else { return }
            let cache = fetched.map(store.update(with:)) ?? store.clearProgram()
            workout = schedule.workouts(cache.program, from: today, through: today).first
        }
    }

    private func mfitCard(_ workout: StrengthWorkout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(TodayConstants.strengthTodayTitle)
                Spacer()
                TrainerStrengthSourceChip(source: .mfit)
            }
            Text(workout.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            Text(StrengthText.countLabel(exercises: workout.blocks.flatMap(\.exercises).count, sets: workout.totalSets))
                .font(.caption).foregroundStyle(BrandColors.dim)
            NavigationLink {
                StrengthPlannedDetailView(workoutId: workout.id)
            } label: {
                CardLinkFooter(title: CardLinkConstants.workout)
            }
            .buttonStyle(.cardLink)
            .padding(.top, 4)
        }
        .brandCard()
    }

    private func planCard(session: TrainerStrengthSession, generated: GeneratedStrengthWorkout, day: Day) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(TodayConstants.strengthTodayTitle)
                Spacer()
                if app.trainer.isFreeClaudeDay(day) {
                    ClaudeSourceChip()
                } else {
                    TrainerStrengthSourceChip(source: .trainer)
                }
            }
            Text(TrainerStrengthText.focusName(generated.group)).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            Text(TrainerStrengthText.meta(generated)).font(.caption).foregroundStyle(BrandColors.dim)
            if let adjustment = generated.adjustments.first {
                Text(TrainerStrengthText.adjustmentTitle(adjustment)).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention)
            }
            NavigationLink {
                TrainerStrengthWorkoutView(iso: day.iso, sessionId: session.id)
            } label: {
                CardLinkFooter(title: CardLinkConstants.workout)
            }
            .buttonStyle(.cardLink)
            .padding(.top, 4)
        }
        .brandCard()
    }
}
