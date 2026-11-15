import GarminAPI
import SwiftUI

struct RaceDayCard: View {
    let model: NextRaceModel
    let info: RaceInfo
    let client: GarminAccountClient?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaceStrategyCard(model: model)
            Divider().overlay(BrandColors.line)
            RaceCoursePointsCard(raceId: info.id, distance: info.distance, profile: model.profile, targetSeconds: model.target?.seconds ?? info.goalSeconds)
            Divider().overlay(BrandColors.line)
            RaceStrategyUploadButton(info: info, strategy: model.strategy, client: client)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
