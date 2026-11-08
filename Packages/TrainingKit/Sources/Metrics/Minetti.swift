import Foundation

public func minettiCost(grade i: Double) -> Double {
    155.4 * pow(i, 5) - 30.4 * pow(i, 4) - 43.3 * pow(i, 3) + 46.3 * pow(i, 2) + 19.5 * i + 3.6
}
