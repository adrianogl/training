import Foundation
import Testing
@testable import GarminAPI

@Suite struct GarminCoursesTests {
    @Test func convertsCourseToGPXWithElevation() throws {
        let json = #"{"courseName":"Pampulha <10K> & volta","geoPoints":[{"latitude":-19.85,"longitude":-43.97,"elevation":800.5,"distance":0},{"latitude":-19.86,"longitude":-43.98,"elevation":812,"distance":120}]}"#
        let detail = try JSONDecoder().decode(GarminCourses.Detail.self, from: Data(json.utf8))

        let xml = String(decoding: GarminCourses.gpx(from: detail), as: UTF8.self)

        #expect(xml.contains(#"<trkpt lat="-19.85" lon="-43.97"><ele>800.5</ele></trkpt>"#))
        #expect(xml.components(separatedBy: "<trkpt").count == 3)
        #expect(xml.contains("<name>Pampulha &lt;10K&gt; &amp; volta</name>"))
    }
}
