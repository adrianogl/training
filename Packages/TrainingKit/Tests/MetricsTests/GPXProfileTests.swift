import Foundation
import Testing
@testable import Metrics

@Test func gpxProfileAccumulatesDistance() throws {
    let xml = """
    <?xml version="1.0"?>
    <gpx><trk><trkseg>
    <trkpt lat="0.000" lon="0.0"><ele>10</ele></trkpt>
    <trkpt lat="0.001" lon="0.0"><ele>12</ele></trkpt>
    <trkpt lat="0.002" lon="0.0"><ele>15</ele></trkpt>
    </trkseg></trk></gpx>
    """
    let profile = try gpxProfile(Data(xml.utf8))
    #expect(profile.count == 3)
    #expect(profile[0].distance == 0)
    #expect(abs(profile[1].distance - 111.2) < 0.5)
    #expect(abs(profile[2].distance - 222.4) < 1.0)
    #expect(profile.map(\.altitude) == [10, 12, 15])
}

@Test func gpxWithoutElevationThrows() {
    let xml = """
    <gpx><trk><trkseg>
    <trkpt lat="0.0" lon="0.0"></trkpt>
    <trkpt lat="0.001" lon="0.0"></trkpt>
    </trkseg></trk></gpx>
    """
    #expect(throws: GPXError.noElevation) {
        try gpxProfile(Data(xml.utf8))
    }
}
