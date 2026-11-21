import SwiftUI

extension Shape where Self == ConcentricRectangle {
    static var dsInner: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(DSRadius.medium)), isUniform: true)
    }
}
