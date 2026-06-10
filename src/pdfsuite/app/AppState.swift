import AppKit
import UniformTypeIdentifiers
import UserNotifications
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let container: AppContainer
    @Published var selectedModuleID: String = "pdf_to_images" {
        didSet {
            guard oldValue != selectedModuleID else { return }
            if let url = inputURL {
                let ext = url.pathExtension.lowercased()
                let newManifest = moduleManifests.first { $0.id == selectedModuleID }
                if newManifest?.supportedInputTypes.contains(ext) != true {
                    inputURL = nil
                }
            }
            lastReport = nil
            currentProgress = 0
            statusMessage = "Drop a file or click Choose File to get started."
        }
    }
    @Published var inputURL: URL?
    @Published var outputDirectory: URL?
    @Published var statusMessage: String = "Drop a file or click Choose File to get started."
    @Published var isRunning: Bool = false
    @Published var currentProgress: Double = 0
    @Published var lastReport: ModuleExecutionReport?
    @Published var pdfImageFormat: PDFImageFormat = .png
    @Published var pdfImageDPI: Int = 200
    @Published var txtFontSize: Double = 12
    @Published var txtMargin: Double = 48
    @Published var flattenPreserveAnnotations: Bool = false
    @Published var wordPageBreaks: Bool = true
    @Published var pptxIncludeImages: Bool = true
    @Published var pptxSlideSize: PDFToPPTXOptions.SlideSize = .widescreen
    @Published var excelFormat: ExcelOutputFormat = .csv
    @Published var excelAllPages: Bool = true
    @Published var editPDFOperation: EditPDFOperation = .removeBlankPages
    @Published var editPDFRotation: Int = 90
    @Published var translateSourceLangID: String = ""
    @Published var translateTargetLangID: String = "es"
    @Published var jobs: [DocumentJob] = []
    @Published var cancellationRequested: Bool = false
    private var currentCancellationToken: CancellationToken?

    init(container: AppContainer = .live) {
        self.container = container
        loadSettings()
        jobs = container.jobStore.allJobs()
        requestNotificationPermission()
    }

    var moduleManifests: [ModuleManifest] {
        container.moduleRegistry.allManifests()
    }

    var selectedModule: ModuleManifest? {
        moduleManifests.first { $0.id == selectedModuleID }
    }

    var runButtonHelp: String {
        if isRunning { return "A conversion is already in progress." }
        if inputURL == nil { return "Choose an input file first." }
        if outputDirectory == nil { return "Choose an output folder first." }
        return "Start the conversion"
    }

    func setInput(url: URL) {
        guard let manifest = selectedModule else { return }
        let ext = url.pathExtension.lowercased()
        guard manifest.supportedInputTypes.contains(ext) else {
            statusMessage = "This file type (\(ext.uppercased())) is not supported by \(manifest.displayName)."
            return
        }
        inputURL = url
        lastReport = nil
        statusMessage = "Ready — \(url.lastPathComponent)"
        if outputDirectory == nil {
            outputDirectory = url.deletingLastPathComponent().appendingPathComponent(
                "\(url.deletingPathExtension().lastPathComponent)_output",
                isDirectory: true
            )
        }
    }

    func clearInput() {
        inputURL = nil
        lastReport = nil
        statusMessage = "Drop a file or click Choose File to get started."
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
        currentProgress = 0
        statusMessage = "Running \(selectedModule?.displayName ?? "feature")..."
        lastReport = nil
        let cancellationToken = CancellationToken()
        currentCancellationToken = cancellationToken

        let job = DocumentJob(
            moduleIdentifier: selectedModuleID,
            sourceURL: inputURL,
            outputURL: outputDirectory,
            status: .running,
            progress: 0.05,
            message: statusMessage
        )
        container.jobStore.enqueue(job)
        jobs = container.jobStore.allJobs()
        container.progressBus.publish(
            DocumentJobProgress(jobID: job.id, fractionCompleted: job.progress, statusMessage: job.message)
        )

        let moduleRunner = container.moduleRunner
        let moduleName = selectedModule?.displayName ?? selectedModuleID
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
                    self?.finishJob(jobID: job.id, report: report, moduleName: moduleName)
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
        statusMessage = "Cancellation requested..."
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
            setInput(url: selectedURL)
        }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.title = "Choose Output Folder"
        if let current = outputDirectory {
            panel.directoryURL = current.deletingLastPathComponent()
        }

        if panel.runModal() == .OK, let selectedURL = panel.url {
            outputDirectory = selectedURL
            statusMessage = "Output folder selected."
        }
    }

    private func settingsForSelectedModule() -> [String: String] {
        switch selectedModuleID {
        case "pdf_to_images":
            return ["dpi": String(pdfImageDPI), "format": pdfImageFormat.rawValue]
        case "txt_to_pdf":
            return ["fontSize": String(txtFontSize), "margin": String(txtMargin)]
        case "flatten_pdf":
            return ["preserveAnnotations": flattenPreserveAnnotations ? "true" : "false"]
        case "pdf_to_word":
            return ["pageBreaks": wordPageBreaks ? "true" : "false"]
        case "pdf_to_pptx":
            return ["includeImages": pptxIncludeImages ? "true" : "false",
                    "slideSize": pptxSlideSize.rawValue]
        case "pdf_to_excel":
            return ["format": excelFormat.rawValue, "allPages": excelAllPages ? "true" : "false"]
        case "edit_pdf":
            return ["operation": editPDFOperation.rawValue, "rotationDegrees": String(editPDFRotation)]
        case "translate_pdf":
            return ["sourceLanguageID": translateSourceLangID, "targetLanguageID": translateTargetLangID]
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
        if let pageBreaks = container.settingsStore.value(forKey: "wordPageBreaks") {
            wordPageBreaks = pageBreaks != "false"
        }
        if let includeImages = container.settingsStore.value(forKey: "pptxIncludeImages") {
            pptxIncludeImages = includeImages != "false"
        }
        if let sizeRaw = container.settingsStore.value(forKey: "pptxSlideSize"),
           let size = PDFToPPTXOptions.SlideSize(rawValue: sizeRaw) {
            pptxSlideSize = size
        }
        if let fmt = container.settingsStore.value(forKey: "excelFormat"),
           let parsedFmt = ExcelOutputFormat(rawValue: fmt) {
            excelFormat = parsedFmt
        }
        if let allPages = container.settingsStore.value(forKey: "excelAllPages") {
            excelAllPages = allPages != "false"
        }
        if let op = container.settingsStore.value(forKey: "editPDFOperation"),
           let parsedOp = EditPDFOperation(rawValue: op) {
            editPDFOperation = parsedOp
        }
        if let rot = container.settingsStore.value(forKey: "editPDFRotation"),
           let parsedRot = Int(rot) {
            editPDFRotation = parsedRot
        }
        if let src = container.settingsStore.value(forKey: "translateSourceLangID") {
            translateSourceLangID = src
        }
        if let tgt = container.settingsStore.value(forKey: "translateTargetLangID") {
            translateTargetLangID = tgt
        }
    }

    private func saveSettings() {
        container.settingsStore.setValue(pdfImageFormat.rawValue, forKey: "pdfImageFormat")
        container.settingsStore.setValue(String(pdfImageDPI), forKey: "pdfImageDPI")
        container.settingsStore.setValue(String(txtFontSize), forKey: "txtFontSize")
        container.settingsStore.setValue(String(txtMargin), forKey: "txtMargin")
        container.settingsStore.setValue(flattenPreserveAnnotations ? "true" : "false", forKey: "flattenPreserveAnnotations")
        container.settingsStore.setValue(wordPageBreaks ? "true" : "false", forKey: "wordPageBreaks")
        container.settingsStore.setValue(pptxIncludeImages ? "true" : "false", forKey: "pptxIncludeImages")
        container.settingsStore.setValue(pptxSlideSize.rawValue, forKey: "pptxSlideSize")
        container.settingsStore.setValue(excelFormat.rawValue, forKey: "excelFormat")
        container.settingsStore.setValue(excelAllPages ? "true" : "false", forKey: "excelAllPages")
        container.settingsStore.setValue(editPDFOperation.rawValue, forKey: "editPDFOperation")
        container.settingsStore.setValue(String(editPDFRotation), forKey: "editPDFRotation")
        container.settingsStore.setValue(translateSourceLangID, forKey: "translateSourceLangID")
        container.settingsStore.setValue(translateTargetLangID, forKey: "translateTargetLangID")
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
        currentProgress = progress
        container.jobStore.update(job)
        jobs = container.jobStore.allJobs()
        container.progressBus.publish(
            DocumentJobProgress(jobID: id, fractionCompleted: progress, statusMessage: message)
        )
    }

    private func finishJob(jobID: UUID, report: ModuleExecutionReport, moduleName: String) {
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
        sendCompletionNotification(moduleName: moduleName, summary: report.summary)
    }

    private func failJob(jobID: UUID, error: Error, wasCancelled: Bool) {
        let message = wasCancelled ? "Cancelled." : error.localizedDescription
        updateJob(
            id: jobID,
            status: wasCancelled ? .cancelled : .failed,
            progress: 0,
            message: message,
            resultURLs: []
        )
        currentCancellationToken = nil
        isRunning = false
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendCompletionNotification(moduleName: String, summary: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(moduleName) Complete"
        content.body = summary
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
