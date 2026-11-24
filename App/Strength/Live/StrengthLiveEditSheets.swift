import Insights
import SwiftUI

private typealias C = StrengthLiveViewConstants
private typealias T = StrengthLiveText

struct StrengthLiveWeightSheet: View {
    let exercise: LiveStrengthExercise
    let setsLeft: Int
    let planned: Double?
    let connected: Bool
    let onSend: (Double?, Bool, Bool) -> Void
    @State private var weight: Double = 0
    @State private var bodyweight = false
    @State private var nextOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.headline).foregroundStyle(BrandColors.text)
                Text(T.setsLeft(setsLeft, last: exercise.last.compactMap(\.weight).last)).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Toggle(T.bodyweightToggle, isOn: $bodyweight).tint(BrandColors.accentFill)
            StrengthLiveStepper(value: bodyweight ? nil : weight, unit: bodyweight ? T.noLoad : T.kilogramUnit, format: T.kilograms) { delta in
                weight = max(weight + delta * C.weightStep, 0)
            }
            .disabled(bodyweight)
            .opacity(bodyweight ? C.pendingOpacity : 1)
            Picker("", selection: $nextOnly) {
                Text(T.remainingScope).tag(false)
                Text(T.nextScope).tag(true)
            }
            .pickerStyle(.segmented)
            if bodyweight { Text(T.bodyweightNote).font(.caption).foregroundStyle(BrandColors.dim) }
            Button { onSend(bodyweight ? nil : weight, bodyweight, nextOnly) } label: {
                Text(T.sendToWatch)
            }
            .buttonStyle(.ds(.primary))
            .disabled(!connected)
            if !connected { Text(T.disconnected).font(.caption).foregroundStyle(BrandColors.dim) }
        }
        .padding(.horizontal, DSSpacing.s5)
        .padding(.top, DSSpacing.s6)
        .onAppear {
            weight = planned ?? exercise.last.compactMap(\.weight).last ?? 0
            bodyweight = exercise.bodyweight
        }
    }
}

struct StrengthLiveCorrectSheet: View {
    let exercise: LiveStrengthExercise
    let sets: [LiveStrengthSetResult]
    let onSave: (Int, Int?, Double?) -> Void
    @State private var index = 0
    @State private var reps = 0
    @State private var weight: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(T.correctionTitle(exercise.name, set: index + 1)).font(.headline).foregroundStyle(BrandColors.text)
                Text(T.doneColumn + " " + LiveStrengthLive.setText(sets[index], bodyweight: exercise.bodyweight)).font(.caption).foregroundStyle(BrandColors.dim)
            }
            if sets.count > 1 {
                Picker("", selection: $index) {
                    ForEach(sets.indices, id: \.self) { Text("\($0 + 1)").tag($0) }
                }
                .pickerStyle(.segmented)
            }
            StrengthLiveStepper(value: Double(reps), unit: T.repsUnit, format: { String(Int($0)) }) { delta in
                reps = max(reps + Int(delta), 0)
            }
            if !exercise.bodyweight {
                StrengthLiveStepper(value: weight, unit: T.kilogramUnit, format: T.kilograms) { delta in
                    weight = max(weight + delta * C.weightStep, 0)
                }
            }
            Button { onSave(index, reps, exercise.bodyweight ? nil : weight) } label: {
                Text(T.saveCorrection)
            }
            .buttonStyle(.ds(.primary))
            Text(T.correctionNote).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .padding(.horizontal, DSSpacing.s5)
        .padding(.top, DSSpacing.s6)
        .onAppear { load() }
        .onChange(of: index) { load() }
    }

    private func load() {
        reps = sets[index].reps ?? exercise.reps ?? 0
        weight = sets[index].weight ?? 0
    }
}

struct StrengthLiveStepper: View {
    let value: Double?
    let unit: String
    let format: (Double) -> String
    let onStep: (Double) -> Void

    var body: some View {
        HStack {
            button("minus", delta: -1)
            Spacer()
            VStack(spacing: 0) {
                Text(value.map(format) ?? T.bodyweightShort).font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(BrandColors.text)
                Text(unit).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Spacer()
            button("plus", delta: 1)
        }
        .padding(8)
        .background(BrandColors.card, in: .rect(cornerRadius: DSRadius.medium))
    }

    private func button(_ symbol: String, delta: Double) -> some View {
        Button { onStep(delta) } label: {
            Image(systemName: symbol).font(.title3.weight(.semibold)).frame(width: C.stepperSize, height: C.stepperSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(BrandColors.text)
        .background(BrandColors.line, in: .rect(cornerRadius: DSRadius.small))
    }
}
