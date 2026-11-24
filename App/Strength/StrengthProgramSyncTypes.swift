import MFIT

enum MFITProgramChangeKind: Equatable, Sendable {
    case added, removed, changed
}

struct MFITProgramChange: Equatable, Sendable {
    let kind: MFITProgramChangeKind
    let workout: MFITWorkout
}

struct MFITProgramUpdate: Sendable {
    let cache: StrengthProgramCache
    let changes: [MFITProgramChange]
}
