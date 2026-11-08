public enum ActivityTypeKey {
    public static func isRun(_ typeKey: String) -> Bool {
        typeKey == ActivityTypeKeyConstants.running
            || ActivityTypeKeyConstants.runSuffixes.contains { typeKey.hasSuffix($0) }
    }
}
