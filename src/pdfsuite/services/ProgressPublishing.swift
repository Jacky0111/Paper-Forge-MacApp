import Foundation

protocol ProgressPublishing {
    func publish(_ progress: DocumentJobProgress)
}

final class DefaultProgressBus: ProgressPublishing {
    private var latestProgress: [UUID: DocumentJobProgress] = [:]

    func publish(_ progress: DocumentJobProgress) {
        latestProgress[progress.jobID] = progress
    }

    func latestProgress(for jobID: UUID) -> DocumentJobProgress? {
        latestProgress[jobID]
    }
}
