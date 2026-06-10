import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 270)
        } detail: {
            ModuleWorkspaceView()
        }
        .environmentObject(appState)
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    private var convertModules: [ModuleManifest] {
        appState.moduleManifests.filter { $0.category == "Convert" }
    }

    private var optimizeModules: [ModuleManifest] {
        appState.moduleManifests.filter { $0.category == "Optimize" }
    }

    var body: some View {
        List(selection: $appState.selectedModuleID) {
            if !convertModules.isEmpty {
                Section("Convert") {
                    ForEach(convertModules) { manifest in
                        ModuleSidebarRow(manifest: manifest)
                            .tag(manifest.id)
                    }
                }
            }
            if !optimizeModules.isEmpty {
                Section("Optimize") {
                    ForEach(optimizeModules) { manifest in
                        ModuleSidebarRow(manifest: manifest)
                            .tag(manifest.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Paper Forge")
    }
}

private struct ModuleSidebarRow: View {
    let manifest: ModuleManifest

    var body: some View {
        HStack(spacing: 11) {
            ModuleIconView(iconName: manifest.iconName, accentColor: manifest.accentColor)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(manifest.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(manifest.moduleDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct ModuleIconView: View {
    let iconName: String
    let accentColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.gradient)
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Workspace

private struct ModuleWorkspaceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let manifest = appState.selectedModule {
            WorkspaceDetailView(manifest: manifest)
                .id(manifest.id)
        } else {
            EmptySelectionView()
        }
    }
}

private struct EmptySelectionView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("Select a tool")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Choose a document workflow from the sidebar.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct WorkspaceDetailView: View {
    @EnvironmentObject private var appState: AppState
    let manifest: ModuleManifest
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WorkspaceHeaderView(manifest: manifest)
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    DropZoneView(manifest: manifest, isDropTargeted: $isDropTargeted)
                    OutputFolderRow()
                    FeatureOptionsSection()
                    RunActionSection(manifest: manifest)
                    if !appState.jobs.isEmpty {
                        JobHistorySection(jobs: appState.jobs)
                    }
                }
                .padding(28)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            appState.setInput(url: url)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }
}

// MARK: - Header

private struct WorkspaceHeaderView: View {
    let manifest: ModuleManifest

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(manifest.accentColor.gradient)
                    .frame(width: 54, height: 54)
                Image(systemName: manifest.iconName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(manifest.displayName)
                    .font(.title2.bold())
                Text(manifest.moduleDescription)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Drop Zone

private struct DropZoneView: View {
    @EnvironmentObject private var appState: AppState
    let manifest: ModuleManifest
    @Binding var isDropTargeted: Bool

    var body: some View {
        Button(action: appState.chooseInputFile) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDropTargeted
                          ? manifest.accentColor.opacity(0.08)
                          : Color(NSColor.controlBackgroundColor))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isDropTargeted ? manifest.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1.5, dash: isDropTargeted ? [] : [6, 4])
                    )

                if let inputURL = appState.inputURL {
                    SelectedFileContent(url: inputURL, accentColor: manifest.accentColor)
                } else {
                    EmptyDropZoneContent(manifest: manifest, isDropTargeted: isDropTargeted)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        .animation(.easeInOut(duration: 0.2), value: appState.inputURL != nil)
        .overlay(alignment: .topTrailing) {
            if appState.inputURL != nil {
                Button {
                    appState.clearInput()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.8), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
    }
}

private struct EmptyDropZoneContent: View {
    let manifest: ModuleManifest
    let isDropTargeted: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                .font(.system(size: 34))
                .foregroundStyle(isDropTargeted ? manifest.accentColor : Color.secondary)
            Text(isDropTargeted ? "Drop to select" : "Drop file here")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isDropTargeted ? manifest.accentColor : .primary)
            Text("Accepts \(manifest.supportedInputTypes.map { $0.uppercased() }.joined(separator: ", ")) files")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("or click to browse")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct SelectedFileContent: View {
    let url: URL
    let accentColor: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accentColor)
                .font(.title3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

// MARK: - Output Folder

private struct OutputFolderRow: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Output Folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(appState.outputDirectory?.path ?? "Not selected")
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(appState.outputDirectory == nil ? .secondary : .primary)
            }
            Spacer()
            Button("Change") {
                appState.chooseOutputFolder()
            }
            .controlSize(.small)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Options

private struct FeatureOptionsSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.selectedModuleID {
        case "pdf_to_images": PDFToImagesOptionsView()
        case "txt_to_pdf":    TxtToPDFOptionsView()
        case "flatten_pdf":   FlattenPDFOptionsView()
        case "pdf_to_word":   PDFToWordOptionsView()
        case "pdf_to_pptx":   PDFToPPTXOptionsView()
        case "pdf_to_excel":  PDFToExcelOptionsView()
        case "edit_pdf":      EditPDFOptionsView()
        case "translate_pdf": TranslatePDFOptionsView()
        default:              EmptyView()
        }
    }
}

private struct OptionsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct PDFToImagesOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OptionsCard(title: "Output Options") {
            HStack(spacing: 0) {
                Text("Format")
                    .font(.system(size: 13))
                    .frame(width: 90, alignment: .leading)
                Picker("", selection: $appState.pdfImageFormat) {
                    ForEach(PDFImageFormat.allCases, id: \.self) { fmt in
                        Text(fmt.rawValue.uppercased()).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Divider()
            HStack(spacing: 0) {
                Text("Resolution")
                    .font(.system(size: 13))
                    .frame(width: 90, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { Double(appState.pdfImageDPI) },
                        set: { appState.pdfImageDPI = Int($0) }
                    ),
                    in: 72...600,
                    step: 10
                )
                Text("\(appState.pdfImageDPI) dpi")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 68, alignment: .trailing)
            }
        }
    }
}

private struct TxtToPDFOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OptionsCard(title: "Layout Options") {
            HStack(spacing: 0) {
                Text("Font size")
                    .font(.system(size: 13))
                    .frame(width: 90, alignment: .leading)
                Slider(value: $appState.txtFontSize, in: 8...24, step: 1)
                Text("\(Int(appState.txtFontSize)) pt")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            Divider()
            HStack(spacing: 0) {
                Text("Margin")
                    .font(.system(size: 13))
                    .frame(width: 90, alignment: .leading)
                Slider(value: $appState.txtMargin, in: 24...96, step: 6)
                Text("\(Int(appState.txtMargin)) pt")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }
}

private struct FlattenPDFOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OptionsCard(title: "Flatten Options") {
            Toggle("Preserve existing annotations", isOn: $appState.flattenPreserveAnnotations)
                .font(.system(size: 13))
        }
    }
}

private struct PDFToWordOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OptionsCard(title: "Word Options") {
            Toggle("Insert page break between PDF pages", isOn: $appState.wordPageBreaks)
                .font(.system(size: 13))
        }
    }
}

private struct TranslatePDFOptionsView: View {
    @EnvironmentObject private var appState: AppState

    private let sourceLangs: [TranslationLanguage] = [.autoDetect] + TranslationLanguage.all
    private let targetLangs: [TranslationLanguage] = TranslationLanguage.all

    var body: some View {
        OptionsCard(title: "Translation") {
            HStack(spacing: 0) {
                Text("From")
                    .font(.system(size: 13))
                    .frame(width: 60, alignment: .leading)
                Picker("", selection: $appState.translateSourceLangID) {
                    ForEach(sourceLangs) { lang in
                        Text(lang.displayName).tag(lang.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            Divider()
            HStack(spacing: 0) {
                Text("To")
                    .font(.system(size: 13))
                    .frame(width: 60, alignment: .leading)
                Picker("", selection: $appState.translateTargetLangID) {
                    ForEach(targetLangs) { lang in
                        Text(lang.displayName).tag(lang.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            if #unavailable(macOS 26.0) {
                Divider()
                Label("Requires macOS 15 or later", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct EditPDFOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OptionsCard(title: "Edit Options") {
            HStack(spacing: 0) {
                Text("Operation")
                    .font(.system(size: 13))
                    .frame(width: 90, alignment: .leading)
                Picker("", selection: $appState.editPDFOperation) {
                    Text("Remove blank pages").tag(EditPDFOperation.removeBlankPages)
                    Text("Rotate all pages").tag(EditPDFOperation.rotateAll)
                    Text("Remove first page").tag(EditPDFOperation.removeFirstPage)
                    Text("Remove last page").tag(EditPDFOperation.removeLastPage)
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            if appState.editPDFOperation == .rotateAll {
                Divider()
                HStack(spacing: 0) {
                    Text("Rotation")
                        .font(.system(size: 13))
                        .frame(width: 90, alignment: .leading)
                    Picker("", selection: $appState.editPDFRotation) {
                        Text("90° CW").tag(90)
                        Text("180°").tag(180)
                        Text("90° CCW").tag(270)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }
}

private struct PDFToExcelOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OptionsCard(title: "Excel Options") {
            HStack(spacing: 0) {
                Text("Format")
                    .font(.system(size: 13))
                    .frame(width: 90, alignment: .leading)
                Picker("", selection: $appState.excelFormat) {
                    ForEach(ExcelOutputFormat.allCases, id: \.self) { fmt in
                        Text(fmt.rawValue.uppercased()).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Divider()
            Toggle("Combine all pages into one sheet", isOn: $appState.excelAllPages)
                .font(.system(size: 13))
        }
    }
}

private struct PDFToPPTXOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        OptionsCard(title: "Slide Options") {
            HStack(spacing: 0) {
                Text("Slide size")
                    .font(.system(size: 13))
                    .frame(width: 90, alignment: .leading)
                Picker("", selection: $appState.pptxSlideSize) {
                    Text("Widescreen 16:9").tag(PDFToPPTXOptions.SlideSize.widescreen)
                    Text("Standard 4:3").tag(PDFToPPTXOptions.SlideSize.standard)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Divider()
            Toggle("Embed page images in slides", isOn: $appState.pptxIncludeImages)
                .font(.system(size: 13))
        }
    }
}

// MARK: - Run / Progress / Results

private struct RunActionSection: View {
    @EnvironmentObject private var appState: AppState
    let manifest: ModuleManifest

    var body: some View {
        VStack(spacing: 12) {
            if appState.isRunning {
                ProgressIndicatorSection(manifest: manifest)
            }

            if let report = appState.lastReport, !report.outputURLs.isEmpty, !appState.isRunning {
                ResultsSection(report: report)
            }

            HStack(spacing: 10) {
                Button {
                    appState.runSelectedModule()
                } label: {
                    Label("Run", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(manifest.accentColor)
                .keyboardShortcut(.return)
                .disabled(appState.isRunning || appState.inputURL == nil || appState.outputDirectory == nil)
                .help(appState.runButtonHelp)

                if appState.isRunning {
                    Button("Cancel") {
                        appState.cancelCurrentJob()
                    }
                    .controlSize(.large)
                    .disabled(appState.cancellationRequested)
                }
            }
        }
    }
}

private struct ProgressIndicatorSection: View {
    @EnvironmentObject private var appState: AppState
    let manifest: ModuleManifest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text(appState.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text("\(Int(appState.currentProgress * 100))%")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: appState.currentProgress)
                .progressViewStyle(.linear)
                .tint(manifest.accentColor)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ResultsSection: View {
    @EnvironmentObject private var appState: AppState
    let report: ModuleExecutionReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
                Text(report.summary)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Show in Finder") {
                    appState.openOutputFolder()
                }
                .controlSize(.small)
            }

            if report.outputURLs.count == 1, let url = report.outputURLs.first {
                SingleOutputRow(url: url)
            } else if report.outputURLs.count > 1 {
                MultiOutputList(urls: report.outputURLs)
            }
        }
        .padding(14)
        .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct SingleOutputRow: View {
    let url: URL

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 24, height: 24)
            Text(url.lastPathComponent)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(1)
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}

private struct MultiOutputList: View {
    let urls: [URL]
    private let displayLimit = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(urls.prefix(displayLimit), id: \.self) { url in
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            if urls.count > displayLimit {
                Text("… and \(urls.count - displayLimit) more files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Job History

private struct JobHistorySection: View {
    let jobs: [DocumentJob]
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(jobs.reversed().prefix(10).enumerated()), id: \.element.id) { index, job in
                    if index > 0 { Divider().padding(.leading, 38) }
                    JobHistoryRow(job: job)
                        .padding(.vertical, 6)
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text("Recent Jobs")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text("\(jobs.count)")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.18), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct JobHistoryRow: View {
    let job: DocumentJob

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            jobStatusIcon
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.moduleIdentifier.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 12, weight: .medium))
                Text(job.sourceURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(job.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 180, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var jobStatusIcon: some View {
        switch job.status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
        case .cancelled:
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - ModuleManifest UI helpers

private extension ModuleManifest {
    var accentColor: Color {
        switch colorName {
        case "blue":   return .blue
        case "green":  return .green
        case "orange": return .orange
        case "indigo": return .indigo
        case "pink":   return .pink
        case "teal":   return .teal
        case "purple": return .purple
        case "mint":   return .mint
        default:       return .accentColor
        }
    }
}
