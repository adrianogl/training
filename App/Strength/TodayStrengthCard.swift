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
        NavigationLink {
            StrengthPlannedDetailView(workoutId: workout.id)
        } label: {
            StrengthDayCard(model: StrengthPlanDraftLogic.mfitDayCard(
                title: workout.title, exercises: workout.blocks.flatMap(\.exercises).count, sets: workout.totalSets
            ))
        }
        .buttonStyle(.cardLink)
    }

    private func planCard(session: TrainerStrengthSession, generated: GeneratedStrengthWorkout, day: Day) -> some View {
        NavigationLink {
            TrainerStrengthWorkoutView(iso: day.iso, sessionId: session.id)
        } label: {
            StrengthDayCard(model: app.trainer.planDayCard(generated, day: day, isClaude: app.trainer.isFreeClaudeDay(day), isDone: false))
        }
        .buttonStyle(.cardLink)
    }
}
