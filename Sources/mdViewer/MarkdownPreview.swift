import SwiftUI
import WebKit

struct MarkdownPreview: View {
    let markdown: String
    let fontName: String
    let fontSize: Double
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .textSelection(.enabled)
    }

    private var blocks: [MarkdownBlock] {
        MarkdownBlock.parse(markdown)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .image(let alt):
            VStack(alignment: .leading, spacing: 8) {
                Text(alt.uppercased())
                    .font(.custom(fontName, size: 34).weight(.bold))
                    .foregroundStyle(AppColor.ink)
                    .textSelection(.enabled)
                accentColor
                    .frame(width: 240, height: 6)
            }
            .padding(.bottom, 10)
        case .heading(let level, let text):
            Text(TextDirection.displayText(text))
                .font(.custom(fontName, size: headingSize(level)).weight(level == 1 ? .bold : .semibold))
                .foregroundStyle(AppColor.ink)
                .textSelection(.enabled)
                .multilineTextAlignment(TextDirection.isRTL(text) ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: TextDirection.isRTL(text) ? .trailing : .leading)
                .padding(.top, level == 1 ? 8 : 2)
        case .paragraph(let text):
            Text(MarkdownInline.attributed(TextDirection.displayText(text), base: .custom(fontName, size: fontSize)))
                .lineSpacing(5)
                .textSelection(.enabled)
                .multilineTextAlignment(TextDirection.isRTL(text) ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: TextDirection.isRTL(text) ? .trailing : .leading)
        case .bullets(let items):
            VStack(alignment: items.contains(where: { TextDirection.isRTL($0.text) }) ? .trailing : .leading, spacing: 9) {
                ForEach(items, id: \.self) { item in
                    MarkdownListItemView(item: item, fontName: fontName, fontSize: fontSize)
                }
            }
            .frame(maxWidth: .infinity, alignment: items.contains(where: { TextDirection.isRTL($0.text) }) ? .trailing : .leading)
        case .table(let table):
            MarkdownTableView(table: table, fontName: fontName, fontSize: fontSize)
        case .mermaid(let source):
            MermaidDiagramPanel(source: source)
        case .code(let text):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .foregroundStyle(AppColor.mutedInk)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private func headingSize(_ level: Int) -> Double {
        switch level {
        case 1: 31
        case 2: 22
        default: 18
        }
    }
}

struct MarkdownListItemView: View {
    let item: MarkdownListItem
    let fontName: String
    let fontSize: Double

    private var isRTL: Bool {
        TextDirection.isRTL(item.text)
    }

