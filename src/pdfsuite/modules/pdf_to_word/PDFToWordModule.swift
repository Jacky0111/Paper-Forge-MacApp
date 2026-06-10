import AppKit
import Foundation
import PDFKit

struct PDFToWordOptions: Hashable {
    let pageBreaks: Bool
}

final class PDFToWordModule: ModulePerforming {
    let manifest = ModuleManifest(
        id: "pdf_to_word",
        displayName: "PDF to Word",
        category: "Convert",
        supportedInputTypes: ["pdf"],
        iconName: "doc.richtext",
        colorName: "indigo",
        moduleDescription: "Extract text and styles into an editable .docx file"
    )

    private let options: PDFToWordOptions

    init(options: PDFToWordOptions = PDFToWordOptions(pageBreaks: true)) {
        self.options = options
    }

    func execute(inputURL: URL, context: ModuleExecutionContext) throws -> ModuleExecutionReport {
        let renderer = PDFToWordRenderer()
        let outputURL = try renderer.render(
            pdfURL: inputURL,
            outputDirectory: context.outputDirectory,
            options: options,
            context: context
        )
        return ModuleExecutionReport(
            id: UUID(),
            moduleID: manifest.id,
            outputURLs: [outputURL],
            summary: "Created Word document from \(inputURL.lastPathComponent)."
        )
    }
}

// MARK: - Renderer

final class PDFToWordRenderer {
    func render(
        pdfURL: URL,
        outputDirectory: URL,
        options: PDFToWordOptions,
        context: ModuleExecutionContext
    ) throws -> URL {
        guard let document = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidInput("Unable to open the selected PDF.")
        }
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw DocumentError.processingFailed("The selected PDF does not contain any pages.")
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        context.reportProgress(0.05, "Reading PDF pages...")

        var allPageParagraphs: [[DocxParagraph]] = []
        for index in 0..<pageCount {
            try context.checkCancellation()
            context.reportProgress(0.05 + (Double(index) / Double(pageCount)) * 0.60,
                                   "Extracting page \(index + 1) of \(pageCount)...")
            guard let page = document.page(at: index) else { continue }
            allPageParagraphs.append(extractParagraphs(from: page))
        }

        context.reportProgress(0.70, "Building document structure...")
        let xml = buildDocumentXML(pages: allPageParagraphs, pageBreaks: options.pageBreaks)
        context.reportProgress(0.80, "Writing .docx package...")

