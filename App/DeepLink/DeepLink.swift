import Foundation

enum DeepLink: Equatable {
    case section(AppSection)
    case readiness
    case workout(Int64)
    case trainer(TrainerRoute)

    init?(url: URL) {
        guard let section = AppSection(url: url) else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch (section, parts.first) {
        case (.today, DeepLinkConstants.readinessPath): self = .readiness
        case (.workouts, let id?): self = Int64(id).map { .workout($0) } ?? .section(section)
        case (.trainer, DeepLinkConstants.strengthPath): self = .trainer(.strength)
        case (.trainer, DeepLinkConstants.changesPath): self = .trainer(.changes)
        default: self = .section(section)
        }
    }

    var section: AppSection {
        switch self {
        case .section(let section): section
        case .readiness: .today
        case .workout: .workouts
        case .trainer: .workouts
        }
    }

    static func workoutURL(_ activityId: Int64) -> String {
        DeepLinkConstants.workoutsPrefix + String(activityId)
    }
}