    var body: some View {
        if isRTL {
            itemText
                .padding(.trailing, markerWidth + 8)
                .overlay(alignment: .topTrailing) {
                    markerView
                }
                .padding(.trailing, CGFloat(item.level) * 24)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(AppColor.ink)
        } else {
            HStack(alignment: .top, spacing: 8) {
                markerView
                itemText
            }
            .foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, CGFloat(item.level) * 24)
        }
    }

    private var itemText: some View {
        Text(MarkdownInline.attributed(TextDirection.displayText(item.text), base: .custom(fontName, size: fontSize)))
            .strikethrough(item.checkbox == .checked, color: AppColor.mutedInk)
            .textSelection(.enabled)
            .lineSpacing(5)
            .multilineTextAlignment(isRTL ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var markerView: some View {
        if let checkbox = item.checkbox {
            CheckboxIcon(state: checkbox)
                .padding(.top, 3)
                .frame(width: markerWidth, alignment: .center)
        } else {
            Text(item.marker.displayText)
                .font(.custom(fontName, size: fontSize).weight(item.marker.isOrdered ? .semibold : .regular))
                .frame(width: markerWidth, alignment: isRTL ? .trailing : .leading)
        }
    }

    private var markerWidth: CGFloat {
        item.marker.isOrdered ? 32 : 18
    }
}

struct MermaidDiagramPanel: View {
    let source: String
    @State private var isFullscreen = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MermaidDiagramView(source: source)
                .frame(minHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            Button {
                isFullscreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColor.ink)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("Fullscreen")
        }
        .sheet(isPresented: $isFullscreen) {
            VStack(spacing: 0) {
                HStack {
                    Text("Mermaid Diagram")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColor.ink)
                    Spacer()
                    Button {
                        isFullscreen = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(AppColor.toolbar)

                MermaidDiagramView(source: source)
                    .frame(minWidth: 1400, minHeight: 900)
            }
            .frame(minWidth: 1400, minHeight: 960)
        }
    }
}

struct MermaidDiagramView: NSViewRepresentable {
    let source: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(html, baseURL: Bundle.module.resourceURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: Bundle.module.resourceURL)
    }

    private var html: String {
        let mermaidScript = MermaidAssets.script
        let vazirmatnFont = MermaidAssets.vazirmatnFontBase64
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            @font-face {
              font-family: 'Vazirmatn';
              src: url(data:font/truetype;charset=utf-8;base64,\(vazirmatnFont)) format('truetype');
              font-weight: 400;
              font-style: normal;
            }
            html, body {
              margin: 0;
              padding: 0;
              background: #f4f4f4;
              color: #141d2b;
              font-family: 'Vazirmatn', -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
              user-select: none;
            }
            body {
              min-height: 300px;
              overflow: hidden;
              cursor: grab;
            }
            body.dragging {
              cursor: grabbing;
            }
            .wrap {
              box-sizing: border-box;
              min-height: 300px;
              height: 100vh;
              padding: 18px;
              display: flex;
              align-items: center;
              justify-content: center;
              overflow: hidden;
            }
            .viewport {
              transform-origin: center center;
              will-change: transform;
              transform: translateZ(0);
            }
            .mermaid {
              width: 100%;
              text-align: center;
              font-family: 'Vazirmatn', -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif !important;
            }
            .mermaid svg {
              max-width: none !important;
              height: auto;
              overflow: visible;
              shape-rendering: geometricPrecision;
              text-rendering: geometricPrecision;
              -webkit-font-smoothing: antialiased;
              font-family: 'Vazirmatn', -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif !important;
            }
            .mermaid text,
            .mermaid tspan,
            .mermaid textPath,
            .mermaid span,
            .mermaid div,
            .mermaid foreignObject,
            .mermaid .nodeLabel,
            .mermaid .edgeLabel,
            .mermaid .label,
            .mermaid .labelBkg {
              font-family: 'Vazirmatn', -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif !important;
              direction: rtl;
              unicode-bidi: isolate;
              text-align: right;
            }
            .toolbar {
              position: fixed;
              top: 10px;
              left: 10px;
              z-index: 10;
              display: flex;
              gap: 6px;
              padding: 5px;
              background: rgba(255,255,255,0.92);
              border: 1px solid rgba(0,0,0,0.08);
              border-radius: 9px;
              box-shadow: 0 8px 24px rgba(0,0,0,0.10);
            }
            button {
              width: 30px;
              height: 30px;
              border: 0;
              border-radius: 6px;
              background: #eef1f2;
              color: #141d2b;
              font-size: 15px;
              font-weight: 800;
              line-height: 30px;
            }
            button:hover {
              background: #dfe5e7;
            }
            .error {
              white-space: pre-wrap;
              font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
              font-size: 13px;
              color: #9f1d1d;
              text-align: left;
            }
          </style>
          <script>
          \(mermaidScript)
          </script>
        </head>
        <body>
          <div class="toolbar">
            <button type="button" id="zoomOut" title="Zoom out">−</button>
            <button type="button" id="zoomReset" title="Reset">1:1</button>
            <button type="button" id="zoomIn" title="Zoom in">+</button>
          </div>
          <div class="wrap">
            <div class="viewport" id="viewport">
              <pre class="mermaid">\(escapeHTML(source))</pre>
            </div>
          </div>
          <script>
            const viewport = document.getElementById('viewport');
            let scale = 1;
            let panX = 0;
            let panY = 0;
            let dragging = false;
            let lastX = 0;
            let lastY = 0;

            function applyTransform() {
              viewport.style.transform = `translate(${panX}px, ${panY}px) scale(${scale})`;
            }

            function zoom(delta) {
              scale = Math.max(0.3, Math.min(6, scale + delta));
              applyTransform();
            }

            document.getElementById('zoomIn').addEventListener('click', function() { zoom(0.15); });
            document.getElementById('zoomOut').addEventListener('click', function() { zoom(-0.15); });
            document.getElementById('zoomReset').addEventListener('click', function() {
              scale = 1;
              panX = 0;
              panY = 0;
              applyTransform();
            });

            document.addEventListener('wheel', function(event) {
              if (!event.ctrlKey && !event.metaKey) { return; }
              event.preventDefault();
              zoom(event.deltaY < 0 ? 0.12 : -0.12);
            }, { passive: false });

            document.addEventListener('pointerdown', function(event) {
              if (event.target.tagName === 'BUTTON') { return; }
              dragging = true;
              lastX = event.clientX;
              lastY = event.clientY;
              document.body.classList.add('dragging');
            });

            document.addEventListener('pointermove', function(event) {
              if (!dragging) { return; }
              panX += event.clientX - lastX;
              panY += event.clientY - lastY;
              lastX = event.clientX;
              lastY = event.clientY;
              applyTransform();
            });

            document.addEventListener('pointerup', function() {
              dragging = false;
              document.body.classList.remove('dragging');
            });

            document.addEventListener('pointercancel', function() {
              dragging = false;
              document.body.classList.remove('dragging');
            });

            mermaid.initialize({
              startOnLoad: false,
              securityLevel: 'loose',
              theme: 'default',
              htmlLabels: true,
              flowchart: { htmlLabels: true },
              themeVariables: {
                fontFamily: 'Vazirmatn, -apple-system, BlinkMacSystemFont, Helvetica Neue, Arial, sans-serif',
                fontSize: '16px'
              }
            });
            document.fonts.ready.then(function() {
              return mermaid.run({ querySelector: '.mermaid' });
            }).then(function() {
              normalizeSVG();
              fitToView();
            }).catch(function(error) {
              document.querySelector('.wrap').innerHTML = '<pre class="error">' + String(error).replace(/[&<>]/g, function(c) {
                return {'&':'&amp;','<':'&lt;','>':'&gt;'}[c];
              }) + '</pre>';
            });

            function normalizeSVG() {
              const svg = document.querySelector('.mermaid svg');
              if (!svg) { return; }
              applyPersianTextFixes(svg);
              const box = svg.getBBox();
              const padding = 24;
              svg.setAttribute('viewBox', `${box.x - padding} ${box.y - padding} ${box.width + padding * 2} ${box.height + padding * 2}`);
              svg.removeAttribute('width');
              svg.removeAttribute('height');
              svg.style.width = Math.max(box.width + padding * 2, 900) + 'px';
              svg.style.height = 'auto';
              svg.style.display = 'block';
              svg.style.margin = '0 auto';
            }

            function hasRTL(text) {
              return /[\\u0590-\\u08FF\\uFB1D-\\uFDFF\\uFE70-\\uFEFF]/.test(text || '');
            }

            function applyPersianTextFixes(root) {
              root.querySelectorAll('text, tspan, textPath, span, div, p, foreignObject, .nodeLabel, .edgeLabel, .label').forEach(function(el) {
                el.style.fontFamily = 'Vazirmatn, -apple-system, BlinkMacSystemFont, Helvetica Neue, Arial, sans-serif';
                if (hasRTL(el.textContent)) {
                  el.setAttribute('dir', 'rtl');
                  el.setAttribute('direction', 'rtl');
                  el.setAttribute('unicode-bidi', 'isolate');
                  el.style.direction = 'rtl';
                  el.style.unicodeBidi = 'isolate';
                  el.style.textAlign = 'right';
                  if (el.tagName && el.tagName.toLowerCase() === 'text') {
                    el.setAttribute('text-anchor', 'middle');
                  }
                  el.querySelectorAll('tspan').forEach(function(tspan) {
                    tspan.setAttribute('direction', 'rtl');
                    tspan.setAttribute('unicode-bidi', 'isolate');
                    tspan.style.direction = 'rtl';
                    tspan.style.unicodeBidi = 'isolate';
                    tspan.style.fontFamily = 'Vazirmatn, -apple-system, BlinkMacSystemFont, Helvetica Neue, Arial, sans-serif';
                  });
                }
              });
            }

            function fitToView() {
              const svg = document.querySelector('.mermaid svg');
              const wrap = document.querySelector('.wrap');
              if (!svg || !wrap) {
                applyTransform();
                return;
              }
              const svgWidth = svg.getBoundingClientRect().width || 900;
              const svgHeight = svg.getBoundingClientRect().height || 300;
              const availableWidth = Math.max(wrap.clientWidth - 72, 320);
              const availableHeight = Math.max(wrap.clientHeight - 72, 260);
              scale = Math.min(1.8, Math.max(0.55, Math.min(availableWidth / svgWidth, availableHeight / svgHeight)));
              panX = 0;
              panY = 0;
              applyTransform();
            }

            window.addEventListener('resize', fitToView);
          </script>
        </body>
        </html>
        """
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

struct MarkdownTableView: View {
    let table: MarkdownTable
    let fontName: String
    let fontSize: Double

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                tableRow(cells: table.headers, isHeader: true)

                ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                    tableRow(cells: row, isHeader: false)
                        .background(index.isMultiple(of: 2) ? Color.white : Color.black.opacity(0.018))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            )
            .padding(.bottom, 4)
        }
    }

    private func tableRow(cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<table.columnCount, id: \.self) { index in
                Text(MarkdownInline.attributed(cell(at: index, in: cells), base: .custom(fontName, size: max(fontSize - 1, 12))))
                    .fontWeight(isHeader ? .bold : .regular)
                    .foregroundStyle(isHeader ? AppColor.ink : AppColor.ink.opacity(0.92))
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .multilineTextAlignment(TextDirection.isRTL(cell(at: index, in: cells)) ? .trailing : .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(width: 230, alignment: TextDirection.isRTL(cell(at: index, in: cells)) ? .topTrailing : .topLeading)
                    .background(isHeader ? Color.black.opacity(0.075) : Color.clear)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.black.opacity(0.08))
                            .frame(width: 1)
                    }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func cell(at index: Int, in cells: [String]) -> String {
        index < cells.count ? cells[index] : ""
    }
}

struct CheckboxIcon: View {
    let state: CheckboxState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.black.opacity(0.08))
                .frame(width: 16, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.black.opacity(0.16), lineWidth: 1)
                )

            if state == .checked {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(AppColor.ink)
            }
        }
        .frame(width: 18, height: 18)
    }
}

enum MarkdownBlock: Equatable {
    case image(String)
    case heading(Int, String)
    case paragraph(String)
    case bullets([MarkdownListItem])
    case table(MarkdownTable)
    case mermaid(String)
    case code(String)

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var bullets: [MarkdownListItem] = []
        var codeLines: [String] = []
        var isInsideFencedCode = false
        var fencedCodeLanguage: String?

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }

        func flushBullets() {
            guard !bullets.isEmpty else { return }
            blocks.append(.bullets(bullets))
            bullets.removeAll()
        }

        func flushCode() {
            let code = codeLines.joined(separator: "\n")
            if isMermaidFence(language: fencedCodeLanguage, code: code) {
                blocks.append(.mermaid(code))
            } else {
                blocks.append(.code(code))
            }
            codeLines.removeAll()
            fencedCodeLanguage = nil
        }

        var index = 0
        while index < lines.count {
            let rawLine = lines[index]
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if let fence = parseFence(line) {
                if isInsideFencedCode {
                    flushCode()
                    isInsideFencedCode = false
                } else {
                    flushParagraph()
                    flushBullets()
                    isInsideFencedCode = true
                    fencedCodeLanguage = fence.info
                }
                index += 1
                continue
            }

            if isInsideFencedCode {
                codeLines.append(rawLine)
                index += 1
                continue
            }

            if line.localizedCaseInsensitiveContains("<table") {
                flushParagraph()
                flushBullets()
                var htmlLines = [rawLine]
                index += 1
                while index < lines.count {
                    htmlLines.append(lines[index])
                    if lines[index].localizedCaseInsensitiveContains("</table>") {
                        index += 1
                        break
                    }
                    index += 1
                }

                if let table = MarkdownTable.parseHTML(htmlLines.joined(separator: "\n")) {
                    blocks.append(.table(table))
                } else {
                    blocks.append(.paragraph(htmlLines.joined(separator: " ")))
                }
                continue
            }

            if line.isEmpty {
                flushParagraph()
                flushBullets()
                index += 1
                continue
            }

            if let table = parseTable(startingAt: index, in: lines) {
                flushParagraph()
                flushBullets()
                blocks.append(table.block)
                index = table.nextIndex
                continue
            }

            if line.hasPrefix("![") {
                flushParagraph()
                flushBullets()
                let alt = line.dropFirst(2).split(separator: "]").first.map(String.init) ?? "Image"
                blocks.append(.image(alt.replacingOccurrences(of: " logo", with: "")))
            } else if line.hasPrefix("#") {
                flushParagraph()
                flushBullets()
                let level = line.prefix(while: { $0 == "#" }).count
                let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level, text))
            } else if let listItem = MarkdownListItem.parse(rawLine) {
                flushParagraph()
                bullets.append(listItem)
            } else if line.hasPrefix("`"), line.hasSuffix("`"), line.count > 1 {
                flushParagraph()
                flushBullets()
                blocks.append(.code(String(line.dropFirst().dropLast())))
            } else {
                flushBullets()
                paragraph.append(line)
            }

            index += 1
        }

        flushParagraph()
        flushBullets()
        if isInsideFencedCode {
            flushCode()
        }
        return blocks
    }

    private static func parseFence(_ line: String) -> (marker: Character, count: Int, info: String)? {
        guard let marker = line.first, marker == "`" || marker == "~" else { return nil }
        let count = line.prefix { $0 == marker }.count
        guard count >= 3 else { return nil }
        let info = String(line.dropFirst(count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return (marker, count, info)
    }

    private static func isMermaidFence(language: String?, code: String) -> Bool {
        let normalizedLanguage = language?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .first?
            .lowercased()

        if normalizedLanguage == "mermaid" {
            return true
        }

        let firstLine = code
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        return [
            "flowchart ",
            "graph ",
            "sequencediagram",
            "classdiagram",
            "statediagram",
            "erdiagram",
            "journey",
            "gantt",
            "pie",
            "mindmap",
            "timeline"
        ].contains { firstLine.hasPrefix($0) }
    }

    private static func parseTable(startingAt index: Int, in lines: [String]) -> (block: MarkdownBlock, nextIndex: Int)? {
        guard index + 1 < lines.count else { return nil }

        let headerLine = lines[index].trimmingCharacters(in: .whitespaces)
        let separatorLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard isTableRow(headerLine), isTableSeparator(separatorLine) else { return nil }

        let headers = tableCells(from: headerLine)
        guard !headers.isEmpty else { return nil }

        var rows: [[String]] = []
        var nextIndex = index + 2
        while nextIndex < lines.count {
            let rowLine = lines[nextIndex].trimmingCharacters(in: .whitespaces)
            guard isTableRow(rowLine), !isTableSeparator(rowLine) else { break }
            rows.append(tableCells(from: rowLine))
            nextIndex += 1
        }

        return (.table(MarkdownTable(headers: headers, rows: rows)), nextIndex)
    }

    private static func isTableRow(_ line: String) -> Bool {
        line.contains("|")
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(from: line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 3 else { return false }
            return trimmed.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func tableCells(from line: String) -> [String] {
        var normalized = line.trimmingCharacters(in: .whitespaces)
        if normalized.first == "|" {
            normalized.removeFirst()
        }
        if normalized.last == "|" {
            normalized.removeLast()
        }
        return normalized
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

struct MarkdownTable: Equatable {
    let headers: [String]
    let rows: [[String]]

    var columnCount: Int {
        ([headers.count] + rows.map(\.count)).max() ?? 0
    }

    static func parseHTML(_ html: String) -> MarkdownTable? {
        let headerCells = cells(tag: "th", in: html)
        let rowMatches = matches(pattern: #"<tr\b[^>]*>(.*?)</tr>"#, in: html)
        var rows: [[String]] = []

        for rowHTML in rowMatches {
            let dataCells = cells(tag: "td", in: rowHTML)
            if !dataCells.isEmpty {
                rows.append(dataCells)
            }
        }

        guard !headerCells.isEmpty || !rows.isEmpty else { return nil }
        return MarkdownTable(headers: headerCells.isEmpty ? rows.removeFirst() : headerCells, rows: rows)
    }

    private static func cells(tag: String, in html: String) -> [String] {
        matches(pattern: #"<\#(tag)\b[^>]*>(.*?)</\#(tag)>"#, in: html)
            .map { cleanHTML($0) }
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }

    private static func cleanHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"<code\b[^>]*>(.*?)</code>"#, with: "`$1`", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MermaidAssets {
    static var script: String {
        guard let url = Bundle.module.url(forResource: "mermaid.min", withExtension: "js"),
              let script = try? String(contentsOf: url, encoding: .utf8) else {
            return "document.body.innerHTML = '<pre class=\"error\">Mermaid script not found.</pre>';"
        }
        return script
    }

    static var vazirmatnFontBase64: String {
        guard let url = Bundle.module.url(forResource: "Vazirmatn-Regular", withExtension: "ttf", subdirectory: "Fonts"),
              let data = try? Data(contentsOf: url) else {
            return ""
        }
        return data.base64EncodedString()
    }
}

enum TextDirection {
    static func isRTL(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }

    static func displayText(_ text: String) -> String {
        guard isRTL(text) else { return text }
        return "\u{202B}\(text)\u{202C}"
    }
}

struct MarkdownListItem: Equatable, Hashable {
    let text: String
    let checkbox: CheckboxState?
    let level: Int
    let marker: ListMarker

    static func parse(_ rawLine: String) -> MarkdownListItem? {
        let leadingSpaces = rawLine.prefix { $0 == " " || $0 == "\t" }.reduce(0) { total, char in
            total + (char == "\t" ? 4 : 1)
        }
        let level = max(0, leadingSpaces / 2)
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        let marker: ListMarker
        let rawItemText: String

        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            marker = .bullet
            rawItemText = String(line.dropFirst(2))
        } else if let ordered = parseOrderedMarker(line) {
            marker = .ordered(ordered.number)
            rawItemText = ordered.text
        } else {
            return nil
        }

        let trimmed = rawItemText.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[ ]") {
            return MarkdownListItem(text: String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces), checkbox: .unchecked, level: level, marker: marker)
        }

        if trimmed.lowercased().hasPrefix("[x]") {
            return MarkdownListItem(text: String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces), checkbox: .checked, level: level, marker: marker)
        }

        return MarkdownListItem(text: trimmed, checkbox: nil, level: level, marker: marker)
    }

    private static func parseOrderedMarker(_ line: String) -> (number: Int, text: String)? {
        guard let regex = try? NSRegularExpression(pattern: #"^(\d+)[\.\)]\s+(.+)$"#) else {
            return nil
        }

        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)
        guard let match = regex.firstMatch(in: line, range: fullRange),
              match.numberOfRanges == 3,
              let number = Int(nsLine.substring(with: match.range(at: 1))) else {
            return nil
        }

        return (number, nsLine.substring(with: match.range(at: 2)))
    }
}

enum CheckboxState: Equatable, Hashable {
    case unchecked
    case checked
}

enum ListMarker: Equatable, Hashable {
    case bullet
    case ordered(Int)

    var displayText: String {
        switch self {
        case .bullet:
            return "•"
        case .ordered(let number):
            return "\(number)."
        }
    }

    var isOrdered: Bool {
        if case .ordered = self {
            return true
        }
        return false
    }
}
