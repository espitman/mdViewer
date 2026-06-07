import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var markdown = sampleMarkdown
    @State private var fileName = "README.md"
    @State private var folderName = "introToMarkdown"
    @State private var fontName = "Vazirmatn-Regular"
    @State private var fontSize = 16.0
    @State private var accentColor = AppColor.accent
    @State private var showImporter = false
    @State private var exportMessage: String?
    @State private var viewMode: ViewMode = .preview
    @State private var isDropTargeted = false
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var currentMatchRange: NSRange?
    @State private var editorSelectionRequest: EditorSelectionRequest?

    private let fonts = ["Vazirmatn-Regular", "Helvetica Neue", "Avenir Next", "SF Pro"]
    private let importableTypes: [UTType] = [.mdFile, .plainText, .text]
    private let droppableTypes = [UTType.fileURL.identifier]

    init(initialFileURL: URL? = nil) {
        if let initialFileURL,
           let content = try? String(contentsOf: initialFileURL, encoding: .utf8) {
            _markdown = State(initialValue: content)
            _fileName = State(initialValue: initialFileURL.lastPathComponent)
            _folderName = State(initialValue: initialFileURL.deletingLastPathComponent().lastPathComponent)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                topBar
                workspace
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1120, minHeight: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.appSurface)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColor.accent, lineWidth: 4)
                    .padding(8)
            }
        }
        .onDrop(of: droppableTypes, isTargeted: $isDropTargeted, perform: handleDrop)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: importableTypes) { result in
            if case .success(let url) = result {
                loadMarkdown(from: url)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MD Viewer")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                Text("Markdown reader")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColor.mutedInk)
                    .lineLimit(1)
            }
            .padding(.top, 26)
            .padding(.horizontal, 22)

            HStack(spacing: 10) {
                statBlock(value: "\(wordCount)", title: "Words")
                statBlock(value: "\(lineCount)", title: "Lines")
            }
            .padding(.top, 22)
            .padding(.horizontal, 22)

            Divider()
                .padding(.vertical, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("File")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColor.sidebarLabel)
                    .textCase(.uppercase)

                actionButton(title: "Open file", icon: "folder") {
                    showImporter = true
                }

                actionButton(title: "Export HTML", icon: "square.and.arrow.up") {
                    exportHTML()
                }
                .help(exportMessage ?? "Export rendered markdown as HTML")
            }
            .padding(.horizontal, 22)

            VStack(alignment: .leading, spacing: 14) {
                Text("Reading")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColor.sidebarLabel)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Font")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.mutedInk)
                    Menu {
                        ForEach(fonts, id: \.self) { font in
                            Button {
                                fontName = font
                            } label: {
                                Label(displayFontName(font), systemImage: fontName == font ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(displayFontName(fontName))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColor.ink)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColor.mutedInk)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppColor.hairline, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Size")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColor.mutedInk)
                        Spacer()
                        Text("\(Int(fontSize))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColor.mutedInk)
                    }
                    Slider(value: $fontSize, in: 13...22, step: 1)
                }

                HStack {
                    Text("Accent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.mutedInk)
                    Spacer()
                    ColorPicker("", selection: $accentColor)
                        .labelsHidden()
                        .frame(width: 42)
                }
            }
            .padding(.top, 30)
            .padding(.horizontal, 22)

            Spacer(minLength: 20)
        }
        .frame(width: 256)
        .background(AppColor.sidebar)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Markdown Viewer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.mutedInk)
                Text(fileName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
            }

            Spacer()

            viewModeControl
        }
        .padding(.horizontal, 28)
        .frame(height: 86)
        .background(AppColor.toolbar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColor.hairline)
                .frame(height: 1)
        }
    }

    private var viewModeControl: some View {
        HStack(spacing: 6) {
            ForEach([ViewMode.preview, .code, .split]) { mode in
                Button {
                    viewMode = mode
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 13, weight: .bold))
                        Text(mode.title)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(viewMode == mode ? .white : AppColor.ink)
                    .frame(width: 96, height: 36)
                    .background(viewMode == mode ? AppColor.accent : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(viewMode == mode ? AppColor.accent : AppColor.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var workspace: some View {
        switch viewMode {
        case .split:
            HStack(spacing: 16) {
                editorPanel
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                previewPanel
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .code:
            editorPanel
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .preview:
            previewPanel
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var editorPanel: some View {
        VStack(spacing: 0) {
            panelHeader(title: "Code", icon: "curlybraces", detail: "Markdown source")
            findReplaceBar
            MarkdownEditor(text: $markdown, selectionRequest: $editorSelectionRequest)
        }
        .background(AppColor.editor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var findReplaceBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.54))
                TextField("Find", text: $findText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .font(.system(size: 13, weight: .medium))
                    .onSubmit { selectNextMatch() }
                    .onChange(of: findText) { _, _ in
                        currentMatchRange = nil
                        selectNextMatch()
                    }
            }
            .padding(.horizontal, 10)
            .frame(width: 190, height: 34)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            TextField("Replace", text: $replaceText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 10)
                .frame(width: 170, height: 34)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(matchStatus)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.56))
                .frame(width: 56, alignment: .leading)

            iconBarButton("chevron.up") { selectPreviousMatch() }
                .disabled(findRanges.isEmpty)
            iconBarButton("chevron.down") { selectNextMatch() }
                .disabled(findRanges.isEmpty)

            Divider()
                .frame(height: 24)
                .overlay(.white.opacity(0.16))

            compactBarButton("Replace") { replaceCurrentMatch() }
                .disabled(currentMatchRange == nil)
            compactBarButton("All") { replaceAllMatches() }
                .disabled(findRanges.isEmpty)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(AppColor.editorHeader.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    private func iconBarButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func compactBarButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.90))
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var previewPanel: some View {
        VStack(spacing: 0) {
            panelHeader(title: "Preview", icon: "doc.richtext", detail: displayFontName(effectiveFontName))
                .background(AppColor.paper)
            ScrollView {
                MarkdownPreview(markdown: markdown, fontName: effectiveFontName, fontSize: fontSize, accentColor: accentColor)
                    .frame(maxWidth: 780, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(AppColor.paper)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColor.hairline, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func panelHeader(title: String, icon: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .bold))
            Spacer()
            Text(detail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColor.mutedInk)
        }
        .foregroundStyle(title == "Code" ? .white.opacity(0.92) : AppColor.ink)
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(title == "Code" ? AppColor.editorHeader : AppColor.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(title == "Code" ? .white.opacity(0.06) : AppColor.hairline)
                .frame(height: 1)
        }
    }

    private func statBlock(value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.ink)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColor.sidebarLabel)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(AppColor.ink)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(.white.opacity(0.68))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var wordCount: Int {
        markdown
            .split { $0.isWhitespace || $0.isNewline }
            .filter { !$0.isEmpty }
            .count
    }

    private var lineCount: Int {
        max(markdown.components(separatedBy: .newlines).count, 1)
    }

    private var findRanges: [NSRange] {
        guard !findText.isEmpty else { return [] }
        let source = markdown as NSString
        let searchRange = NSRange(location: 0, length: source.length)
        var ranges: [NSRange] = []
        var currentLocation = 0

        while currentLocation < source.length {
            let remainingRange = NSRange(location: currentLocation, length: source.length - currentLocation)
            let range = source.range(of: findText, options: [.caseInsensitive], range: remainingRange)
            guard range.location != NSNotFound else { break }
            ranges.append(range)
            currentLocation = range.location + max(range.length, 1)
        }

        if source.length == 0 {
            _ = searchRange
        }

        return ranges
    }

    private var currentMatchIndex: Int? {
        guard let currentMatchRange else { return nil }
        return findRanges.firstIndex { $0.location == currentMatchRange.location && $0.length == currentMatchRange.length }
    }

    private var matchStatus: String {
        let ranges = findRanges
        guard !findText.isEmpty else { return "" }
        guard !ranges.isEmpty else { return "0/0" }
        let index = currentMatchIndex.map { $0 + 1 } ?? 1
        return "\(index)/\(ranges.count)"
    }

    private var effectiveFontName: String {
        NSFont(name: fontName, size: fontSize) == nil ? "Helvetica Neue" : fontName
    }

    private func displayFontName(_ font: String) -> String {
        font == "Vazirmatn-Regular" ? "Vazirmatn" : font
    }

    private func selectNextMatch() {
        let ranges = findRanges
        guard !ranges.isEmpty else {
            currentMatchRange = nil
            return
        }

        let nextIndex: Int
        if let currentMatchIndex {
            nextIndex = ranges.index(after: currentMatchIndex) == ranges.endIndex ? ranges.startIndex : ranges.index(after: currentMatchIndex)
        } else {
            nextIndex = ranges.startIndex
        }

        selectMatch(ranges[nextIndex])
    }

    private func selectPreviousMatch() {
        let ranges = findRanges
        guard !ranges.isEmpty else {
            currentMatchRange = nil
            return
        }

        let previousIndex: Int
        if let currentMatchIndex {
            previousIndex = currentMatchIndex == ranges.startIndex ? ranges.index(before: ranges.endIndex) : ranges.index(before: currentMatchIndex)
        } else {
            previousIndex = ranges.startIndex
        }

        selectMatch(ranges[previousIndex])
    }

    private func selectMatch(_ range: NSRange) {
        currentMatchRange = range
        editorSelectionRequest = EditorSelectionRequest(range: range)
    }

    private func replaceCurrentMatch() {
        guard let currentMatchRange else { return }
        let source = NSMutableString(string: markdown)
        guard NSMaxRange(currentMatchRange) <= source.length else {
            self.currentMatchRange = nil
            return
        }

        source.replaceCharacters(in: currentMatchRange, with: replaceText)
        markdown = source as String

        let replacementEnd = currentMatchRange.location + (replaceText as NSString).length
        self.currentMatchRange = nil
        selectFirstMatch(startingAt: replacementEnd)
    }

    private func replaceAllMatches() {
        guard !findText.isEmpty else { return }
        markdown = markdown.replacingOccurrences(of: findText, with: replaceText, options: [.caseInsensitive])
        currentMatchRange = nil
        editorSelectionRequest = nil
    }

    private func selectFirstMatch(startingAt location: Int) {
        let ranges = findRanges
        guard !ranges.isEmpty else { return }
        let nextRange = ranges.first { $0.location >= location } ?? ranges[0]
        selectMatch(nextRange)
    }

    private func loadMarkdown(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        markdown = content
        fileName = url.lastPathComponent
        folderName = url.deletingLastPathComponent().lastPathComponent
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let url = DropURLDecoder.fileURL(from: item) else { return }
            DispatchQueue.main.async {
                loadMarkdown(from: url)
                viewMode = .preview
            }
        }

        return true
    }

    private func exportHTML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = fileName.replacingOccurrences(of: ".md", with: ".html")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try HTMLExporter.html(for: markdown, title: fileName, accent: NSColor(accentColor).hexString)
                .write(to: url, atomically: true, encoding: .utf8)
            exportMessage = "Exported \(url.lastPathComponent)"
        } catch {
            exportMessage = error.localizedDescription
        }
    }
}

