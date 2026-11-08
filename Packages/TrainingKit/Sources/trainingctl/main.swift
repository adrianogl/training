import Foundation
import Storage
import SwiftData
import TrainingCore

func parse(_ arguments: [String]) throws -> Invocation {
    guard let first = arguments.first else { throw CLIError.usage("Faltou o comando.") }
    guard let command = Command(rawValue: first) else { throw CLIError.usage("Comando desconhecido: \(first)") }
    var store: String?
    var rest = arguments.dropFirst()
    while let argument = rest.popFirst() {
        guard argument == "--store" else { throw CLIError.usage("Argumento desconhecido: \(argument)") }
        guard let value = rest.popFirst(), !value.hasPrefix("--") else { throw CLIError.usage("Faltou o caminho depois de --store.") }
        store = value
    }
    guard let store else { throw CLIError.usage("Faltou --store <caminho>.") }
    let path = (store as NSString).expandingTildeInPath
    return Invocation(command: command, store: URL(filePath: path, relativeTo: URL.currentDirectory()).absoluteURL)
}

func openContainer(at store: URL) throws -> ModelContainer {
    try FileManager.default.createDirectory(at: store.deletingLastPathComponent(), withIntermediateDirectories: true)
    return try TrainingSchema.container(url: store)
}

func fail(_ error: Error) -> Never {
    FileHandle.standardError.write(Data((CLIMessages.message(for: error) + "\n").utf8))
    if case CLIError.usage = error { exit(CLIConstants.usageExitCode) }
    exit(CLIConstants.failureExitCode)
}

do {
    let invocation = try parse(Array(CommandLine.arguments.dropFirst()))
    switch invocation.command {
    case .sync:
        let apiKey = try SyncCommand.readKey(at: SyncCommand.keyPath())
        let container = try openContainer(at: invocation.store)
        SyncCommand.lines(try await SyncCommand.run(apiKey: apiKey, container: container)).forEach { print($0) }
    case .report:
        let container = try openContainer(at: invocation.store)
        let report = try ReportBuilder(context: ModelContext(container), today: Day.today()).build()
        ReportFormatter.lines(report).forEach { print($0) }
    }
} catch {
    fail(error)
}
