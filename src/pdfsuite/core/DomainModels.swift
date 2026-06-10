import Foundation

struct DocumentJob: Identifiable, Hashable {
    let id: UUID
    let moduleIdentifier: String
    let sourceURL: URL
    let outputURL: URL?
    let createdAt: Date
    var status: DocumentJobStatus
    var progress: Double
    var message: String
    var resultURLs: [URL]

    init(
        id: UUID = UUID(),
        moduleIdentifier: String,
        sourceURL: URL,
        outputURL: URL?,
        createdAt: Date = Date(),
        status: DocumentJobStatus = .queued,
        progress: Double = 0,
        message: String = "Queued",
        resultURLs: [URL] = []
    ) {
        self.id = id
        self.moduleIdentifier = moduleIdentifier
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.createdAt = createdAt
        self.status = status
        self.progress = progress
        self.message = message
        self.resultURLs = resultURLs
    }
}

struct DocumentJobProgress: Hashable {
    let jobID: UUID
    let fractionCompleted: Double
    let statusMessage: String
}

enum DocumentJobStatus: String, Hashable {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

enum DocumentError: Error, LocalizedError {
    case unsupportedModule(String)
    case invalidInput(String)
    case processingFailed(String)
    case cancelled(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedModule(let message):
            return message
        case .invalidInput(let message):
            return message
        case .processingFailed(let message):
            return message
        case .cancelled(let message):
            return message
        }
    }
}
