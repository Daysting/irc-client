import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

private struct ThemeJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum InstalledFonts {
    static var allNames: [String] {
#if canImport(UIKit)
        return UIFont.familyNames
            .flatMap { UIFont.fontNames(forFamilyName: $0) }
            .sorted()
#elseif canImport(AppKit)
        return NSFontManager.shared.availableFonts.sorted()
#else
        return []
#endif
    }
}

struct ThemeControlsView: View {
    @EnvironmentObject private var vm: IRCViewModel

    @State private var showDeleteThemeConfirmation = false
    @State private var showImportStrategyConfirmation = false
    @State private var pendingImportData: Data?
    @State private var pendingImportFileName: String = ""
    @State private var isExportingThemes = false
    @State private var exportDocument: ThemeJSONDocument?
    @State private var isImportingThemes = false

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

    private var appearanceFontNameBinding: Binding<String> {
        Binding(
            get: { vm.config.appearanceFontName ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                vm.config.appearanceFontName = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private var installedFontNames: [String] {
        InstalledFonts.allNames
    }

    var body: some View {
        themeControlsContent
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
            .fileExporter(
                isPresented: $isExportingThemes,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "daysting-themes"
            ) { result in
                switch result {
                case .success:
                    vm.setThemeStatus("Exported themes", isError: false)
                case .failure(let error):
                    vm.setThemeStatus("Export failed: \(error.localizedDescription)", isError: true)
                }
                exportDocument = nil
            }
            .fileImporter(isPresented: $isImportingThemes, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        vm.setThemeStatus("Import failed: no file selected", isError: true)
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
                case .failure(let error):
                    vm.setThemeStatus("Import failed: \(error.localizedDescription)", isError: true)
                }
            }
    }

    @ViewBuilder
    private var themeControlsContent: some View {
#if os(iOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme Controls")
                    .font(.title3.weight(.semibold))

                Toggle("Custom Theme", isOn: $vm.config.enableCustomAppearance)
                    .toggleStyle(.switch)

                Picker("Font", selection: $vm.config.appearanceFontFamily) {
                    ForEach(AppearanceFontFamily.allCases) { family in
                        Text(family.title).tag(family)
                    }
                }

                Stepper(
                    "Font Size: \(Int(vm.config.appearanceFontSize))",
                    value: $vm.config.appearanceFontSize,
                    in: 10...24,
                    step: 1
                )

                ColorPicker("Text", selection: appearanceTextColorBinding, supportsOpacity: true)
                ColorPicker("Background", selection: appearanceBackgroundColorBinding, supportsOpacity: true)

                TextField("Installed Font Name (optional)", text: appearanceFontNameBinding)
                    .textFieldStyle(.roundedBorder)

                Menu("Installed Fonts") {
                    if installedFontNames.isEmpty {
                        Text("No fonts available")
                    } else {
                        Button("Use Family Picker Only") {
                            vm.config.appearanceFontName = nil
                        }
                        Divider()
                        ForEach(installedFontNames, id: \.self) { fontName in
                            Button(fontName) {
                                vm.config.appearanceFontName = fontName
                            }
                        }
                    }
                }

                TextField("Theme Name", text: $vm.themeDraftName)
                    .textFieldStyle(.roundedBorder)

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

                HStack(spacing: 8) {
                    Button("Apply Theme") {
                        vm.applySelectedTheme()
                    }
                    .disabled(!vm.hasSelectedSavedTheme)

                    Button("Delete Theme") {
                        showDeleteThemeConfirmation = true
                    }
                    .disabled(!vm.hasSelectedSavedTheme)
                }

                HStack(spacing: 8) {
                    Button("Reset Theme") {
                        vm.resetAppearanceToDefaults()
                    }

                    Button("Export Themes") {
                        exportThemesToJSONFile()
                    }

                    Button("Import Themes") {
                        importThemesFromJSONFile()
                    }
                }

                if !vm.themeStatusMessage.isEmpty {
                    Text(vm.themeStatusMessage)
                        .foregroundStyle(vm.themeStatusIsError ? .red : .green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
#else
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
                TextField("Installed Font Name (optional)", text: appearanceFontNameBinding)
                    .textFieldStyle(.roundedBorder)

                Menu("Installed Fonts") {
                    if installedFontNames.isEmpty {
                        Text("No fonts available")
                    } else {
                        Button("Use Family Picker Only") {
                            vm.config.appearanceFontName = nil
                        }
                        Divider()
                        ForEach(installedFontNames, id: \.self) { fontName in
                            Button(fontName) {
                                vm.config.appearanceFontName = fontName
                            }
                        }
                    }
                }

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
#endif
    }

    private func color(from rgba: RGBAColor) -> Color {
        Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    private func rgba(from color: Color) -> RGBAColor {
#if canImport(UIKit)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBAColor(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
#elseif canImport(AppKit)
        let nsColor = NSColor(color)
        let rgbColor = nsColor.usingColorSpace(.deviceRGB) ?? NSColor.white
        return RGBAColor(
            red: Double(rgbColor.redComponent),
            green: Double(rgbColor.greenComponent),
            blue: Double(rgbColor.blueComponent),
            alpha: Double(rgbColor.alphaComponent)
        )
#else
        return RGBAColor.defaultText
#endif
    }

    private func exportThemesToJSONFile() {
        guard let data = vm.exportThemesData() else {
            vm.setThemeStatus("Export failed: unable to encode themes", isError: true)
            return
        }

        exportDocument = ThemeJSONDocument(data: data)
        isExportingThemes = true
    }

    private func importThemesFromJSONFile() {
        isImportingThemes = true
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
