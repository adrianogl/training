import Foundation

enum Command: String {
    case sync, report
}

struct Invocation {
    var command: Command
    var store: URL
}

enum CLIError: Error {
    case usage(String)
    case missingKey(path: String)
    case emptyKey(path: String)
}
