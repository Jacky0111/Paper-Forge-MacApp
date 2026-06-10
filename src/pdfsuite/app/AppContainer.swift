import Foundation

struct AppContainer {
    let fileImporter: FileImporting
    let jobStore: JobStoring
    let progressBus: ProgressPublishing
    let settingsStore: SettingsStoring
    let moduleRegistry: ModuleRegistering
    let moduleRunner: ModuleRunning

    static let live: AppContainer = {
        let registry = BuiltInModuleRegistry()
        return AppContainer(
            fileImporter: DefaultFileImporter(),
            jobStore: InMemoryJobStore(),
            progressBus: DefaultProgressBus(),
            settingsStore: UserDefaultsSettingsStore(),
            moduleRegistry: registry,
            moduleRunner: DefaultModuleRunner(moduleRegistry: registry)
        )
    }()
}
