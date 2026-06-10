import AppKit
import UniformTypeIdentifiers
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let container: AppContainer
    @Published var selectedModuleID: String = "pdf_to_images"
    @Published var inputURL: URL?
    @Published var outputDirectory: URL?
    @Published var statusMessage: String = "Choose a feature, input file, and output folder."
    @Published var isRunning: Bool = false
    @Published var lastReport: ModuleExecutionReport?
    @Published var pdfImageFormat: PDFImageFormat = .png
    @Published var pdfImageDPI: Int = 200
    @Published var txtFontSize: Double = 12
    @Published var txtMargin: Double = 48
    @Published var flattenPreserveAnnotations: Bool = false
    @Published var jobs: [DocumentJob] = []
    @Published var cancellationRequested: Bool = false
    private var currentCancellationToken: CancellationToken?

    init(container: AppContainer = .live) {
        self.container = container
        loadSettings()
        jobs = container.jobStore.allJobs()
    }

    var moduleManifests: [ModuleManifest] {
        container.moduleRegistry.allManifests()
    }

    var selectedModule: ModuleManifest? {
        moduleManifests.first { $0.id == selectedModuleID }
    }

    func runSelectedModule() {
        guard let inputURL else {
            statusMessage = "Choose an input file first."
            return
        }

        guard let outputDirectory else {
            statusMessage = "Choose an output folder first."
            return
        }

        let settings = settingsForSelectedModule()
        saveSettings()
        cancellationRequested = false
        isRunning = true
        statusMessage = "Running \(selectedModule?.displayName ?? "feature")..."
        lastReport = nil
        let cancellationToken = CancellationToken()
        currentCancellationToken = cancellationToken

        let job = DocumentJob(
            moduleIdentifier: selectedModuleID,
            sourceURL: inputURL,
            outputURL: outputDirectory,
            status: .running,
            progress: 0.1,
            message: statusMessage
        )
        container.jobStore.enqueue(job)
        jobs = container.jobStore.allJobs()
        container.progressBus.publish(
            DocumentJobProgress(jobID: job.id, fractionCompleted: job.progress, statusMessage: job.message)
        )

        let moduleRunner = container.moduleRunner
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let report = try moduleRunner.run(
                    moduleID: job.moduleIdentifier,
                    inputURL: inputURL,
                    outputDirectory: outputDirectory,
                    settings: settings,
                    progressHandler: { fractionCompleted, message in
                        Task { @MainActor [weak self] in
                            self?.updateJob(
                                id: job.id,
                                status: .running,
                                progress: fractionCompleted,
                                message: message,
                                resultURLs: []
                            )
                        }
                    },
                    cancellationHandler: {
                        cancellationToken.isCancelled
                    }
                )

                await MainActor.run { [weak self] in
                    self?.finishJob(jobID: job.id, report: report)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.failJob(jobID: job.id, error: error, wasCancelled: cancellationToken.isCancelled)
                }
            }
        }
    }

    func cancelCurrentJob() {
        cancellationRequested = true
        currentCancellationToken?.cancel()
        statusMessage = "Cancellation requested."
    }

    func openOutputFolder() {
        guard let outputDirectory else {
            statusMessage = "Choose an output folder first."
            return
        }

        NSWorkspace.shared.open(outputDirectory)
    }

    func chooseInputFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.allowedContentTypes = inputContentTypes()
        panel.title = "Choose Input File"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            inputURL = selectedURL
            statusMessage = "Input selected."
            if outputDirectory == nil {
                outputDirectory = selectedURL.deletingLastPathComponent().appendingPathComponent(
                    "\(selectedURL.deletingPathExtension().lastPathComponent)_output",
                    isDirectory: true
                )
            }
        }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.title = "Choose Output Folder"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            outputDirectory = selectedURL
            statusMessage = "Output folder selected."
        }
    }

    private func settingsForSelectedModule() -> [String: String] {
        switch selectedModuleID {
        case "pdf_to_images":
            return [
                "dpi": String(pdfImageDPI),
                "format": pdfImageFormat.rawValue
            ]
        case "txt_to_pdf":
            return [
                "fontSize": String(txtFontSize),
                "margin": String(txtMargin)
            ]
        case "flatten_pdf":
            return [
                "preserveAnnotations": flattenPreserveAnnotations ? "true" : "false"
            ]
        default:
            return [:]
        }
    }

    private func loadSettings() {
        if let format = container.settingsStore.value(forKey: "pdfImageFormat"),
           let parsedFormat = PDFImageFormat(rawValue: format) {
            pdfImageFormat = parsedFormat
        }

        if let dpi = container.settingsStore.value(forKey: "pdfImageDPI"),
           let parsedDPI = Int(dpi) {
            pdfImageDPI = parsedDPI
        }

        if let fontSize = container.settingsStore.value(forKey: "txtFontSize"),
           let parsedFontSize = Double(fontSize) {
            txtFontSize = parsedFontSize
        }

        if let margin = container.settingsStore.value(forKey: "txtMargin"),
           let parsedMargin = Double(margin) {
            txtMargin = parsedMargin
        }

        if let preserve = container.settingsStore.value(forKey: "flattenPreserveAnnotations") {
            flattenPreserveAnnotations = preserve == "true"
        }
    }

    private func saveSettings() {
        container.settingsStore.setValue(pdfImageFormat.rawValue, forKey: "pdfImageFormat")
        container.settingsStore.setValue(String(pdfImageDPI), forKey: "pdfImageDPI")
        container.settingsStore.setValue(String(txtFontSize), forKey: "txtFontSize")
        container.settingsStore.setValue(String(txtMargin), forKey: "txtMargin")
        container.settingsStore.setValue(flattenPreserveAnnotations ? "true" : "false", forKey: "flattenPreserveAnnotations")
    }

    private func inputContentTypes() -> [UTType] {
        guard let manifest = selectedModule else { return [.item] }
        let types = manifest.supportedInputTypes.compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.item] : types
    }

    private func updateJob(
        id: UUID,
        status: DocumentJobStatus,
        progress: Double,
        message: String,
        resultURLs: [URL]
    ) {
        guard var job = jobs.first(where: { $0.id == id }) else { return }
        job.status = status
        job.progress = progress
        job.message = message
        job.resultURLs = resultURLs
        statusMessage = message
        container.jobStore.update(job)
        jobs = container.jobStore.allJobs()
        container.progressBus.publish(
            DocumentJobProgress(jobID: id, fractionCompleted: progress, statusMessage: message)
        )
    }

    private func finishJob(jobID: UUID, report: ModuleExecutionReport) {
        lastReport = report
        updateJob(
            id: jobID,
            status: .completed,
            progress: 1,
            message: report.summary,
            resultURLs: report.outputURLs
        )
        currentCancellationToken = nil
        cancellationRequested = false
        isRunning = false
    }

    private func failJob(jobID: UUID, error: Error, wasCancelled: Bool) {
        let message = error.localizedDescription
        updateJob(
            id: jobID,
            status: wasCancelled ? .cancelled : .failed,
            progress: 1,
            message: message,
            resultURLs: []
        )
        currentCancellationToken = nil
        isRunning = false
    }
}
