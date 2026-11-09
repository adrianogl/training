import FITReader
import Foundation

enum FITOutcome {
    case read(summary: FITSummary, samples: Data, route: Data, structure: Data)
    case skipped
    case unavailable
    case rateLimited
}
