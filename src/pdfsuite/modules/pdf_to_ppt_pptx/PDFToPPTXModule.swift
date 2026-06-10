import AppKit
import CoreGraphics
import Foundation
import PDFKit

struct PDFToPPTXOptions: Hashable {
    let includeImages: Bool  // render each page as an image embedded in the slide
    let slideSize: SlideSize

    enum SlideSize: String, CaseIterable, Hashable {
        case widescreen = "widescreen"   // 13.33 x 7.5 in
        case standard = "standard"       // 10 x 7.5 in

        var widthEMU: Int {
            switch self {
            case .widescreen: return 9_144_000
            case .standard:  return 6_858_000
            }
        }
        var heightEMU: Int { 6_858_000 } // 7.5 inches in both
    }
}

final class PDFToPPTXModule: ModulePerforming {
    let manifest = ModuleManifest(
        id: "pdf_to_pptx",
        displayName: "PDF to PPTX",
        category: "Convert",
        supportedInputTypes: ["pdf"],
        iconName: "play.rectangle",
        colorName: "pink",
        moduleDescription: "Convert each PDF page into a PowerPoint slide"
    )

    private let options: PDFToPPTXOptions

    init(options: PDFToPPTXOptions = PDFToPPTXOptions(includeImages: true, slideSize: .widescreen)) {
        self.options = options
    }

    func execute(inputURL: URL, context: ModuleExecutionContext) throws -> ModuleExecutionReport {
        let renderer = PDFToPPTXRenderer()
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
            summary: "Created presentation from \(inputURL.lastPathComponent)."
        )
    }
}

// MARK: - Renderer

