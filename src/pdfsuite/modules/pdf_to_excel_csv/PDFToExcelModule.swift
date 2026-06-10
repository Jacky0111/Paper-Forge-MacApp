import AppKit
import Foundation
import PDFKit

enum ExcelOutputFormat: String, CaseIterable, Hashable {
    case csv  = "csv"
    case xlsx = "xlsx"
}

struct PDFToExcelOptions: Hashable {
    let format: ExcelOutputFormat
    let allPages: Bool      // combine all pages into one sheet vs separate sheets
    let rowThreshold: CGFloat   // Y-proximity threshold for same row (points)
    let colGapThreshold: CGFloat // minimum X gap to consider a new column
}

final class PDFToExcelModule: ModulePerforming {
    let manifest = ModuleManifest(
        id: "pdf_to_excel",
        displayName: "PDF to Excel",
        category: "Convert",
        supportedInputTypes: ["pdf"],
        iconName: "tablecells",
        colorName: "teal",
        moduleDescription: "Extract tables and text into CSV or XLSX spreadsheet"
    )

    private let options: PDFToExcelOptions

    init(options: PDFToExcelOptions = PDFToExcelOptions(
        format: .csv, allPages: true, rowThreshold: 3.0, colGapThreshold: 12.0
    )) {
        self.options = options
    }

    func execute(inputURL: URL, context: ModuleExecutionContext) throws -> ModuleExecutionReport {
        let renderer = PDFToExcelRenderer()
        let outputURLs = try renderer.render(
            pdfURL: inputURL,
            outputDirectory: context.outputDirectory,
            options: options,
            context: context
        )
        let fileCount = outputURLs.count
        return ModuleExecutionReport(
            id: UUID(),
            moduleID: manifest.id,
            outputURLs: outputURLs,
            summary: "Extracted \(fileCount) \(options.format.rawValue.uppercased()) file\(fileCount == 1 ? "" : "s") from \(inputURL.lastPathComponent)."
        )
    }
}

// MARK: - Renderer

final class PDFToExcelRenderer {
    func render(
        pdfURL: URL,
        outputDirectory: URL,
        options: PDFToExcelOptions,
        context: ModuleExecutionContext
    ) throws -> [URL] {
        guard let document = PDFDocument(url: pdfURL) else {
            throw DocumentError.invalidInput("Unable to open the selected PDF.")
        }
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw DocumentError.processingFailed("The selected PDF does not contain any pages.")
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        context.reportProgress(0.05, "Extracting table data...")

        var pageGrids: [[[String]]] = []   // [page][row][col]
        for index in 0..<pageCount {
            try context.checkCancellation()
            context.reportProgress(
                0.05 + (Double(index) / Double(pageCount)) * 0.60,
                "Processing page \(index + 1) of \(pageCount)..."
            )
            guard let page = document.page(at: index) else {
                pageGrids.append([])
                continue
            }
            pageGrids.append(extractGrid(from: page, options: options))
        }

        context.reportProgress(0.70, "Writing output...")

        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        var outputURLs: [URL] = []

        switch options.format {
        case .csv:
            if options.allPages {
                let rows = pageGrids.flatMap { $0 }
                let url = outputDirectory.appendingPathComponent("\(baseName).csv")
                try writeCSV(rows: rows, to: url)
                outputURLs.append(url)
            } else {
                for (i, grid) in pageGrids.enumerated() {
                    let url = outputDirectory.appendingPathComponent("\(baseName)_page\(i + 1).csv")
                    try writeCSV(rows: grid, to: url)
                    outputURLs.append(url)
                }
            }
        case .xlsx:
            let url = outputDirectory.appendingPathComponent("\(baseName).xlsx")
            try writeXLSX(pageGrids: pageGrids, baseName: baseName, allPages: options.allPages, to: url)
            outputURLs.append(url)
        }

        context.reportProgress(1.0, "Extracted table data from \(pdfURL.lastPathComponent).")
        return outputURLs
    }

    // MARK: - Grid extraction

    struct CharCell {
        let char: String
        let x: CGFloat
        let y: CGFloat
    }

    private func extractGrid(from page: PDFPage, options: PDFToExcelOptions) -> [[String]] {
        guard let fullText = page.string, !fullText.isEmpty else { return [] }

        let nsText = fullText as NSString
        let length = nsText.length
        let pageBounds = page.bounds(for: .mediaBox)
        let pageHeight = pageBounds.height

        // Collect per-character positions
        var cells: [CharCell] = []
        cells.reserveCapacity(length)
        for i in 0..<length {
            let ch = nsText.substring(with: NSRange(location: i, length: 1))
            if ch == "\n" { continue }
            let bounds = page.characterBounds(at: i)
            if bounds.isEmpty && ch.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            // Flip Y: PDFKit uses bottom-left origin
            let flippedY = pageHeight - bounds.midY
            cells.append(CharCell(char: ch, x: bounds.midX, y: flippedY))
        }

        guard !cells.isEmpty else { return [] }

        // Cluster characters into rows by Y proximity
        let sorted = cells.sorted { $0.y < $1.y }
        var rows: [[CharCell]] = []
        var currentRow: [CharCell] = [sorted[0]]
        var currentY = sorted[0].y

        for cell in sorted.dropFirst() {
            if abs(cell.y - currentY) <= options.rowThreshold {
                currentRow.append(cell)
            } else {
                rows.append(currentRow.sorted { $0.x < $1.x })
                currentRow = [cell]
                currentY = cell.y
            }
        }
        rows.append(currentRow.sorted { $0.x < $1.x })

        // Convert each row's characters into column-separated tokens
        return rows.map { rowCells in
            var tokens: [String] = []
            var currentToken = ""
            var lastX: CGFloat = rowCells.first?.x ?? 0

            for cell in rowCells {
                let gap = cell.x - lastX
                if gap > options.colGapThreshold && !currentToken.isEmpty {
                    tokens.append(currentToken.trimmingCharacters(in: .whitespaces))
                    currentToken = cell.char
                } else {
                    currentToken += cell.char
                }
                lastX = cell.x
            }
            if !currentToken.trimmingCharacters(in: .whitespaces).isEmpty {
                tokens.append(currentToken.trimmingCharacters(in: .whitespaces))
            }
            return tokens
        }.filter { !$0.isEmpty }
    }

