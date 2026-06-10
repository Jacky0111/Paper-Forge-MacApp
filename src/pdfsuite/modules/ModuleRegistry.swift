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
                supportedInputTypes: ["pdf"]
            ),
            ModuleManifest(
                id: "txt_to_pdf",
                displayName: "TXT to PDF",
                category: "Convert",
                supportedInputTypes: ["txt"]
            ),
            ModuleManifest(
                id: "flatten_pdf",
                displayName: "Flatten PDF",
                category: "Optimize",
                supportedInputTypes: ["pdf"]
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
        default:
            return nil
        }
    }
}
