import FITReader
import Foundation

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    var points: [(latitude: Double, longitude: Double, altitude: Double)] = []
    private var currentCoordinate: (Double, Double)?
    private var currentAltitude: Double?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if elementName == "trkpt" || elementName == "rtept" {
            if let latitude = attributes["lat"].flatMap(Double.init), let longitude = attributes["lon"].flatMap(Double.init) {
                currentCoordinate = (latitude, longitude)
            } else {
                currentCoordinate = nil
            }
            currentAltitude = nil
        }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "ele":
            currentAltitude = Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        case "trkpt", "rtept":
            if let coordinate = currentCoordinate, let altitude = currentAltitude {
                points.append((coordinate.0, coordinate.1, altitude))
            }
            currentCoordinate = nil
            currentAltitude = nil
        default:
            break
        }
    }
}

private func haversine(_ a: (latitude: Double, longitude: Double), _ b: (latitude: Double, longitude: Double)) -> Double {
    let toRadians = Double.pi / 180
    let deltaLatitude = (b.latitude - a.latitude) * toRadians
    let deltaLongitude = (b.longitude - a.longitude) * toRadians
    let h = pow(sin(deltaLatitude / 2), 2) + cos(a.latitude * toRadians) * cos(b.latitude * toRadians) * pow(sin(deltaLongitude / 2), 2)
    return 2 * RaceConstants.earthRadiusMeters * asin(min(1, sqrt(h)))
}

public func gpxProfile(_ data: Data) throws -> [(distance: Double, altitude: Double)] {
    let delegate = GPXParserDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = delegate
    guard parser.parse() else { throw GPXError.invalidFile }
    guard !delegate.points.isEmpty else { throw GPXError.noElevation }

    var distance = 0.0
    var profile: [(distance: Double, altitude: Double)] = []
    var previous: (latitude: Double, longitude: Double)?
    for point in delegate.points {
        let coordinate = (latitude: point.latitude, longitude: point.longitude)
        if let previous { distance += haversine(previous, coordinate) }
        profile.append((distance, point.altitude))
        previous = coordinate
    }
    return profile
}

public func reducedGPX(_ data: Data, maxPoints: Int) throws -> Data {
    let delegate = GPXParserDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = delegate
    guard parser.parse() else { throw GPXError.invalidFile }
    guard !delegate.points.isEmpty else { throw GPXError.noElevation }
    let kept = RouteSimplifier.simplify(delegate.points.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }, maxPoints: maxPoints)
    var remaining = kept[...]
    var text = #"<?xml version="1.0" encoding="UTF-8"?><gpx version="1.1" creator="trAIning"><trk><trkseg>"#
    for point in delegate.points {
        guard let next = remaining.first, next.lat == point.latitude, next.lon == point.longitude else { continue }
        remaining = remaining.dropFirst()
        text += #"<trkpt lat="\#(point.latitude)" lon="\#(point.longitude)"><ele>\#(point.altitude)</ele></trkpt>"#
    }
    text += "</trkseg></trk></gpx>"
    return Data(text.utf8)
}
