import AppKit
import CoreGraphics
import Foundation
import PDFKit

struct FlattenPDFOptions: Hashable {
    let preserveAnnotations: Bool
}

final class FlattenPDFModule: ModulePerforming {
    let manifest = ModuleManifest(
        id: "flatten_pdf",
        displayName: "Flatten PDF",
        category: "Optimize",
        supportedInputTypes: ["pdf"],
        iconName: "arrow.2.squarepath",
        colorName: "orange",
        moduleDescription: "Merge annotations and form fields into the page"
    )

    private let options: FlattenPDFOptions

    init(options: FlattenPDFOptions = FlattenPDFOptions(preserveAnnotations: false)) {
        self.options = options
    }

    func execute(inputURL: URL, context: ModuleExecutionContext) throws -> ModuleExecutionReport {
        let renderer = FlattenPDFRenderer()
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
            summary: "Created flattened PDF from \(inputURL.lastPathComponent)."
        )
    }
}

final class FlattenPDFRenderer {
    func render(
        pdfURL: URL,
        outputDirectory: URL,
        options: FlattenPDFOptions,
        context: ModuleExecutionContext
    ) throws -> URL {
        guard let document = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidInput("Unable to open the selected PDF.")
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw DocumentError.processingFailed("The selected PDF does not contain any pages.")
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let outputURL = outputDirectory.appendingPathComponent(
            "\(pdfURL.deletingPathExtension().lastPathComponent)_flattened.pdf"
        )

        guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
            throw DocumentError.processingFailed("Unable to create the flattened PDF output file.")
        }

        guard let pdfContext = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw DocumentError.processingFailed("Unable to create the flattened PDF drawing context.")
        }

        context.reportProgress(0.05, "Preparing flattened PDF...")
        for index in 0..<pageCount {
            try context.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            let pageNumber = index + 1
            context.reportProgress(Double(index) / Double(pageCount), "Flattening page \(pageNumber) of \(pageCount)...")
            let pageBounds = page.bounds(for: .mediaBox)
            var mediaBox = CGRect(origin: .zero, size: pageBounds.size)

            pdfContext.beginPDFPage([kCGPDFContextMediaBox as String: NSData(bytes: &mediaBox, length: MemoryLayout<CGRect>.size)] as CFDictionary)
            draw(page: page, pageBounds: pageBounds, options: options, in: pdfContext)
            pdfContext.endPDFPage()
            context.reportProgress(Double(pageNumber) / Double(pageCount), "Flattened page \(pageNumber) of \(pageCount).")
        }

        pdfContext.closePDF()
        context.reportProgress(1, "Created flattened PDF from \(pdfURL.lastPathComponent).")
        return outputURL
    }

    private func draw(page: PDFPage, pageBounds: CGRect, options: FlattenPDFOptions, in context: CGContext) {
        context.saveGState()
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: pageBounds.size))

        context.translateBy(x: -pageBounds.origin.x, y: -pageBounds.origin.y)
        page.draw(with: .mediaBox, to: context)

        if options.preserveAnnotations {
            for annotation in page.annotations {
                annotation.draw(with: .mediaBox, in: context)
            }
        }

        context.restoreGState()
    }
}
