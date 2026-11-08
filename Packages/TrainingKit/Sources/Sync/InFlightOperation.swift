struct InFlightOperation {
    var operation: SyncOperation
    var task: Task<SyncReport, Error>
}