    // MARK: - CSV writer

    private func writeCSV(rows: [[String]], to url: URL) throws {
        let lines = rows.map { cols in
            cols.map { csvEscape($0) }.joined(separator: ",")
        }
        let csv = lines.joined(separator: "\n")
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - XLSX writer

    private func writeXLSX(pageGrids: [[[String]]], baseName: String, allPages: Bool, to outputURL: URL) throws {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: tmpDir) }

        let relsDir   = tmpDir.appendingPathComponent("_rels")
        let xlDir     = tmpDir.appendingPathComponent("xl")
        let xlRelsDir = xlDir.appendingPathComponent("_rels")
        let sheetsDir = xlDir.appendingPathComponent("worksheets")
        for dir in [relsDir, xlRelsDir, sheetsDir] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let sheets: [(name: String, grid: [[String]])]
        if allPages {
            let combined = pageGrids.flatMap { $0 }
            sheets = [("Sheet1", combined)]
        } else {
            sheets = pageGrids.enumerated().map { (i, grid) in ("Page\(i + 1)", grid) }
        }

        // Build shared strings for all cells
        var stringTable: [String: Int] = [:]
        var stringList: [String] = []
        func sharedStringIndex(for value: String) -> Int {
            if let idx = stringTable[value] { return idx }
            let idx = stringList.count
            stringList.append(value)
            stringTable[value] = idx
            return idx
        }

        // Pre-register all cell values
        for sheet in sheets {
            for row in sheet.grid {
                for cell in row { _ = sharedStringIndex(for: cell) }
            }
        }

        // [Content_Types].xml
        var sheetOverrides = ""
        for i in 1...max(sheets.count, 1) {
            sheetOverrides += "\n  <Override PartName=\"/xl/worksheets/sheet\(i).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\(sheetOverrides)
        </Types>
        """
        try contentTypes.write(to: tmpDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)

        // _rels/.rels
        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        try rootRels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)

        // xl/_rels/workbook.xml.rels
        var wbRelEntries = """
          <Relationship Id="rIdSS" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
          <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        """
        for i in 1...sheets.count {
            wbRelEntries += "\n  <Relationship Id=\"rId\(i)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i).xml\"/>"
        }
        let wbRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(wbRelEntries)
        </Relationships>
        """
        try wbRels.write(to: xlRelsDir.appendingPathComponent("workbook.xml.rels"), atomically: true, encoding: .utf8)

        // xl/workbook.xml
        var sheetElems = ""
        for (i, sheet) in sheets.enumerated() {
            sheetElems += "<sheet name=\"\(xmlEscape(sheet.name))\" sheetId=\"\(i + 1)\" r:id=\"rId\(i + 1)\"/>"
        }
        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>\(sheetElems)</sheets>
        </workbook>
        """
        try workbook.write(to: xlDir.appendingPathComponent("workbook.xml"), atomically: true, encoding: .utf8)

        // xl/styles.xml (minimal)
        let styles = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts><font><sz val="11"/><name val="Calibri"/></font></fonts>
          <fills><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
          <borders><border><left/><right/><top/><bottom/><diagonal/></border></borders>
          <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
          <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
        </styleSheet>
        """
        try styles.write(to: xlDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)

        // xl/sharedStrings.xml
        let ssEntries = stringList.map { "<si><t xml:space=\"preserve\">\(xmlEscape($0))</t></si>" }.joined()
        let sharedStrings = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(stringList.count)" uniqueCount="\(stringList.count)">\(ssEntries)</sst>
        """
        try sharedStrings.write(to: xlDir.appendingPathComponent("sharedStrings.xml"), atomically: true, encoding: .utf8)

        // xl/worksheets/sheet{n}.xml
        for (si, sheet) in sheets.enumerated() {
            var rowsXML = ""
            for (ri, row) in sheet.grid.enumerated() {
                var cellsXML = ""
                for (ci, value) in row.enumerated() {
                    let colLetter = columnLetter(ci + 1)
                    let cellRef = "\(colLetter)\(ri + 1)"
                    let ssIdx = sharedStringIndex(for: value)
                    cellsXML += "<c r=\"\(cellRef)\" t=\"s\"><v>\(ssIdx)</v></c>"
                }
                rowsXML += "<row r=\"\(ri + 1)\">\(cellsXML)</row>"
            }
            let worksheetXML = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>\(rowsXML)</sheetData>
            </worksheet>
            """
            try worksheetXML.write(to: sheetsDir.appendingPathComponent("sheet\(si + 1).xml"), atomically: true, encoding: .utf8)
        }

        // Package as ZIP
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
            throw DocumentError.processingFailed("Failed to create .xlsx: \(String(data: errData, encoding: .utf8) ?? "unknown")")
        }
        guard fm.fileExists(atPath: outputURL.path) else {
            throw DocumentError.processingFailed("The .xlsx file was not created.")
        }
    }

    // MARK: - Helpers

    private func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func columnLetter(_ n: Int) -> String {
        var n = n
        var result = ""
        while n > 0 {
            n -= 1
            result = String(UnicodeScalar(65 + (n % 26))!) + result
            n /= 26
        }
        return result
    }
}
