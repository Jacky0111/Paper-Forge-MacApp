import Foundation

@main
struct Phase1SmokeTests {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let outputRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("paper-forge-phase1-smoke", isDirectory: true)

        try? FileManager.default.removeItem(at: outputRoot)
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)

        try testTxtToPDF(root: root, outputRoot: outputRoot)
        try testPDFToImages(root: root, outputRoot: outputRoot)
        try testFlattenPDF(root: root, outputRoot: outputRoot)

        print("Phase 1 smoke tests passed")
    }

    private static func testTxtToPDF(root: URL, outputRoot: URL) throws {
        let input = outputRoot.appendingPathComponent("sample.txt")
        try "Paper Forge\nPhase 1 smoke test\n".write(to: input, atomically: true, encoding: .utf8)

        let output = outputRoot.appendingPathComponent("txt-to-pdf", isDirectory: true)
        let report = try TxtToPDFModule().execute(
            inputURL: input,
            context: ModuleExecutionContext(outputDirectory: output, settings: [:])
        )

        try assertExistingOutputs(report.outputURLs, label: "TXT to PDF")
    }

    private static func testPDFToImages(root: URL, outputRoot: URL) throws {
        let input = root.appendingPathComponent("work/testdata/sample.pdf")
        let output = outputRoot.appendingPathComponent("pdf-to-images", isDirectory: true)
        let report = try PDFToImagesModule(options: PDFToImagesOptions(dpi: 72, format: .png)).execute(
            inputURL: input,
            context: ModuleExecutionContext(outputDirectory: output, settings: [:])
        )

        try assertExistingOutputs(report.outputURLs, label: "PDF to Images")
    }

    private static func testFlattenPDF(root: URL, outputRoot: URL) throws {
        let input = root.appendingPathComponent("work/testdata/sample.pdf")
        let output = outputRoot.appendingPathComponent("flatten-pdf", isDirectory: true)
        let report = try FlattenPDFModule().execute(
            inputURL: input,
            context: ModuleExecutionContext(outputDirectory: output, settings: [:])
        )

        try assertExistingOutputs(report.outputURLs, label: "Flatten PDF")
    }

    private static func assertExistingOutputs(_ urls: [URL], label: String) throws {
        guard !urls.isEmpty else {
            throw SmokeTestError.failed("\(label) did not produce outputs.")
        }

        for url in urls {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw SmokeTestError.failed("\(label) output is missing: \(url.path)")
            }
        }
    }
}

enum SmokeTestError: Error, LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}