private enum ViewMode: String, CaseIterable, Identifiable {
    case split
    case code
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .split: "Split"
        case .code: "Code"
        case .preview: "Preview"
        }
    }

    var icon: String {
        switch self {
        case .split: "rectangle.split.2x1"
        case .code: "curlybraces"
        case .preview: "doc.richtext"
        }
    }
}

enum HTMLExporter {
    static func html(for markdown: String, title: String, accent: String) -> String {
        let body = MarkdownBlock.parse(markdown).map { block -> String in
            switch block {
            case .image(let alt):
                return "<h1 class=\"logo\">\(escape(alt.uppercased()))</h1><div class=\"rule\"></div>"
            case .heading(let level, let text):
                return "<h\(min(level, 6))>\(escape(text))</h\(min(level, 6))>"
            case .paragraph(let text):
                return "<p>\(inlineHTML(text))</p>"
            case .bullets(let items):
                return listHTML(items)
            case .table(let table):
                return tableHTML(table)
            case .mermaid(let source):
                return "<pre class=\"mermaid\">\(escape(source))</pre>"
            case .code(let text):
                return "<pre><code>\(escape(text))</code></pre>"
            }
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>
        body{font:16px/1.55 Vazirmatn,-apple-system,BlinkMacSystemFont,"Helvetica Neue",Arial,sans-serif;color:#141d2b;margin:56px auto;max-width:960px;padding:0 24px}
        h1{font-size:34px;line-height:1.15}h2{font-size:24px;margin-top:34px}.logo{letter-spacing:.02em}.rule{width:240px;height:6px;background:\(accent);margin-top:-12px;margin-bottom:34px}pre{background:#f1f1f1;padding:12px 16px;overflow:auto}code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}table{border-collapse:collapse;width:100%;display:block;overflow:auto}th,td{border:1px solid #ddd;padding:10px 12px;text-align:left;vertical-align:top}th{background:#eee}.mermaid{background:#f4f4f4}
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func inlineHTML(_ text: String) -> String {
        var escaped = escape(text)
        escaped = escaped.replacing(#/\*\*([^*]+)\*\*/#, with: "<strong>$1</strong>")
        escaped = escaped.replacing(#/\*([^*]+)\*/#, with: "<em>$1</em>")
        escaped = escaped.replacing(#/`([^`]+)`/#, with: "<code>$1</code>")
        return escaped
    }

    private static func checkboxHTML(_ state: CheckboxState?) -> String {
        guard let state else { return "" }
        let mark = state == .checked ? "✓" : ""
        return "<span style=\"display:inline-flex;width:14px;height:14px;margin-right:8px;align-items:center;justify-content:center;background:#e6e6e6;border:1px solid #cfcfcf;border-radius:3px;font-size:11px;font-weight:700;vertical-align:-2px\">\(mark)</span>"
    }

    private static func listHTML(_ items: [MarkdownListItem]) -> String {
        guard !items.isEmpty else { return "" }
        var html = ""
        var currentLevel = 0

        html += "<ul>"
        for item in items {
            while currentLevel < item.level {
                html += "<ul>"
                currentLevel += 1
            }

            while currentLevel > item.level {
                html += "</ul>"
                currentLevel -= 1
            }

            html += "<li>\(orderedMarkerHTML(item.marker))\(checkboxHTML(item.checkbox))\(inlineHTML(item.text))</li>"
        }

        while currentLevel > 0 {
            html += "</ul>"
            currentLevel -= 1
        }

        html += "</ul>"
        return html
    }

    private static func tableHTML(_ table: MarkdownTable) -> String {
        let headers = table.headers.map { "<th>\(inlineHTML($0))</th>" }.joined()
        let rows = table.rows.map { row in
            let cells = (0..<table.columnCount).map { index in
                "<td>\(inlineHTML(index < row.count ? row[index] : ""))</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined()
        return "<table><thead><tr>\(headers)</tr></thead><tbody>\(rows)</tbody></table>"
    }

    private static func orderedMarkerHTML(_ marker: ListMarker) -> String {
        guard case .ordered(let number) = marker else { return "" }
        return "<span style=\"display:inline-block;min-width:28px;font-weight:700\">\(number).</span>"
    }
}

private extension NSColor {
    var hexString: String {
        guard let color = usingColorSpace(.deviceRGB) else { return "#109ecc" }
        return String(format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
    }
}

private extension UTType {
    static let mdFile = UTType(filenameExtension: "md") ?? .plainText
}

private enum DropURLDecoder {
    static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let string = item as? String {
            return URL(string: string) ?? URL(fileURLWithPath: string)
        }

        return nil
    }
}
