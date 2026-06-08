import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var documents: [MarkdownDocument]
    @State private var selectedDocumentID: MarkdownDocument.ID?
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
    private let droppableTypes = [UTType.fileURL.identifier, UTType.url.identifier, UTType.text.identifier]

    init(initialFileURL: URL? = nil) {
        if let initialFileURL,
           let content = try? String(contentsOf: initialFileURL, encoding: .utf8) {
            let document = MarkdownDocument(url: initialFileURL, markdown: content)
            _documents = State(initialValue: [document])
            _selectedDocumentID = State(initialValue: document.id)
        } else {
            _documents = State(initialValue: [])
            _selectedDocumentID = State(initialValue: nil)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                topBar
                tabBar
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
                openMarkdown(from: url)
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
                Text(activeDocument?.fileName ?? "No document")
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

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(documents) { document in
                    documentTab(document)
                }

                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppColor.ink)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppColor.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Open file")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .frame(height: 56)
        .background(AppColor.toolbar.opacity(0.82))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColor.hairline)
                .frame(height: 1)
        }
    }

    private func documentTab(_ document: MarkdownDocument) -> some View {
        let isSelected = document.id == selectedDocumentID
        return HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? .white.opacity(0.9) : AppColor.mutedInk)

            Text(document.fileName)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isSelected ? .white : AppColor.ink)
                .frame(maxWidth: 170, alignment: .leading)

            Button {
                closeDocument(document)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(isSelected ? .white.opacity(0.74) : AppColor.mutedInk)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Close tab")
        }
        .padding(.leading, 12)
        .padding(.trailing, 7)
        .frame(height: 36)
        .background(isSelected ? AppColor.accent : Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isSelected ? AppColor.accent : AppColor.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectDocument(document.id)
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
        if activeDocument == nil {
            emptyState
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
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
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AppColor.mutedInk)

            VStack(spacing: 6) {
                Text("No document open")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColor.ink)
                Text("Open or drop Markdown files to start reading.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColor.mutedInk)
            }

            actionButton(title: "Open file", icon: "folder") {
                showImporter = true
            }
            .frame(width: 180)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColor.hairline, lineWidth: 1)
        )
    }

    private var editorPanel: some View {
        VStack(spacing: 0) {
            panelHeader(title: "Code", icon: "curlybraces") {
                Text("Markdown source")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            findReplaceBar
            MarkdownEditor(text: activeMarkdownBinding, selectionRequest: $editorSelectionRequest)
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
            panelHeader(title: "Preview", icon: "doc.richtext") {
                Button {
                    reloadActiveDocument()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .black))
                        Text("Reload")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(AppColor.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Color.black.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(AppColor.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(activeDocument?.url == nil)
                .help("Reload file")
            }
                .background(AppColor.paper)
            MarkdownPreview(
                documentID: activeDocument?.id,
                markdown: activeDocument?.markdown ?? "",
                fontName: effectiveFontName,
                fontSize: fontSize,
                accentColor: accentColor,
                scrollY: activeDocument?.scrollY ?? 0,
                onFileDrop: { urls in
                    loadDroppedMarkdown(from: urls)
                },
                onScrollChange: { scrollY in
                    setActiveScrollY(scrollY)
                }
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColor.paper)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColor.hairline, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func panelHeader<Trailing: View>(title: String, icon: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .bold))
            Spacer()
            trailing()
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
        guard let markdown = activeDocument?.markdown else { return 0 }
        return markdown
            .split { $0.isWhitespace || $0.isNewline }
            .filter { !$0.isEmpty }
            .count
    }

    private var lineCount: Int {
        guard let markdown = activeDocument?.markdown else { return 0 }
        return max(markdown.components(separatedBy: .newlines).count, 1)
    }

    private var findRanges: [NSRange] {
        guard !findText.isEmpty, let markdown = activeDocument?.markdown else { return [] }
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

    private var activeDocument: MarkdownDocument? {
        guard let selectedDocumentID else { return nil }
        return documents.first { $0.id == selectedDocumentID }
    }

    private var activeDocumentIndex: Int? {
        guard let selectedDocumentID else { return nil }
        return documents.firstIndex { $0.id == selectedDocumentID }
    }

    private var activeMarkdownBinding: Binding<String> {
        Binding(
            get: { activeDocument?.markdown ?? "" },
            set: { setActiveMarkdown($0) }
        )
    }

    private func setActiveMarkdown(_ value: String) {
        guard let activeDocumentIndex else { return }
        documents[activeDocumentIndex].markdown = value
    }

    private func setActiveScrollY(_ value: Double) {
        guard let activeDocumentIndex else { return }
        documents[activeDocumentIndex].scrollY = value
    }

    private func selectDocument(_ id: MarkdownDocument.ID) {
        selectedDocumentID = id
        currentMatchRange = nil
        editorSelectionRequest = nil
    }

    private func closeDocument(_ document: MarkdownDocument) {
        guard documents.count > 1 else {
            documents = []
            selectedDocumentID = nil
            currentMatchRange = nil
            editorSelectionRequest = nil
            return
        }

        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        let wasSelected = document.id == selectedDocumentID
        documents.remove(at: index)

        if wasSelected {
            let nextIndex = min(index, documents.count - 1)
            selectDocument(documents[nextIndex].id)
        }
    }

    private func reloadDocument(_ document: MarkdownDocument) {
        guard let url = document.url,
              let index = documents.firstIndex(where: { $0.id == document.id }) else { return }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        documents[index].markdown = content
        selectDocument(document.id)
    }

    private func reloadActiveDocument() {
        guard let activeDocument else { return }
        reloadDocument(activeDocument)
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
        guard let currentMatchRange, let markdown = activeDocument?.markdown else { return }
        let source = NSMutableString(string: markdown)
        guard NSMaxRange(currentMatchRange) <= source.length else {
            self.currentMatchRange = nil
            return
        }

        source.replaceCharacters(in: currentMatchRange, with: replaceText)
        setActiveMarkdown(source as String)

        let replacementEnd = currentMatchRange.location + (replaceText as NSString).length
        self.currentMatchRange = nil
        selectFirstMatch(startingAt: replacementEnd)
    }

    private func replaceAllMatches() {
        guard !findText.isEmpty, let markdown = activeDocument?.markdown else { return }
        setActiveMarkdown(markdown.replacingOccurrences(of: findText, with: replaceText, options: [.caseInsensitive]))
        currentMatchRange = nil
        editorSelectionRequest = nil
    }

    private func selectFirstMatch(startingAt location: Int) {
        let ranges = findRanges
        guard !ranges.isEmpty else { return }
        let nextRange = ranges.first { $0.location >= location } ?? ranges[0]
        selectMatch(nextRange)
    }

    private func openMarkdown(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let standardizedURL = url.standardizedFileURL

        if let existingIndex = documents.firstIndex(where: { $0.url?.standardizedFileURL == standardizedURL }) {
            documents[existingIndex].markdown = content
            selectDocument(documents[existingIndex].id)
            return
        }

        let document = MarkdownDocument(url: standardizedURL, markdown: content)
        documents.append(document)
        selectDocument(document.id)
    }

    private func loadDroppedMarkdown(from url: URL) {
        loadDroppedMarkdown(from: [url])
    }

    private func loadDroppedMarkdown(from urls: [URL]) {
        urls.forEach { openMarkdown(from: $0) }
        viewMode = .preview
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { provider in
            droppableTypes.contains { provider.hasItemConformingToTypeIdentifier($0) }
        }
        guard !fileProviders.isEmpty else {
            return false
        }

        for provider in fileProviders {
            let type = droppableTypes.first { provider.hasItemConformingToTypeIdentifier($0) } ?? UTType.fileURL.identifier
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                let urls = DropURLDecoder.fileURLs(from: item)
                guard !urls.isEmpty else { return }
                DispatchQueue.main.async {
                    loadDroppedMarkdown(from: urls)
                }
            }
        }

        return true
    }

    private func exportHTML() {
        guard let activeDocument else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = activeDocument.fileName.replacingOccurrences(of: ".md", with: ".html")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try MarkdownHTMLRenderer.html(
                for: activeDocument.markdown,
                title: activeDocument.fileName,
                fontName: effectiveFontName,
                fontSize: fontSize,
                accent: NSColor(accentColor).hexString
            )
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

private struct MarkdownDocument: Identifiable, Equatable {
    let id: UUID
    var url: URL?
    var fileName: String
    var folderName: String
    var markdown: String
    var scrollY: Double

    init(id: UUID = UUID(), url: URL?, markdown: String) {
        self.id = id
        self.url = url
        self.fileName = url?.lastPathComponent ?? "README.md"
        self.folderName = url?.deletingLastPathComponent().lastPathComponent ?? "introToMarkdown"
        self.markdown = markdown
        self.scrollY = 0
    }

    static let sample = MarkdownDocument(url: nil, markdown: sampleMarkdown)
}

private extension UTType {
    static let mdFile = UTType(filenameExtension: "md") ?? .plainText
}

private enum DropURLDecoder {
    static func fileURLs(from item: NSSecureCoding?) -> [URL] {
        if let url = item as? URL {
            return [url]
        }

        if let urls = item as? [URL] {
            return urls
        }

        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                return [url]
            }
            if let string = String(data: data, encoding: .utf8) {
                return fileURLs(from: string as NSString)
            }
        }

        if let string = item as? String {
            let values = string
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return values.map { URL(string: $0) ?? URL(fileURLWithPath: $0) }
        }

        return []
    }
}
