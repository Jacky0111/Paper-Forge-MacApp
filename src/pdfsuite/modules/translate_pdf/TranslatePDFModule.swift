import AppKit
import CoreGraphics
import CoreText
import Foundation
import PDFKit
import Translation

// MARK: - Supported languages

struct TranslationLanguage: Hashable, Identifiable {
    let id: String          // BCP-47 e.g. "en", "zh-Hans"
    let displayName: String

    static let autoDetect = TranslationLanguage(id: "", displayName: "Auto-detect")

    static let all: [TranslationLanguage] = [
        .init(id: "ar",      displayName: "Arabic"),
        .init(id: "zh-Hans", displayName: "Chinese (Simplified)"),
        .init(id: "zh-Hant", displayName: "Chinese (Traditional)"),
        .init(id: "nl",      displayName: "Dutch"),
        .init(id: "en",      displayName: "English"),
        .init(id: "fr",      displayName: "French"),
        .init(id: "de",      displayName: "German"),
        .init(id: "id",      displayName: "Indonesian"),
        .init(id: "it",      displayName: "Italian"),
        .init(id: "ja",      displayName: "Japanese"),
        .init(id: "ko",      displayName: "Korean"),
        .init(id: "pl",      displayName: "Polish"),
        .init(id: "pt",      displayName: "Portuguese"),
        .init(id: "ru",      displayName: "Russian"),
        .init(id: "es",      displayName: "Spanish"),
        .init(id: "th",      displayName: "Thai"),
        .init(id: "tr",      displayName: "Turkish"),
        .init(id: "uk",      displayName: "Ukrainian"),
        .init(id: "vi",      displayName: "Vietnamese"),
    ]
}

// MARK: - Options

struct TranslatePDFOptions: Hashable {
    let sourceLanguageID: String   // "" = auto-detect
    let targetLanguageID: String
}

// MARK: - Module

final class TranslatePDFModule: ModulePerforming {
    let manifest = ModuleManifest(
        id: "translate_pdf",
        displayName: "Translate PDF",
        category: "Convert",
        supportedInputTypes: ["pdf"],
        iconName: "character.bubble",
        colorName: "mint",
        moduleDescription: "Translate PDF text into another language using Apple on-device AI"
    )

    private let options: TranslatePDFOptions

    init(options: TranslatePDFOptions = TranslatePDFOptions(sourceLanguageID: "", targetLanguageID: "es")) {
        self.options = options
    }

    func execute(inputURL: URL, context: ModuleExecutionContext) throws -> ModuleExecutionReport {
        guard #available(macOS 26.0, *) else {
            throw DocumentError.processingFailed("PDF Translation requires macOS 15 or later.")
        }
        guard !options.targetLanguageID.isEmpty else {
            throw DocumentError.invalidInput("Choose a target language before running.")
        }

        let renderer = TranslatePDFRenderer()
        let outputURL = try renderer.render(
            pdfURL: inputURL,
            outputDirectory: context.outputDirectory,
            options: options,
            context: context
        )
        let targetName = TranslationLanguage.all
            .first { $0.id == options.targetLanguageID }?.displayName ?? options.targetLanguageID
        return ModuleExecutionReport(
            id: UUID(),
            moduleID: manifest.id,
            outputURLs: [outputURL],
            summary: "Translated \(inputURL.lastPathComponent) to \(targetName)."
        )
    }
}

// MARK: - Renderer

final class TranslatePDFRenderer {
    func render(
        pdfURL: URL,
        outputDirectory: URL,
        options: TranslatePDFOptions,
        context: ModuleExecutionContext
    ) throws -> URL {
        guard #available(macOS 26.0, *) else {
            throw DocumentError.processingFailed("PDF Translation requires macOS 15 or later.")
        }

