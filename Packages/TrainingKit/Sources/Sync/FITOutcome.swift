import FITReader
import Foundation

enum FITOutcome {
    case read(summary: FITSummary, samples: Data, route: Data)
    case skipped
    case rateLimited
}
