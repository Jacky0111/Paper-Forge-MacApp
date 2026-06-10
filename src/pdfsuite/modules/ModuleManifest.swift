import Foundation

struct ModuleManifest: Identifiable, Hashable {
    let id: String
    let displayName: String
    let category: String
    let supportedInputTypes: [String]
    let iconName: String
    let colorName: String
    let moduleDescription: String
}