        let outputURL = outputDirectory.appendingPathComponent(
            "\(pdfURL.deletingPathExtension().lastPathComponent).docx"
        )
        try packageDocx(documentXML: xml, to: outputURL)
        context.reportProgress(1.0, "Created Word document from \(pdfURL.lastPathComponent).")
        return outputURL
    }

    // MARK: - Text extraction

    private struct DocxRun {
        let text: String
        let bold: Bool
        let italic: Bool
        let fontSize: Int  // in half-points (Word units)
    }

    private struct DocxParagraph {
        let runs: [DocxRun]
        let isPageBreak: Bool

        static let pageBreak = DocxParagraph(runs: [], isPageBreak: true)
    }

    private func extractParagraphs(from page: PDFPage) -> [DocxParagraph] {
        guard let attrStr = page.attributedString, attrStr.length > 0 else {
            if let text = page.string, !text.isEmpty {
                let lines = text.components(separatedBy: "\n")
                return lines.map { line in
                    DocxParagraph(runs: [DocxRun(text: line, bold: false, italic: false, fontSize: 24)],
                                  isPageBreak: false)
                }
            }
            return []
        }

        // Collect runs with formatting, then split into paragraphs on newlines
        var flatRuns: [DocxRun] = []
        attrStr.enumerateAttributes(in: NSRange(location: 0, length: attrStr.length), options: []) { attrs, range, _ in
            let text = (attrStr.string as NSString).substring(with: range)
            var bold = false
            var italic = false
            var halfPoints = 24  // 12pt default
            if let font = attrs[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                bold = traits.contains(.bold)
                italic = traits.contains(.italic)
                halfPoints = max(Int((font.pointSize * 2).rounded()), 16)
            }
            flatRuns.append(DocxRun(text: text, bold: bold, italic: italic, fontSize: halfPoints))
        }

        // Merge adjacent runs with identical properties and split on newlines
        var paragraphs: [DocxParagraph] = []
        var currentRuns: [DocxRun] = []

        func flushParagraph() {
            paragraphs.append(DocxParagraph(runs: currentRuns, isPageBreak: false))
            currentRuns = []
        }

        for run in flatRuns {
            // Split this run's text on newlines
            let segments = run.text.components(separatedBy: "\n")
            for (i, segment) in segments.enumerated() {
                if !segment.isEmpty {
                    currentRuns.append(DocxRun(text: segment, bold: run.bold, italic: run.italic, fontSize: run.fontSize))
                }
                if i < segments.count - 1 {
                    flushParagraph()
                }
            }
        }
        flushParagraph()

        return paragraphs.filter { !$0.runs.isEmpty || $0.isPageBreak }
    }

    // MARK: - XML generation

    private func buildDocumentXML(pages: [[DocxParagraph]], pageBreaks: Bool) -> String {
        var body = ""
        for (pageIndex, paragraphs) in pages.enumerated() {
            if pageIndex > 0 && pageBreaks {
                // Page break paragraph
                body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
            }
            if paragraphs.isEmpty {
                body += "<w:p/>"
            }
            for paragraph in paragraphs {
                body += buildParagraphXML(paragraph)
            }
        }
        // Word requires at least one paragraph and a sectPr
        if body.isEmpty { body = "<w:p/>" }
        body += "<w:sectPr/>"

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>\(body)</w:body>
        </w:document>
        """
    }

    private func buildParagraphXML(_ paragraph: DocxParagraph) -> String {
        if paragraph.isPageBreak {
            return "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
        }
        var runs = ""
        for run in paragraph.runs {
            runs += buildRunXML(run)
        }
        return "<w:p>\(runs)</w:p>"
    }

    private func buildRunXML(_ run: DocxRun) -> String {
        var rPr = "<w:sz w:val=\"\(run.fontSize)\"/><w:szCs w:val=\"\(run.fontSize)\"/>"
        if run.bold { rPr += "<w:b/>" }
        if run.italic { rPr += "<w:i/>" }
        let escaped = xmlEscape(run.text)
        return "<w:r><w:rPr>\(rPr)</w:rPr><w:t xml:space=\"preserve\">\(escaped)</w:t></w:r>"
    }

    private func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - .docx packaging (ZIP)

    private func packageDocx(documentXML: String, to outputURL: URL) throws {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: tmpDir) }

        let relsDir = tmpDir.appendingPathComponent("_rels", isDirectory: true)
        let wordDir = tmpDir.appendingPathComponent("word", isDirectory: true)
        let wordRelsDir = wordDir.appendingPathComponent("_rels", isDirectory: true)
        for dir in [relsDir, wordDir, wordRelsDir] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """

        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """

        let docRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        </Relationships>
        """

        let utf8 = String.Encoding.utf8
        try contentTypes.write(to: tmpDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: utf8)
        try rootRels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: utf8)
        try documentXML.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: utf8)
        try docRels.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"), atomically: true, encoding: utf8)

        // Remove stale output if any
        try? fm.removeItem(at: outputURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", outputURL.path, "."]
        process.currentDirectoryURL = tmpDir

        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "unknown error"
            throw DocumentError.processingFailed("Failed to create .docx package: \(errMsg)")
        }

        guard fm.fileExists(atPath: outputURL.path) else {
            throw DocumentError.processingFailed("The .docx file was not created.")
        }
    }
}
