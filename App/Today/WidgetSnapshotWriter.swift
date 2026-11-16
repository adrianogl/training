import Foundation
import WidgetKit

enum WidgetSnapshotWriter {
    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = WidgetSharedConstants.fileURL, snapshot != WidgetSharedConstants.load().with(updatedAt: snapshot.updatedAt),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func firstSentence(_ text: String) -> String? {
        let sentence = text.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces) ?? ""
        return sentence.isEmpty ? nil : sentence
    }
}

extension WidgetSnapshot {
    func with(updatedAt date: Date) -> WidgetSnapshot {
        var copy = self
        copy.updatedAt = date
        return copy
    }
}
