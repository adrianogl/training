import SwiftUI
import UIKit

enum BrandLogo {
    static func image(for group: SettingsGroup) -> UIImage? {
        guard let name = BrandLogoConstants.files[group],
              let path = Bundle.main.path(forResource: name, ofType: BrandLogoConstants.fileExtension, inDirectory: BrandLogoConstants.directory)
        else { return nil }
        return UIImage(contentsOfFile: path)
    }
}