        guard let document = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidInput("Unable to open the selected PDF.")
        }
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw DocumentError.processingFailed("The selected PDF does not contain any pages.")
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        context.reportProgress(0.05, "Extracting text...")

        // Extract text per page
        var pageTexts: [String] = []
        for i in 0..<pageCount {
            let text = document.page(at: i)?.string ?? ""
            pageTexts.append(text)
        }

        context.reportProgress(0.20, "Translating with Apple on-device AI...")

        // Translate all non-empty pages in one batch
        let nonEmpty = pageTexts.enumerated().filter { !$0.element.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var translatedMap: [Int: String] = [:]

        if !nonEmpty.isEmpty {
            let translatedTexts = try translateBatch(
                texts: nonEmpty.map { $0.element },
                sourceID: options.sourceLanguageID,
                targetID: options.targetLanguageID,
                progressCallback: { fraction in
                    let overall = 0.20 + fraction * 0.55
                    context.reportProgress(overall, "Translating...")
                }
            )
            for (offset, (pageIndex, _)) in nonEmpty.enumerated() {
                translatedMap[pageIndex] = offset < translatedTexts.count ? translatedTexts[offset] : pageTexts[pageIndex]
            }
        }

        // Merge back: translated where available, original otherwise
        let finalTexts = (0..<pageCount).map { translatedMap[$0] ?? pageTexts[$0] }

        context.reportProgress(0.80, "Rebuilding PDF...")

        let targetLangName = TranslationLanguage.all
            .first { $0.id == options.targetLanguageID }?.displayName
            .lowercased().replacingOccurrences(of: " ", with: "_") ?? options.targetLanguageID

        let outputURL = outputDirectory.appendingPathComponent(
            "\(pdfURL.deletingPathExtension().lastPathComponent)_\(targetLangName).pdf"
        )

        try buildPDF(pages: finalTexts, to: outputURL)
        context.reportProgress(1.0, "Translated PDF saved.")
        return outputURL
    }

    // MARK: - Translation (async bridged to sync via semaphore)

    @available(macOS 26.0, *)
    private func translateBatch(
        texts: [String],
        sourceID: String,
        targetID: String,
        progressCallback: @escaping (Double) -> Void
    ) throws -> [String] {
        let source: Locale.Language? = sourceID.isEmpty ? nil : Locale.Language(identifier: sourceID)
        let target = Locale.Language(identifier: targetID)

        var results: [String] = []
        var thrownError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                let session = TranslationSession(installedSource: source ?? Locale.Language(identifier: "en"), target: target)
                let requests = texts.enumerated().map { i, text in
                    TranslationSession.Request(sourceText: text, clientIdentifier: "\(i)")
                }
                let responses = try await session.translations(from: requests)
                // Re-order responses by clientIdentifier to preserve page order
                var ordered = [String](repeating: "", count: texts.count)
                for response in responses {
                    if let idStr = response.clientIdentifier, let idx = Int(idStr), idx < ordered.count {
                        ordered[idx] = response.targetText
                    }
                }
                // Fill any gaps with originals
                for i in 0..<texts.count where ordered[i].isEmpty {
                    ordered[i] = texts[i]
                }
                results = ordered
                progressCallback(1.0)
            } catch {
                thrownError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let err = thrownError { throw err }
        return results
    }

    // MARK: - PDF rebuilding (CoreText, same approach as TxtToPDF)

    private func buildPDF(pages: [String], to outputURL: URL) throws {
        let pageSize = CGSize(width: 595, height: 842)  // A4
        let margin: CGFloat = 48
        let pageBounds = CGRect(origin: .zero, size: pageSize)
        let textBounds = pageBounds.insetBy(dx: margin, dy: margin)

        guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
            throw DocumentError.processingFailed("Unable to create output PDF.")
        }
        var mediaBox = pageBounds
        guard let pdfCtx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw DocumentError.processingFailed("Unable to create PDF context.")
        }

        for pageText in pages {
            let text = pageText.isEmpty ? " " : pageText
            let attrStr = NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.black
                ]
            )
            let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
            var range = CFRange(location: 0, length: 0)

            repeat {
                pdfCtx.beginPDFPage(nil)
                pdfCtx.saveGState()
                pdfCtx.textMatrix = .identity
                pdfCtx.translateBy(x: 0, y: pageSize.height)
                pdfCtx.scaleBy(x: 1, y: -1)
                let path = CGMutablePath()
                path.addRect(textBounds)
                let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
                CTFrameDraw(frame, pdfCtx)
                let visible = CTFrameGetVisibleStringRange(frame)
                range.location += max(visible.length, 1)
                range.length = 0
                pdfCtx.restoreGState()
                pdfCtx.endPDFPage()
            } while range.location < attrStr.length
        }

        pdfCtx.closePDF()
    }
}
