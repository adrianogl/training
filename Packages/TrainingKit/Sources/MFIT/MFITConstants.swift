import Foundation

public enum MFITConstants {
    public static let baseURL = URL(string: "https://api.mfitpersonal.com.br")!
    static let loginPath = "/auth/client"
    static let teachersPath = "/check/check-users"
    static let switchTeacherPath = "/check/authenticate-to-user?id="
    static let programsPath = "/v2/client/workout/all"
    static let programPath = "/v2/client/workout/?id="
    static let progressPath = "/v2/client/workout/progress?id="
    static let parenthesisPattern = #"\([^)]*\)"#
    static let sessionPath = "/v2/client/workout/session?id="
    static let authorizationHeader = "authorization"
    static let contentType = "application/json"
    static let timeout: TimeInterval = 20
    static let dateFormat = "MMM d, yyyy"
    static let dateLocale = "en_US_POSIX"
    static let combinedName = "combinado"
    static let instructionType = 5
    static let combinedItemType = 6
    static let loadTypes: Set<Int> = [0, 1, 4]
    static let defaultSets = 3
    static let defaultRestSeconds = 60.0
    static let setsPattern = #"(\d+)\s*s[ée]ries?"#
    static let restPattern = #"(\d+)(?:\s*(?:a|á|à|-)\s*(\d+))?\s*(seg|segundos|s|min|minutos)\s*de\s*(recupera|descanso|intervalo)"#
    static let noRestPattern = #"sem\s+(intervalo|descanso|recupera)"#
    static let repsPattern = #"(\d+)(?:\s*(?:a|á|à|-)\s*(\d+))?\s*(rep|repeti)"#
    static let secondsPattern = #"(\d+)\s*(seg|segundos)\b"#
    static let setsLeadPattern = #"^\s*\d+\s*s[ée]ries?\s*(de\s+)?"#
    static let setsTailPattern = #"\s*(com|sem)\s+.*$"#
    static let minuteWords: Set<String> = ["min", "minutos"]
}
