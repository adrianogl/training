import Foundation

public enum RemoteMerge {
    public static func action(remoteUpdatedAt: Date, remoteDeleted: Bool, localUpdatedAt: Date?) -> RemoteMergeAction {
        guard let localUpdatedAt else { return remoteDeleted ? .ignore : .insert }
        guard RemoteTimestamp.milliseconds(remoteUpdatedAt) > RemoteTimestamp.milliseconds(localUpdatedAt) else { return .keepLocal }
        return remoteDeleted ? .delete : .replace
    }
}
