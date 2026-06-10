import Foundation

protocol FileImporting {
    func importFile(at url: URL) throws -> URL
}

struct DefaultFileImporter: FileImporting {
    func importFile(at url: URL) throws -> URL {
        url
    }
}
