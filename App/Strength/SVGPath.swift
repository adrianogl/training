import SwiftUI

enum SVGPath {
    static func path(_ data: String) -> Path {
        var path = Path()
        var numbers: [CGFloat] = []
        var command: Character?
        var token = ""

        func flushNumber() {
            if let value = Double(token) { numbers.append(CGFloat(value)) }
            token = ""
        }

        func apply() {
            guard let command else { return }
            switch command {
            case "M" where numbers.count >= 2:
                path.move(to: CGPoint(x: numbers[0], y: numbers[1]))
            case "L" where numbers.count >= 2:
                path.addLine(to: CGPoint(x: numbers[0], y: numbers[1]))
            case "C" where numbers.count >= 6:
                path.addCurve(
                    to: CGPoint(x: numbers[4], y: numbers[5]),
                    control1: CGPoint(x: numbers[0], y: numbers[1]),
                    control2: CGPoint(x: numbers[2], y: numbers[3])
                )
            case "Z":
                path.closeSubpath()
            default:
                break
            }
            numbers = []
        }

        for character in data {
            if "MLCZ".contains(character) {
                flushNumber()
                apply()
                command = character
            } else if character == " " {
                flushNumber()
            } else if character == "-", !token.isEmpty {
                flushNumber()
                token.append(character)
            } else {
                token.append(character)
            }
        }
        flushNumber()
        apply()
        return path
    }
}
