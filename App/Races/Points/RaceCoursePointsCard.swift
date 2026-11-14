import SwiftUI

struct RaceCoursePointsCard: View {
    let raceId: UUID
    let distance: Double
    let profile: [GPXPoint]?
    let targetSeconds: Double?
    @AppStorage private var waterText: String

    private typealias C = CoursePointsConstants

    init(raceId: UUID, distance: Double, profile: [GPXPoint]?, targetSeconds: Double?) {
        self.raceId = raceId
        self.distance = distance
        self.profile = profile
        self.targetSeconds = targetSeconds
        _waterText = AppStorage(wrappedValue: "", C.defaultsPrefix + raceId.uuidString)
    }

    var body: some View {
        let climbs = CoursePointsBuilder.climbs(profile ?? [])
        let water = CoursePointsBuilder.water(waterText)
        let gels = CoursePointsBuilder.gels(distance: distance, targetSeconds: targetSeconds)
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(C.title).padding(.top, 0).padding(.bottom, 0)
            if let profile, profile.count >= 2 {
                GeometryReader { proxy in
                    let x = { (km: Double) in proxy.size.width * km * 1_000 / max(distance, 1) }
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(climbs.enumerated()), id: \.offset) { _, climb in
                            Rectangle().fill(BrandColors.attention.opacity(0.18))
                                .frame(width: max(2, x(climb.endKm) - x(climb.startKm)), height: proxy.size.height)
                                .offset(x: x(climb.startKm))
                        }
                        ElevationLine(values: profile.map(\.altitude))
                        ForEach(water, id: \.self) { km in
                            Image(systemName: "drop.fill").font(.caption).foregroundStyle(BrandColors.fitness)
                                .position(x: x(km), y: proxy.size.height - 8)
                        }
                        ForEach(gels, id: \.self) { km in
                            Image(systemName: "bolt.fill").font(.caption).foregroundStyle(BrandColors.accent)
                                .position(x: x(km), y: 8)
                        }
                    }
                }
                .frame(height: C.profileHeight)
            } else {
                Text(C.noProfile).font(.caption).foregroundStyle(BrandColors.dim)
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(climbs.enumerated()), id: \.offset) { _, climb in
                    Label(String(format: C.climbFormat, km(climb.startKm), km(climb.endKm), Int(climb.gain.rounded())), systemImage: "arrow.up.right")
                        .foregroundStyle(BrandColors.attention)
                }
                ForEach(water, id: \.self) { value in
                    Label(String(format: C.waterFormat, km(value)), systemImage: "drop.fill").foregroundStyle(BrandColors.fitness)
                }
                ForEach(gels, id: \.self) { value in
                    Label(String(format: C.gelFormat, km(value)), systemImage: "bolt.fill").foregroundStyle(BrandColors.accent)
                }
            }
            .font(.caption)
            VStack(alignment: .leading, spacing: 4) {
                Text(C.waterLabel).font(.caption2).foregroundStyle(BrandColors.dim)
                TextField(C.waterPlaceholder, text: $waterText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func km(_ value: Double) -> String {
        TodayText.decimal(value, fractionDigits: value.rounded() == value ? 0 : 1)
    }
}
