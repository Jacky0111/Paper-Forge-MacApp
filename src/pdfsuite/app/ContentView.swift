import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(appState.moduleManifests, selection: $appState.selectedModuleID) { manifest in
                VStack(alignment: .leading, spacing: 4) {
                    Text(manifest.displayName)
                    Text(manifest.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(manifest.id)
            }
            .navigationTitle("Paper Forge")
        } detail: {
            ModuleDetailView()
                .environmentObject(appState)
        }
    }
}

private struct ModuleDetailView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.selectedModule?.displayName ?? "Paper Forge")
                .font(.largeTitle.bold())
            Text(appState.selectedModule?.category ?? "Native macOS document workflow")
                .foregroundStyle(.secondary)

            Form {
                LabeledContent("Input") {
                    HStack {
                        Text(appState.inputURL?.lastPathComponent ?? "No file selected")
                            .foregroundStyle(appState.inputURL == nil ? .secondary : .primary)
                        Button("Choose File") {
                            appState.chooseInputFile()
                        }
                    }
                }

                LabeledContent("Output") {
                    HStack {
                        Text(appState.outputDirectory?.lastPathComponent ?? "No folder selected")
                            .foregroundStyle(appState.outputDirectory == nil ? .secondary : .primary)
                        Button("Choose Folder") {
                            appState.chooseOutputFolder()
                        }
                    }
                }

                FeatureOptionsView()
                    .environmentObject(appState)
            }
            .formStyle(.grouped)

            HStack {
                Button("Run") {
                    appState.runSelectedModule()
                }
                .keyboardShortcut(.return)
                .disabled(appState.isRunning)

                Button("Cancel") {
                    appState.cancelCurrentJob()
                }
                .disabled(!appState.isRunning)

                Button("Open Output Folder") {
                    appState.openOutputFolder()
                }
                .disabled(appState.outputDirectory == nil)

                if appState.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(appState.statusMessage)
                .foregroundStyle(.secondary)

            if let report = appState.lastReport, !report.outputURLs.isEmpty {
                Divider()
                Text("Outputs")
                    .font(.headline)
                ForEach(report.outputURLs, id: \.self) { url in
                    Text(url.lastPathComponent)
                        .textSelection(.enabled)
                }
            }

            if !appState.jobs.isEmpty {
                Divider()
                JobHistoryView(jobs: appState.jobs)
            }

            Spacer()
        }
        .padding()
    }
}

private struct JobHistoryView: View {
    let jobs: [DocumentJob]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Job History")
                .font(.headline)

            ForEach(jobs.reversed()) { job in
                HStack(alignment: .top, spacing: 10) {
                    statusIcon(for: job.status)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(job.moduleIdentifier)
                            .font(.subheadline.weight(.semibold))
                        Text(job.sourceURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(job.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(job.progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for status: DocumentJobStatus) -> some View {
        switch status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .controlSize(.small)
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

private struct FeatureOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.selectedModuleID {
        case "pdf_to_images":
            PDFToImagesOptionsView()
        case "txt_to_pdf":
            TxtToPDFOptionsView()
        case "flatten_pdf":
            FlattenPDFOptionsView()
        default:
            EmptyView()
        }
    }
}

private struct PDFToImagesOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        LabeledContent("Format") {
            Picker("Format", selection: $appState.pdfImageFormat) {
                ForEach(PDFImageFormat.allCases, id: \.self) { format in
                    Text(format.rawValue.uppercased()).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }

        LabeledContent("DPI") {
            Stepper(value: $appState.pdfImageDPI, in: 72...600, step: 10) {
                Text("\(appState.pdfImageDPI)")
                    .monospacedDigit()
            }
            .frame(maxWidth: 160)
        }
    }
}

private struct TxtToPDFOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        LabeledContent("Font Size") {
            Stepper(value: $appState.txtFontSize, in: 8...24, step: 1) {
                Text("\(Int(appState.txtFontSize)) pt")
                    .monospacedDigit()
            }
            .frame(maxWidth: 160)
        }

        LabeledContent("Margin") {
            Stepper(value: $appState.txtMargin, in: 24...96, step: 6) {
                Text("\(Int(appState.txtMargin)) pt")
                    .monospacedDigit()
            }
            .frame(maxWidth: 160)
        }
    }
}

private struct FlattenPDFOptionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Toggle("Preserve annotations", isOn: $appState.flattenPreserveAnnotations)
    }
}
