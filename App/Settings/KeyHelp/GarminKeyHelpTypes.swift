enum GarminKeyHelpIllustration {
    case openPage, chooseExpiry, acceptTerms, copyKey, pasteInApp
}

struct GarminKeyHelpStep: Identifiable {
    let number: Int
    let title: String
    let detail: String
    let illustration: GarminKeyHelpIllustration

    var id: Int { number }
}
