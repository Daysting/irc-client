import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ThemeControlsView: View {
    @EnvironmentObject private var vm: IRCViewModel

    @State private var showDeleteThemeConfirmation = false
    @State private var showImportStrategyConfirmation = false
    @State private var pendingImportData: Data?
    @State private var pendingImportFileName: String = ""

    private var appearanceTextColorBinding: Binding<Color> {
        Binding(
            get: { color(from: vm.config.appearanceTextColor) },
            set: { vm.config.appearanceTextColor = rgba(from: $0) }
        )
    }

    private var appearanceBackgroundColorBinding: Binding<Color> {
        Binding(
            get: { color(from: vm.config.appearanceBackgroundColor) },
            set: { vm.config.appearanceBackgroundColor = rgba(from: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme Controls")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                Toggle("Custom Theme", isOn: $vm.config.enableCustomAppearance)
                    .toggleStyle(.switch)
                    .frame(width: 130)

                Picker("Font", selection: $vm.config.appearanceFontFamily) {
                    ForEach(AppearanceFontFamily.allCases) { family in
                        Text(family.title).tag(family)
                    }
                }
                .frame(width: 220)

                Stepper(
                    "Font Size: \(Int(vm.config.appearanceFontSize))",
                    value: $vm.config.appearanceFontSize,
                    in: 10...24,
                    step: 1
                )
                .frame(width: 180)

                ColorPicker("Text", selection: appearanceTextColorBinding, supportsOpacity: true)
                    .frame(width: 150)
                ColorPicker("Background", selection: appearanceBackgroundColorBinding, supportsOpacity: true)
                    .frame(width: 180)

                Spacer()
            }

            HStack(spacing: 10) {
                TextField("Theme Name", text: $vm.themeDraftName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)

                Button("Save Theme") {
                    vm.saveCurrentTheme()
                }
                .disabled(vm.themeDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Picker("Saved Themes", selection: $vm.selectedThemeID) {
                    Text("Select Theme").tag("")
                    ForEach(vm.savedThemes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .frame(width: 240)

                Button("Apply Theme") {
                    vm.applySelectedTheme()
                }
                .disabled(!vm.hasSelectedSavedTheme)

                Button("Delete Theme") {
                    showDeleteThemeConfirmation = true
                }
                .disabled(!vm.hasSelectedSavedTheme)

                Button("Reset Theme") {
                    vm.resetAppearanceToDefaults()
                }

                Button("Export Themes") {
                    exportThemesToJSONFile()
                }

                Button("Import Themes") {
                    importThemesFromJSONFile()
                }

                Spacer()
            }

            if !vm.themeStatusMessage.isEmpty {
                Text(vm.themeStatusMessage)
                    .foregroundStyle(vm.themeStatusIsError ? .red : .green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(16)
        .confirmationDialog("Delete selected theme?", isPresented: $showDeleteThemeConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                vm.deleteSelectedTheme()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the currently selected theme preset.")
        }
        .confirmationDialog("Import Themes", isPresented: $showImportStrategyConfirmation, titleVisibility: .visible) {
            Button("Replace Existing Names") {
                runThemeImport(strategy: .replaceExistingNames)
            }
            Button("Keep Both") {
                runThemeImport(strategy: .keepBoth)
            }
            Button("Cancel", role: .cancel) {
                vm.setThemeStatus("Import canceled", isError: true)
                pendingImportData = nil
                pendingImportFileName = ""
            }
        } message: {
            Text("Choose how to handle imported themes that have the same name as existing themes.")
        }
    }

    private func color(from rgba: RGBAColor) -> Color {
        Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    private func rgba(from color: Color) -> RGBAColor {
        let nsColor = NSColor(color)
        let rgbColor = nsColor.usingColorSpace(.deviceRGB) ?? NSColor.white
        return RGBAColor(
            red: Double(rgbColor.redComponent),
            green: Double(rgbColor.greenComponent),
            blue: Double(rgbColor.blueComponent),
            alpha: Double(rgbColor.alphaComponent)
        )
    }

    private func exportThemesToJSONFile() {
        guard let data = vm.exportThemesData() else {
            vm.setThemeStatus("Export failed: unable to encode themes", isError: true)
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Theme Presets"
        panel.nameFieldStringValue = "daysting-themes.json"
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            vm.setThemeStatus("Export canceled", isError: true)
            return
        }

        do {
            try data.write(to: url, options: .atomic)
            vm.setThemeStatus("Exported themes to \(url.lastPathComponent)", isError: false)
        } catch {
            vm.setThemeStatus("Export failed: \(error.localizedDescription)", isError: true)
        }
    }

    private func importThemesFromJSONFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Theme Presets"
        panel.allowedContentTypes = [UTType.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            vm.setThemeStatus("Import canceled", isError: true)
            return
        }

        do {
            let data = try Data(contentsOf: url)
            pendingImportData = data
            pendingImportFileName = url.lastPathComponent
            showImportStrategyConfirmation = true
        } catch {
            vm.setThemeStatus("Import failed: \(error.localizedDescription)", isError: true)
        }
    }

    private func runThemeImport(strategy: IRCViewModel.ThemeImportStrategy) {
        guard let data = pendingImportData else {
            vm.setThemeStatus("Import failed: no file data loaded", isError: true)
            return
        }
        let imported = vm.importThemesData(data, strategy: strategy)
        if imported > 0 {
            vm.setThemeStatus("Imported \(imported) theme(s) from \(pendingImportFileName)", isError: false)
        }
        pendingImportData = nil
        pendingImportFileName = ""
    }
}
