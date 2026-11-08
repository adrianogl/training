import Foundation

enum Command: String {
    case sync, report, reprocess
}

struct Invocation {
    var command: Command
    var store: URL
    var limit: Int?
}

enum CLIError: Error {
    case usage(String)
    case missingKey(path: String)
    case emptyKey(path: String)
}
