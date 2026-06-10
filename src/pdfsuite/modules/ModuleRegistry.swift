import CoreGraphics
import Foundation

protocol ModuleRegistering {
    func allManifests() -> [ModuleManifest]
    func module(for id: String, settings: [String: String]) -> ModulePerforming?
}

final class BuiltInModuleRegistry: ModuleRegistering {
    func allManifests() -> [ModuleManifest] {
        [
            ModuleManifest(
                id: "pdf_to_images",
                displayName: "PDF to Images",
                category: "Convert",
                supportedInputTypes: ["pdf"],
                iconName: "photo.stack",
                colorName: "blue",
                moduleDescription: "Export each page as PNG, JPG, or TIFF"
            ),
            ModuleManifest(
                id: "txt_to_pdf",
                displayName: "TXT to PDF",
                category: "Convert",
                supportedInputTypes: ["txt"],
                iconName: "doc.text",
                colorName: "green",
                moduleDescription: "Convert plain text into a clean PDF"
            ),
            ModuleManifest(
                id: "flatten_pdf",
                displayName: "Flatten PDF",
                category: "Optimize",
                supportedInputTypes: ["pdf"],
                iconName: "arrow.2.squarepath",
                colorName: "orange",
                moduleDescription: "Merge annotations and form fields into the page"
            ),
            ModuleManifest(
                id: "pdf_to_word",
                displayName: "PDF to Word",
                category: "Convert",
                supportedInputTypes: ["pdf"],
                iconName: "doc.richtext",
                colorName: "indigo",
                moduleDescription: "Extract text and styles into an editable .docx file"
            ),
            ModuleManifest(
                id: "pdf_to_pptx",
                displayName: "PDF to PPTX",
                category: "Convert",
                supportedInputTypes: ["pdf"],
                iconName: "play.rectangle",
                colorName: "pink",
                moduleDescription: "Convert each PDF page into a PowerPoint slide"
            ),
            ModuleManifest(
                id: "pdf_to_excel",
                displayName: "PDF to Excel",
                category: "Convert",
                supportedInputTypes: ["pdf"],
                iconName: "tablecells",
                colorName: "teal",
                moduleDescription: "Extract tables and text into CSV or XLSX spreadsheet"
            ),
            ModuleManifest(
                id: "edit_pdf",
                displayName: "Edit PDF",
                category: "Optimize",
                supportedInputTypes: ["pdf"],
                iconName: "pencil.and.scribble",
                colorName: "purple",
                moduleDescription: "Remove or rotate pages with simple non-destructive edits"
            )
        ]
    }

    func module(for id: String, settings: [String: String]) -> ModulePerforming? {
        switch id {
        case "pdf_to_images":
            let dpi = Int(settings["dpi"] ?? "") ?? 200
            let format = PDFImageFormat(rawValue: settings["format"] ?? "") ?? .png
            return PDFToImagesModule(options: PDFToImagesOptions(dpi: dpi, format: format))
        case "txt_to_pdf":
            let fontSize = Double(settings["fontSize"] ?? "") ?? 12
            let margin = Double(settings["margin"] ?? "") ?? 48
            return TxtToPDFModule(options: TxtToPDFOptions(fontSize: fontSize, margin: margin, pageSize: CGSize(width: 595, height: 842)))
        case "flatten_pdf":
            let preserveAnnotations = settings["preserveAnnotations"] == "true"
            return FlattenPDFModule(options: FlattenPDFOptions(preserveAnnotations: preserveAnnotations))
        case "pdf_to_word":
            let pageBreaks = settings["pageBreaks"] != "false"
            return PDFToWordModule(options: PDFToWordOptions(pageBreaks: pageBreaks))
        case "pdf_to_pptx":
            let includeImages = settings["includeImages"] != "false"
            let sizeRaw = settings["slideSize"] ?? "widescreen"
            let slideSize = PDFToPPTXOptions.SlideSize(rawValue: sizeRaw) ?? .widescreen
            return PDFToPPTXModule(options: PDFToPPTXOptions(includeImages: includeImages, slideSize: slideSize))
        case "pdf_to_excel":
            let format = ExcelOutputFormat(rawValue: settings["format"] ?? "") ?? .csv
            let allPages = settings["allPages"] != "false"
            return PDFToExcelModule(options: PDFToExcelOptions(
                format: format, allPages: allPages, rowThreshold: 3.0, colGapThreshold: 12.0
            ))
        case "edit_pdf":
            let op = EditPDFOperation(rawValue: settings["operation"] ?? "") ?? .removeBlankPages
            let rot = Int(settings["rotationDegrees"] ?? "") ?? 90
            return EditPDFModule(options: EditPDFOptions(operation: op, rotationDegrees: rot))
        default:
            return nil
        }
    }
}
