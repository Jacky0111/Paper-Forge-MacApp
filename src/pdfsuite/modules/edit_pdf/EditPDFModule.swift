import AppKit
import Foundation
import PDFKit

enum EditPDFOperation: String, CaseIterable, Hashable {
    case removeBlankPages = "remove_blank"
    case rotateAll        = "rotate_all"
    case removeFirstPage  = "remove_first"
    case removeLastPage   = "remove_last"
}

struct EditPDFOptions: Hashable {
    let operation: EditPDFOperation
    let rotationDegrees: Int  // used only for rotateAll: 90, 180, 270
}

final class EditPDFModule: ModulePerforming {
    let manifest = ModuleManifest(
        id: "edit_pdf",
        displayName: "Edit PDF",
        category: "Optimize",
        supportedInputTypes: ["pdf"],
        iconName: "pencil.and.scribble",
        colorName: "purple",
        moduleDescription: "Remove or rotate pages with simple non-destructive edits"
    )

    private let options: EditPDFOptions

    init(options: EditPDFOptions = EditPDFOptions(operation: .removeBlankPages, rotationDegrees: 90)) {
        self.options = options
    }

    func execute(inputURL: URL, context: ModuleExecutionContext) throws -> ModuleExecutionReport {
        let renderer = EditPDFRenderer()
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
            summary: summaryMessage(for: options.operation, inputName: inputURL.lastPathComponent)
        )
    }

    private func summaryMessage(for operation: EditPDFOperation, inputName: String) -> String {
        switch operation {
        case .removeBlankPages: return "Removed blank pages from \(inputName)."
        case .rotateAll:        return "Rotated all pages \(options.rotationDegrees)° in \(inputName)."
        case .removeFirstPage:  return "Removed first page from \(inputName)."
        case .removeLastPage:   return "Removed last page from \(inputName)."
        }
    }
}

// MARK: - Renderer

final class EditPDFRenderer {
    func render(
        pdfURL: URL,
        outputDirectory: URL,
        options: EditPDFOptions,
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

        let suffix = options.operation.rawValue
        let outputURL = outputDirectory.appendingPathComponent(
            "\(pdfURL.deletingPathExtension().lastPathComponent)_\(suffix).pdf"
        )

        context.reportProgress(0.10, "Analysing PDF...")

        switch options.operation {
        case .removeBlankPages:
            try removeBlankPages(from: document, pageCount: pageCount, to: outputURL, context: context)
        case .rotateAll:
            try rotateAllPages(in: document, pageCount: pageCount, degrees: options.rotationDegrees, to: outputURL, context: context)
        case .removeFirstPage:
            guard pageCount > 1 else {
                throw DocumentError.processingFailed("Cannot remove the only page in this PDF.")
            }
            try removePages(indices: [0], from: document, pageCount: pageCount, to: outputURL, context: context)
        case .removeLastPage:
            guard pageCount > 1 else {
                throw DocumentError.processingFailed("Cannot remove the only page in this PDF.")
            }
            try removePages(indices: [pageCount - 1], from: document, pageCount: pageCount, to: outputURL, context: context)
        }

        context.reportProgress(1.0, "Saved edited PDF.")
        return outputURL
    }

    // MARK: - Operations

    private func removeBlankPages(
        from document: PDFDocument,
        pageCount: Int,
        to outputURL: URL,
        context: ModuleExecutionContext
    ) throws {
        var blankIndices: [Int] = []
        for i in 0..<pageCount {
            try context.checkCancellation()
            context.reportProgress(0.10 + (Double(i) / Double(pageCount)) * 0.70,
                                   "Checking page \(i + 1) of \(pageCount)...")
            if let page = document.page(at: i), isBlank(page: page) {
                blankIndices.append(i)
            }
        }
        if blankIndices.isEmpty {
            throw DocumentError.processingFailed("No blank pages were found in this PDF.")
        }
        try removePages(indices: blankIndices, from: document, pageCount: pageCount, to: outputURL, context: context)
    }

    private func removePages(
        indices: [Int],
        from document: PDFDocument,
        pageCount: Int,
        to outputURL: URL,
        context: ModuleExecutionContext
    ) throws {
        let removeSet = Set(indices)
        let output = PDFDocument()
        var insertIndex = 0
        for i in 0..<pageCount {
            if removeSet.contains(i) { continue }
            guard let page = document.page(at: i) else { continue }
            output.insert(page, at: insertIndex)
            insertIndex += 1
        }
        guard output.pageCount > 0 else {
            throw DocumentError.processingFailed("All pages would be removed. Aborting.")
        }
        context.reportProgress(0.85, "Writing edited PDF...")
        guard output.write(to: outputURL) else {
            throw DocumentError.processingFailed("Failed to write the edited PDF.")
        }
    }

    private func rotateAllPages(
        in document: PDFDocument,
        pageCount: Int,
        degrees: Int,
        to outputURL: URL,
        context: ModuleExecutionContext
    ) throws {
        let output = PDFDocument()
        var insertIndex = 0
        for i in 0..<pageCount {
            try context.checkCancellation()
            context.reportProgress(0.10 + (Double(i) / Double(pageCount)) * 0.75,
                                   "Rotating page \(i + 1) of \(pageCount)...")
            guard let page = document.page(at: i) else { continue }
            page.rotation = (page.rotation + degrees) % 360
            output.insert(page, at: insertIndex)
            insertIndex += 1
        }
        context.reportProgress(0.90, "Writing rotated PDF...")
        guard output.write(to: outputURL) else {
            throw DocumentError.processingFailed("Failed to write the rotated PDF.")
        }
    }

    // MARK: - Blank page detection

    private func isBlank(page: PDFPage, charThreshold: Int = 5, coverageThreshold: Double = 0.002) -> Bool {
        // Text check: fewer than threshold non-whitespace characters
        let text = page.string ?? ""
        let nonWhitespace = text.filter { !$0.isWhitespace }.count
        if nonWhitespace >= charThreshold { return false }

        // Pixel coverage check: render at low resolution and measure non-white pixel ratio
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 0.5   // 36dpi — fast, good enough for blank detection
        let w = max(Int((bounds.width * scale).rounded()), 1)
        let h = max(Int((bounds.height * scale).rounded()), 1)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
            bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nonWhitespace == 0
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.cgContext.setFillColor(NSColor.white.cgColor)
        ctx.cgContext.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.cgContext.translateBy(x: 0, y: CGFloat(h))
        ctx.cgContext.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: ctx.cgContext)
        NSGraphicsContext.restoreGraphicsState()

        var nonWhitePixels = 0
        let totalPixels = w * h
        for y in 0..<h {
            for x in 0..<w {
                let color = bitmap.colorAt(x: x, y: y)
                let brightness = (color?.brightnessComponent ?? 1.0)
                if brightness < 0.97 { nonWhitePixels += 1 }
            }
        }
        let coverage = Double(nonWhitePixels) / Double(totalPixels)
        return coverage < coverageThreshold
    }
}
