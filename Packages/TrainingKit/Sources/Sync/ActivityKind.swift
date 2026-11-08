enum ActivityKind {
    static func isRun(_ typeKey: String) -> Bool {
        typeKey.contains(SyncConstants.runTypeKeyMarker)
    }
}
