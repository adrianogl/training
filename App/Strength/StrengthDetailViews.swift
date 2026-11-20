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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
                        Text(StrengthText.workoutSubtitle).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandCard()
                    StrengthSection(title: StrengthText.musclesTitle)
                    VStack(spacing: 8) {
                        BodyMapView(levels: model.levels(for: workout), height: StrengthConstants.detailMapHeight)
                        BodyMapLegend()
                    }
                    .brandCard()
                    StrengthSection(title: StrengthText.inOrder)
                    StrengthBlockList(blocks: workout.blocks, workoutDay: workout.day)
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
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
                    VStack(alignment: .leading, spacing: 4) {
                        DSCardLabel(StrengthText.dayLabel(session.day))
                        Text(session.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
                        HStack(alignment: .top, spacing: 12) {
                            stat(session.minutes, StrengthText.minutes)
                            stat(session.averageHR, StrengthText.averageHR)
                            stat(session.maxHR, StrengthText.maxHR)
                            stat(session.effort, StrengthText.effort)
                        }
                        .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandCard()
                    let blocks = model.blocks(forSession: sessionId)
                    if blocks.isEmpty {
                        DSNotice(tone: .info, text: StrengthText.noWorkout)
                    } else {
                        StrengthSection(title: StrengthText.musclesTitle)
                        VStack(spacing: 8) {
                            BodyMapView(levels: model.levels(forSession: sessionId), height: StrengthConstants.detailMapHeight)
                            BodyMapLegend()
                        }
                        .brandCard()
                        StrengthSection(title: StrengthText.sessionWorkout)
                        StrengthBlockList(blocks: blocks, workoutDay: session.day.iso)
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(BrandBackground())
        .navigationTitle(StrengthText.sessionTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ value: Int?, _ label: String) -> some View {
        DSStat(value: value.map(String.init), label: label, size: .large)
    }
}

struct StrengthVolumeView: View {
    let model: StrengthModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        DSCardLabel(StrengthText.volumeCardTitle)
                        Spacer()
                        Text(String(format: StrengthText.volumeWeeksFormat, model.volumeWeekStarts.count)).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    HStack(spacing: 10) {
                        Color.clear.frame(width: 86, height: 1)
                        HStack(spacing: 3) {
                            ForEach(model.volumeWeekStarts, id: \.self) { start in
                                Text("\(start.day)/\(start.month)").font(.system(size: 9)).foregroundStyle(BrandColors.dim)
                                    .lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity)
                            }
                        }
                        Text(StrengthText.volumeLastWeek).font(.system(size: 9)).foregroundStyle(BrandColors.dim)
                            .frame(width: 28, alignment: .trailing)
                    }
                    ForEach(model.volumeRows) { row in
                        HStack(spacing: 10) {
                            Text(StrengthText.groupName(row.group)).font(.footnote).foregroundStyle(BrandColors.text)
                                .frame(width: 86, alignment: .leading)
                            spark(row.weekly)
                            Text("\(Int(row.weekly.dropLast().last ?? 0))").font(BrandFonts.number(16)).foregroundStyle(BrandColors.text)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                    HStack(spacing: DSSpacing.s3) {
                        ForEach(Array(StrengthText.volumeLegend.enumerated()), id: \.offset) { index, label in
                            DSLegendItem(text: label, color: StrengthConstants.heat[index], mark: .square)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .brandCard()
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
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
