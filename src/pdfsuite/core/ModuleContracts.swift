import Foundation

struct ModuleExecutionContext {
    let outputDirectory: URL
    let settings: [String: String]
    let progressHandler: (Double, String) -> Void
    let cancellationHandler: () -> Bool

    init(
        outputDirectory: URL,
        settings: [String: String],
        progressHandler: @escaping (Double, String) -> Void = { _, _ in },
        cancellationHandler: @escaping () -> Bool = { false }
    ) {
        self.outputDirectory = outputDirectory
        self.settings = settings
        self.progressHandler = progressHandler
        self.cancellationHandler = cancellationHandler
    }

    func reportProgress(_ fractionCompleted: Double, _ statusMessage: String) {
        progressHandler(min(max(fractionCompleted, 0), 1), statusMessage)
    }

    func checkCancellation() throws {
        if cancellationHandler() {
            throw DocumentError.cancelled("The job was cancelled.")
        }
    }
}

struct ModuleExecutionReport: Identifiable, Hashable {
    let id: UUID
    let moduleID: String
    let outputURLs: [URL]
    let summary: String
}

protocol ModulePerforming {
    var manifest: ModuleManifest { get }
    func execute(inputURL: URL, context: ModuleExecutionContext) throws -> ModuleExecutionReport
}
