import AppKit
import CoreGraphics
import Foundation
import PDFKit

enum PDFImageFormat: String, CaseIterable, Hashable {
    case png
    case jpg
    case tiff

    var fileExtension: String {
        rawValue
    }
}

struct PDFToImagesOptions: Hashable {
    let dpi: Int
    let format: PDFImageFormat
}

final class PDFToImagesModule: ModulePerforming {
    let manifest = ModuleManifest(
        id: "pdf_to_images",
        displayName: "PDF to Images",
        category: "Convert",
        supportedInputTypes: ["pdf"]
    )

    private let options: PDFToImagesOptions

    init(options: PDFToImagesOptions = PDFToImagesOptions(dpi: 200, format: .png)) {
        self.options = options
    }

    func execute(inputURL: URL, context: ModuleExecutionContext) throws -> ModuleExecutionReport {
        let renderer = PDFToImagesRenderer()
        let outputURLs = try renderer.render(
            pdfURL: inputURL,
            outputDirectory: context.outputDirectory,
            options: options,
            context: context
        )
        return ModuleExecutionReport(
            id: UUID(),
            moduleID: manifest.id,
            outputURLs: outputURLs,
            summary: "Rendered \(outputURLs.count) page image(s)."
        )
    }
}

final class PDFToImagesRenderer {
    func render(
        pdfURL: URL,
        outputDirectory: URL,
        options: PDFToImagesOptions,
        context: ModuleExecutionContext
    ) throws -> [URL] {
        guard let document = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidInput("Unable to open the selected PDF.")
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let pageCount = document.pageCount
        var outputURLs: [URL] = []
        context.reportProgress(0.05, "Preparing PDF pages...")

        for index in 0..<pageCount {
            try context.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            let pageNumber = index + 1
            context.reportProgress(Double(index) / Double(pageCount), "Rendering page \(pageNumber) of \(pageCount)...")
            let outputURL = outputDirectory.appendingPathComponent(
                "\(pdfURL.deletingPathExtension().lastPathComponent)_page_\(String(format: "%03d", pageNumber)).\(options.format.fileExtension)"
            )

            let pageBounds = page.bounds(for: .mediaBox)
            let scale = CGFloat(options.dpi) / 72.0
            let targetSize = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
            let pixelWidth = max(Int(targetSize.width.rounded(.up)), 1)
            let pixelHeight = max(Int(targetSize.height.rounded(.up)), 1)

            guard let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
                throw DocumentError.processingFailed("Unable to create an image buffer for page \(pageNumber).")
            }

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext
            graphicsContext.cgContext.setFillColor(NSColor.white.cgColor)
            graphicsContext.cgContext.fill(CGRect(origin: .zero, size: targetSize))
            graphicsContext.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: graphicsContext.cgContext)
            NSGraphicsContext.restoreGraphicsState()

            let data: Data?
            switch options.format {
            case .png:
                data = bitmap.representation(using: .png, properties: [:])
            case .jpg:
                data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
            case .tiff:
                data = bitmap.representation(using: .tiff, properties: [:])
            }

            guard let data else {
                throw DocumentError.processingFailed("Unable to write image data for page \(pageNumber).")
            }

            try data.write(to: outputURL, options: [.atomic])
            outputURLs.append(outputURL)
            context.reportProgress(Double(pageNumber) / Double(pageCount), "Rendered page \(pageNumber) of \(pageCount).")
        }

        if outputURLs.isEmpty {
            throw DocumentError.processingFailed("The PDF did not produce any images.")
        }

        context.reportProgress(1, "Rendered \(outputURLs.count) page image(s).")
        return outputURLs
    }
}
