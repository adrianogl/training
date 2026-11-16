import GarminAPI
import Insights
import SwiftUI

struct StrengthWorkoutView: View {
    let model: StrengthModel
    let workoutId: Int64

    var body: some View {
        ScrollView {
            if let workout = model.workout(id: workoutId) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(workout.title).font(BrandFonts.display(24)).foregroundStyle(BrandColors.text)
                    Text(StrengthText.workoutSubtitle).font(.footnote).foregroundStyle(BrandColors.dim)
                    VStack(spacing: 8) {
                        BodyMapView(levels: model.levels(for: workout), height: StrengthConstants.detailMapHeight)
                        BodyMapLegend()
                    }
                    .brandCard()
                    StrengthBlockList(title: StrengthText.inOrder, blocks: workout.blocks)
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.bottom, 24)
            }
        }
        .background(BrandBackground())
        .navigationTitle(StrengthText.workoutTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StrengthSessionView: View {
    let model: StrengthModel
    let sessionId: Int64

    var body: some View {
        ScrollView {
            if let session = model.session(id: sessionId) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.title).font(BrandFonts.display(24)).foregroundStyle(BrandColors.text)
                    Text(StrengthText.dayLabel(session.day)).font(.footnote).foregroundStyle(BrandColors.dim)
                    HStack(spacing: 6) {
                        stat(session.minutes, StrengthText.minutes)
                        stat(session.averageHR, StrengthText.averageHR)
                        stat(session.maxHR, StrengthText.maxHR)
                        stat(session.effort, StrengthText.effort)
                    }
                    let blocks = model.blocks(forSession: sessionId)
                    if blocks.isEmpty {
                        Text(StrengthText.noWorkout).font(.footnote).foregroundStyle(BrandColors.dim).brandCard()
                    } else {
                        VStack(spacing: 6) {
                            BodyMapView(levels: model.levels(forSession: sessionId), height: StrengthConstants.detailMapHeight)
                            Text(StrengthText.workedMuscles).font(.caption).foregroundStyle(BrandColors.dim)
                        }
                        .brandCard()
                        StrengthBlockList(title: StrengthText.sessionWorkout, blocks: blocks)
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.bottom, 24)
            }
        }
        .background(BrandBackground())
        .navigationTitle(StrengthText.sessionTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ value: Int?, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value.map(String.init) ?? "—").font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
            Text(label).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(BrandColors.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BrandColors.cardBorder))
    }
}

struct StrengthVolumeView: View {
    let model: StrengthModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(StrengthText.volumeTitle).font(BrandFonts.display(24)).foregroundStyle(BrandColors.text)
                Text(StrengthText.volumeSubtitle).font(.footnote).foregroundStyle(BrandColors.dim)
                VStack(spacing: 10) {
                    ForEach(model.volumeRows) { row in
                        HStack(spacing: 10) {
                            Text(StrengthText.groupName(row.group)).font(.footnote).foregroundStyle(BrandColors.text)
                                .frame(width: 86, alignment: .leading)
                            spark(row.weekly)
                            Text("\(Int(row.weekly.dropLast().last ?? 0))").font(BrandFonts.number(16)).foregroundStyle(BrandColors.text)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
                .brandCard()
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationTitle(StrengthText.volumeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func spark(_ values: [Double]) -> some View {
        let top = max(values.max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                let level = StrengthMuscles.level(value, scale: .week)
                RoundedRectangle(cornerRadius: 2)
                    .fill(level > 0 ? StrengthConstants.heat[level - 1] : StrengthConstants.muscleOff)
                    .frame(height: max(2, StrengthConstants.sparkHeight * value / top))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: StrengthConstants.sparkHeight, alignment: .bottom)
    }
}
