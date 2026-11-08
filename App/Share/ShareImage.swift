import CoreTransferable
import UIKit
import UniformTypeIdentifiers

struct ShareImage: Transferable {
    let data: Data?

    init(image: UIImage) {
        data = image.pngData()
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            guard let data = item.data else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
        .suggestedFileName(ShareConstants.fileName)
    }
}
