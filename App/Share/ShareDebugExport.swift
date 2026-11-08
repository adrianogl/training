#if DEBUG
import Foundation
import UIKit
import WorkoutAnalysis

@MainActor
enum ShareDebugExport {
    static func runIfRequested(input: WorkoutShareInput, enabled: Set<ShareField>, defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: AppConstants.exportShareDefaultsKey),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let folder = documents.appendingPathComponent(ShareConstants.exportFolder, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for template in ShareTemplate.allCases {
            let content = shareContent(record: input, enabled: enabled, template: template)
            let image = ShareRenderer.render(content, template: template, scale: ShareConstants.exportScale)
            try? ShareImage(image: image).data?.write(to: folder.appendingPathComponent("\(template.rawValue).png"))
        }
    }
}
#endif