final class PDFToPPTXRenderer {
    func render(
        pdfURL: URL,
        outputDirectory: URL,
        options: PDFToPPTXOptions,
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
        context.reportProgress(0.05, "Preparing slides...")

        let outputURL = outputDirectory.appendingPathComponent(
            "\(pdfURL.deletingPathExtension().lastPathComponent).pptx"
        )

        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: tmpDir) }

        // PPTX directory structure
        let relsDir    = tmpDir.appendingPathComponent("_rels")
        let pptDir     = tmpDir.appendingPathComponent("ppt")
        let slidesDir  = pptDir.appendingPathComponent("slides")
        let slideRels  = slidesDir.appendingPathComponent("_rels")
        let mediaDir   = pptDir.appendingPathComponent("media")
        let slideLayouts = pptDir.appendingPathComponent("slideLayouts")
        let slideMasters = pptDir.appendingPathComponent("slideMasters")

        for dir in [relsDir, slidesDir, slideRels, mediaDir, slideLayouts, slideMasters] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Render page images (PNG) for embedding
        var slideImageNames: [String] = []
        if options.includeImages {
            for index in 0..<pageCount {
                try context.checkCancellation()
                context.reportProgress(
                    0.05 + (Double(index) / Double(pageCount)) * 0.60,
                    "Rendering page \(index + 1) of \(pageCount)..."
                )
                guard let page = document.page(at: index) else { continue }
                let imageName = "slide\(index + 1).png"
                let imageURL = mediaDir.appendingPathComponent(imageName)
                try renderPageImage(page: page, to: imageURL, dpi: 150)
                slideImageNames.append(imageName)
            }
        }

        context.reportProgress(0.70, "Writing PPTX structure...")

        // Write all XML components
        try writePackageFiles(
            to: tmpDir,
            relsDir: relsDir,
            pptDir: pptDir,
            slidesDir: slidesDir,
            slideRels: slideRels,
            slideLayouts: slideLayouts,
            slideMasters: slideMasters,
            pageCount: pageCount,
            document: document,
            slideImageNames: slideImageNames,
            options: options
        )

        context.reportProgress(0.88, "Packaging presentation...")
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
            throw DocumentError.processingFailed("Failed to create .pptx package: \(errMsg)")
        }

        guard fm.fileExists(atPath: outputURL.path) else {
            throw DocumentError.processingFailed("The .pptx file was not created.")
        }

        context.reportProgress(1.0, "Created presentation from \(pdfURL.lastPathComponent).")
        return outputURL
    }

    // MARK: - Page image rendering

    private func renderPageImage(page: PDFPage, to outputURL: URL, dpi: Int) throws {
        let pageBounds = page.bounds(for: .mediaBox)
        let scale = CGFloat(dpi) / 72.0
        let targetSize = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
        let pixelWidth  = max(Int(targetSize.width.rounded(.up)), 1)
        let pixelHeight = max(Int(targetSize.height.rounded(.up)), 1)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelWidth, pixelsHigh: pixelHeight,
            bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw DocumentError.processingFailed("Unable to create image buffer.")
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.cgContext.setFillColor(NSColor.white.cgColor)
        graphicsContext.cgContext.fill(CGRect(origin: .zero, size: targetSize))
        graphicsContext.cgContext.translateBy(x: 0, y: targetSize.height)
        graphicsContext.cgContext.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: graphicsContext.cgContext)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw DocumentError.processingFailed("Unable to encode slide image.")
        }
        try data.write(to: outputURL, options: [.atomic])
    }

    // MARK: - PPTX XML assembly

    private func writePackageFiles(
        to tmpDir: URL,
        relsDir: URL,
        pptDir: URL,
        slidesDir: URL,
        slideRels: URL,
        slideLayouts: URL,
        slideMasters: URL,
        pageCount: Int,
        document: PDFDocument,
        slideImageNames: [String],
        options: PDFToPPTXOptions
    ) throws {
        let utf8 = String.Encoding.utf8
        let w = options.slideSize.widthEMU
        let h = options.slideSize.heightEMU

        // [Content_Types].xml
        var overrides = ""
        for i in 1...pageCount {
            overrides += """
            \n  <Override PartName="/ppt/slides/slide\(i).xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
            """
        }
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Default Extension="png" ContentType="image/png"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
          <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
          <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>\(overrides)
        </Types>
        """
        try contentTypes.write(to: tmpDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: utf8)

        // _rels/.rels
        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
        """
        try rootRels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: utf8)

        // ppt/_rels/presentation.xml.rels
        let pptRelsDir = pptDir.appendingPathComponent("_rels")
        try FileManager.default.createDirectory(at: pptRelsDir, withIntermediateDirectories: true)
        var presRelEntries = """
          <Relationship Id="rIdMaster1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
        """
        for i in 1...pageCount {
            presRelEntries += """
            \n  <Relationship Id="rId\(i)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide\(i).xml"/>
            """
        }
        let presRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(presRelEntries)
        </Relationships>
        """
        try presRels.write(to: pptRelsDir.appendingPathComponent("presentation.xml.rels"), atomically: true, encoding: utf8)

        // ppt/presentation.xml
        var sldIdList = ""
        for i in 1...pageCount {
            sldIdList += "<p:sldId id=\"\(256 + i)\" r:id=\"rId\(i)\"/>"
        }
        let presentation = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                        saveSubsetFonts="1">
          <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rIdMaster1"/></p:sldMasterIdLst>
          <p:sldIdLst>\(sldIdList)</p:sldIdLst>
          <p:sldSz cx="\(w)" cy="\(h)" type="custom"/>
          <p:notesSz cx="6858000" cy="9144000"/>
        </p:presentation>
        """
        try presentation.write(to: pptDir.appendingPathComponent("presentation.xml"), atomically: true, encoding: utf8)

        // Minimal slide master
        let masterXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                     xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                     xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>
          <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
          <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rIdLayout1"/></p:sldLayoutIdLst>
        </p:sldMaster>
        """
        try masterXML.write(to: slideMasters.appendingPathComponent("slideMaster1.xml"), atomically: true, encoding: utf8)

        let masterRelsDir = slideMasters.appendingPathComponent("_rels")
        try FileManager.default.createDirectory(at: masterRelsDir, withIntermediateDirectories: true)
        let masterRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rIdLayout1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
        </Relationships>
        """
        try masterRels.write(to: masterRelsDir.appendingPathComponent("slideMaster1.xml.rels"), atomically: true, encoding: utf8)

        // Minimal slide layout
        let layoutXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                     xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                     xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" type="blank" preserve="1">
          <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>
        </p:sldLayout>
        """
        try layoutXML.write(to: slideLayouts.appendingPathComponent("slideLayout1.xml"), atomically: true, encoding: utf8)

        let layoutRelsDir = slideLayouts.appendingPathComponent("_rels")
        try FileManager.default.createDirectory(at: layoutRelsDir, withIntermediateDirectories: true)
        let layoutRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rIdMaster1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
        </Relationships>
        """
        try layoutRels.write(to: layoutRelsDir.appendingPathComponent("slideLayout1.xml.rels"), atomically: true, encoding: utf8)

        // Individual slides
        for i in 1...pageCount {
            let hasImage = (i - 1) < slideImageNames.count
            let imageName = hasImage ? slideImageNames[i - 1] : ""

            // Extract text for the slide (fallback if no images)
            var textContent = ""
            if let page = document.page(at: i - 1), let text = page.string, !text.isEmpty {
                textContent = String(text.prefix(500))
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
            }

            let slideXML: String
            if hasImage {
                slideXML = buildImageSlide(index: i, widthEMU: w, heightEMU: h)
            } else {
                slideXML = buildTextSlide(index: i, text: textContent, widthEMU: w, heightEMU: h)
            }
            try slideXML.write(to: slidesDir.appendingPathComponent("slide\(i).xml"), atomically: true, encoding: utf8)

            // slide rels
            let slideRelXML: String
            if hasImage {
                slideRelXML = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rIdLayout" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
                  <Relationship Id="rIdImg1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/\(imageName)"/>
                </Relationships>
                """
            } else {
                slideRelXML = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rIdLayout" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
                </Relationships>
                """
            }
            try slideRelXML.write(to: slideRels.appendingPathComponent("slide\(i).xml.rels"), atomically: true, encoding: utf8)
        }
    }

    private func buildImageSlide(index: Int, widthEMU: Int, heightEMU: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
               xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
               xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
              <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(widthEMU)" cy="\(heightEMU)"/></a:xfrm></p:grpSpPr>
              <p:pic>
                <p:nvPicPr>
                  <p:cNvPr id="2" name="Page \(index)"/>
                  <p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>
                  <p:nvPr/>
                </p:nvPicPr>
                <p:blipFill>
                  <a:blip r:embed="rIdImg1"/>
                  <a:stretch><a:fillRect/></a:stretch>
                </p:blipFill>
                <p:spPr>
                  <a:xfrm><a:off x="0" y="0"/><a:ext cx="\(widthEMU)" cy="\(heightEMU)"/></a:xfrm>
                  <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                </p:spPr>
              </p:pic>
            </p:spTree>
          </p:cSld>
        </p:sld>
        """
    }

    private func buildTextSlide(index: Int, text: String, widthEMU: Int, heightEMU: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
               xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
               xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
              <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(widthEMU)" cy="\(heightEMU)"/></a:xfrm></p:grpSpPr>
              <p:sp>
                <p:nvSpPr><p:cNvPr id="2" name="Content \(index)"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph/></p:nvPr></p:nvSpPr>
                <p:spPr><a:xfrm><a:off x="457200" y="457200"/><a:ext cx="\(widthEMU - 914400)" cy="\(heightEMU - 914400)"/></a:xfrm></p:spPr>
                <p:txBody>
                  <a:bodyPr/>
                  <a:lstStyle/>
                  <a:p><a:r><a:t>\(text)</a:t></a:r></a:p>
                </p:txBody>
              </p:sp>
            </p:spTree>
          </p:cSld>
        </p:sld>
        """
    }
}
