import AppKit
import CoreGraphics
import CoreText
import Foundation

struct TxtToPDFOptions: Hashable {
    let fontSize: Double
    let margin: Double
    let pageSize: CGSize
}

final class TxtToPDFModule: ModulePerforming {
    let manifest = ModuleManifest(
        id: "txt_to_pdf",
        displayName: "TXT to PDF",
        category: "Convert",
        supportedInputTypes: ["txt"]
    )

    private let options: TxtToPDFOptions

    init(options: TxtToPDFOptions = TxtToPDFOptions(fontSize: 12, margin: 48, pageSize: CGSize(width: 595, height: 842))) {
        self.options = options
    }

    func execute(inputURL: URL, context: ModuleExecutionContext) throws -> ModuleExecutionReport {
        let renderer = TxtToPDFRenderer()
        let outputURL = try renderer.render(
            textURL: inputURL,
            outputDirectory: context.outputDirectory,
            options: options,
            context: context
        )
        return ModuleExecutionReport(
            id: UUID(),
            moduleID: manifest.id,
            outputURLs: [outputURL],
            summary: "Created PDF from \(inputURL.lastPathComponent)."
        )
    }
}

final class TxtToPDFRenderer {
    func render(
        textURL: URL,
        outputDirectory: URL,
        options: TxtToPDFOptions,
        context: ModuleExecutionContext
    ) throws -> URL {
        try context.checkCancellation()
        context.reportProgress(0.1, "Reading text file...")
        let text = try readTextFile(at: textURL)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        context.reportProgress(0.25, "Preparing PDF layout...")

        let outputURL = outputDirectory.appendingPathComponent(
            "\(textURL.deletingPathExtension().lastPathComponent).pdf"
        )

        let pageBounds = CGRect(origin: .zero, size: options.pageSize)
        let margin = CGFloat(options.margin)
        let textBounds = pageBounds.insetBy(dx: margin, dy: margin)

        guard textBounds.width > 0, textBounds.height > 0 else {
            throw DocumentError.invalidInput("TXT to PDF margins are too large for the selected page size.")
        }

        guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
            throw DocumentError.processingFailed("Unable to create the PDF output file.")
        }

        var mediaBox = pageBounds
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw DocumentError.processingFailed("Unable to create the PDF drawing context.")
        }

        let attributedText = NSAttributedString(
            string: text.isEmpty ? " " : text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: CGFloat(options.fontSize), weight: .regular),
                .foregroundColor: NSColor.black
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        var currentRange = CFRange(location: 0, length: 0)
        var pageNumber = 0

        repeat {
            try context.checkCancellation()
            pageNumber += 1
            context.reportProgress(0.25, "Writing page \(pageNumber)...")
            pdfContext.beginPDFPage(nil)
            drawPageText(
                framesetter: framesetter,
                currentRange: &currentRange,
                textBounds: textBounds,
                pageHeight: pageBounds.height,
                in: pdfContext
            )
            pdfContext.endPDFPage()
            let textProgress = Double(currentRange.location) / Double(max(attributedText.length, 1))
            context.reportProgress(0.25 + (textProgress * 0.7), "Wrote page \(pageNumber).")
        } while currentRange.location < attributedText.length

        pdfContext.closePDF()
        context.reportProgress(1, "Created PDF from \(textURL.lastPathComponent).")
        return outputURL
    }

    private func readTextFile(at url: URL) throws -> String {
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }

        do {
            return try String(contentsOf: url, encoding: .isoLatin1)
        } catch {
            throw DocumentError.invalidInput("Unable to read the selected text file.")
        }
    }

    private func drawPageText(
        framesetter: CTFramesetter,
        currentRange: inout CFRange,
        textBounds: CGRect,
        pageHeight: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)

        let path = CGMutablePath()
        path.addRect(textBounds)
        let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
        CTFrameDraw(frame, context)

        let visibleRange = CTFrameGetVisibleStringRange(frame)
        currentRange.location += max(visibleRange.length, 1)
        currentRange.length = 0
        context.restoreGState()
    }
}
