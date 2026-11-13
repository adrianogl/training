import Charts
import FITReader
import MapKit
import SwiftUI

struct RouteMapView: View {
    let route: [Coordinate]
    let altitude: [(t: Double, meters: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            map
            if altitude.count > 1 {
                altitudeChart
            }
        }
        .brandCard()
    }

    private var coordinates: [CLLocationCoordinate2D] {
        route
            .map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            .filter { CLLocationCoordinate2DIsValid($0) && !($0.latitude == 0 && $0.longitude == 0) }
    }

    private var map: some View {
        let points = coordinates
        return Map(initialPosition: .rect(Self.frame(points)), interactionModes: []) {
            MapPolyline(coordinates: points)
                .stroke(BrandColors.accent, style: StrokeStyle(lineWidth: WorkoutDetailConstants.routeLineWidth, lineCap: .round, lineJoin: .round))
            if let start = points.first {
                Annotation("", coordinate: start) { marker(BrandColors.accent) }
            }
            if let end = points.last, points.count > 1 {
                Annotation("", coordinate: end) { marker(BrandColors.race) }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: WorkoutDetailConstants.mapHeight)
        .clipShape(RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius - 6, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityLabel("Mapa do percurso")
    }

    private func marker(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .stroke(BrandColors.onAccent, lineWidth: 2)
            .frame(width: WorkoutDetailConstants.routeMarkerSize, height: WorkoutDetailConstants.routeMarkerSize)
    }

    private var altitudeChart: some View {
        let values = altitude.map { $0.meters }
        let low = (values.min() ?? 0) - WorkoutDetailConstants.altitudeDomainPadding
        let high = (values.max() ?? 0) + WorkoutDetailConstants.altitudeDomainPadding
        return VStack(alignment: .leading, spacing: 4) {
            Text("Altimetria · \(Int((values.max() ?? 0) - (values.min() ?? 0))) m de variação")
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
            Chart(Array(altitude.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("min", point.t / WorkoutDetailConstants.secondsPerMinute),
                    yStart: .value("base", low),
                    yEnd: .value("m", point.meters)
                )
                .foregroundStyle(BrandColors.dim.opacity(WorkoutDetailConstants.altitudeFillOpacity))
                LineMark(
                    x: .value("min", point.t / WorkoutDetailConstants.secondsPerMinute),
                    y: .value("m", point.meters)
                )
                .foregroundStyle(BrandColors.dim)
                .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartYScale(domain: low...high)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: WorkoutDetailConstants.altitudeHeight)
        }
    }

    private static func frame(_ points: [CLLocationCoordinate2D]) -> MKMapRect {
        let mapPoints = points.map(MKMapPoint.init)
        guard let first = mapPoints.first else { return .world }
        var rect = mapPoints.dropFirst().reduce(MKMapRect(origin: first, size: MKMapSize(width: 0, height: 0))) { rect, point in
            rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
        let minimum = WorkoutDetailConstants.routeMinimumSpan * MKMapPointsPerMeterAtLatitude(points[0].latitude)
        if rect.width < minimum { rect = rect.insetBy(dx: -(minimum - rect.width) / 2, dy: 0) }
        if rect.height < minimum { rect = rect.insetBy(dx: 0, dy: -(minimum - rect.height) / 2) }
        let padding = WorkoutDetailConstants.routeFramePadding
        return rect.insetBy(dx: -rect.width * padding, dy: -rect.height * padding)
    }
}
