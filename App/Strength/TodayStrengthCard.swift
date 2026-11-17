import GarminAPI
import MFIT
import SwiftUI
import TrainingCore

struct TodayStrengthCard<Label: View>: View {
    @Environment(AppModel.self) private var app
    var showsLabel: Bool
    @ViewBuilder var label: () -> Label
    @State private var workout: StrengthWorkout?

    var body: some View {
        Group {
            if let workout {
                if showsLabel { label() }
                NavigationLink {
                    StrengthPlannedDetailView(workoutId: workout.id)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(StrengthText.todaySource).font(.caption).foregroundStyle(BrandColors.dim)
                            Spacer()
                            TrainerStrengthSourceChip(source: .mfit)
                            Text(StrengthText.open).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                        }
                        Text(workout.title).font(.headline).foregroundStyle(BrandColors.text)
                        Text(StrengthText.countLabel(exercises: workout.blocks.flatMap(\.exercises).count, sets: workout.totalSets))
                            .font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    .brandCard()
                }
                .buttonStyle(.plain)
            } else if let session = app.trainer.trainerSessions(on: Day.today()).first,
                      let generated = app.trainer.strengthWorkout(sessionId: session.id, day: Day.today()) {
                if showsLabel { label() }
                NavigationLink {
                    TrainerStrengthWorkoutView(iso: Day.today().iso, sessionId: session.id)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(TrainerStrengthText.todayTitle).font(.caption).foregroundStyle(BrandColors.dim)
                            Spacer()
                            if app.trainer.isClaudeDay(Day.today()) {
                                ClaudeSourceChip()
                            } else {
                                TrainerStrengthSourceChip(source: .trainer)
                            }
                            Text(StrengthText.open).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                        }
                        Text(TrainerStrengthText.focusName(generated.group)).font(.headline).foregroundStyle(BrandColors.text)
                        Text(TrainerStrengthText.meta(generated)).font(.caption).foregroundStyle(BrandColors.dim)
                        if let adjustment = generated.adjustments.first {
                            Text(TrainerStrengthText.adjustmentTitle(adjustment)).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention)
                        }
                    }
                    .brandCard()
                }
                .buttonStyle(.plain)
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
}
