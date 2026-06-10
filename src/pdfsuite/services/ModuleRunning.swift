import Foundation

protocol ModuleRunning {
    func run(
        moduleID: String,
        inputURL: URL,
        outputDirectory: URL,
        settings: [String: String],
        progressHandler: @escaping (Double, String) -> Void,
        cancellationHandler: @escaping () -> Bool
    ) throws -> ModuleExecutionReport
}

struct DefaultModuleRunner: ModuleRunning {
    let moduleRegistry: ModuleRegistering

    func run(
        moduleID: String,
        inputURL: URL,
        outputDirectory: URL,
        settings: [String: String],
        progressHandler: @escaping (Double, String) -> Void = { _, _ in },
        cancellationHandler: @escaping () -> Bool = { false }
    ) throws -> ModuleExecutionReport {
        guard let module = moduleRegistry.module(for: moduleID, settings: settings) else {
            throw DocumentError.unsupportedModule("The selected feature is not available yet.")
        }

        let context = ModuleExecutionContext(
            outputDirectory: outputDirectory,
            settings: settings,
            progressHandler: progressHandler,
            cancellationHandler: cancellationHandler
        )
        return try module.execute(inputURL: inputURL, context: context)
    }
}
