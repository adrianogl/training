struct FITStepResult {
    var processed = 0
    var reprocessed = 0
    var stoppedByRateLimit = false
    var activityIds: Set<Int64> = []
    var skipped: [SkippedFIT] = []
}
