enum AccountPasswordRule {
    static func problem(password: String, confirmation: String) -> String? {
        if password.count < AccountConstants.passwordMinLength { return AccountConstants.shortPassword }
        if password != confirmation { return AccountConstants.mismatch }
        return nil
    }
}
