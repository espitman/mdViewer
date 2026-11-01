import AppKit
import Foundation
import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct MarkdownPreview: NSViewRepresentable {
    let documentID: UUID?
    let markdown: String
    var documentURL: URL? = nil
    let fontName: String
    let fontSize: Double
    let accentColor: Color
    let scrollY: Double
    var onLoadingChange: (Bool) -> Void = { _ in }
    var onFileDrop: ([URL]) -> Void = { _ in }
    var onScrollChange: (Double) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadingChange: onLoadingChange, onScrollChange: onScrollChange, onFileDrop: onFileDrop)
    }

    func makeNSView(context: Context) -> DroppableMarkdownWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.add(context.coordinator, name: "scroll")
        configuration.userContentController.add(context.coordinator, name: "openLink")

        let webView = DroppableMarkdownWebView(frame: .zero, configuration: configuration)
        webView.renderFingerprint = renderFingerprint
        webView.onFileDrop = onFileDrop
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        context.coordinator.setLoading(true)
        webView.loadPreviewHTML(html, baseURL: documentURL?.deletingLastPathComponent() ?? Bundle.module.resourceURL)
        return webView
    }

    func updateNSView(_ webView: DroppableMarkdownWebView, context: Context) {
        context.coordinator.onLoadingChange = onLoadingChange
        context.coordinator.onScrollChange = onScrollChange
        context.coordinator.onFileDrop = onFileDrop
        webView.onFileDrop = onFileDrop
        webView.navigationDelegate = context.coordinator
        guard webView.renderFingerprint != renderFingerprint else { return }
        webView.renderFingerprint = renderFingerprint
        context.coordinator.setLoading(true)
        webView.loadPreviewHTML(html, baseURL: documentURL?.deletingLastPathComponent() ?? Bundle.module.resourceURL)
    }

    private var html: String {
        MarkdownHTMLRenderer.html(
            for: markdown,
            title: "Preview",
            fontName: fontName,
            fontSize: fontSize,
            accent: NSColor(accentColor).hexString,
            initialScrollY: scrollY,
            baseURL: documentURL?.deletingLastPathComponent()
        )
    }

    private var renderFingerprint: String {
        [
            documentID?.uuidString ?? "empty",
            markdown,
            fontName,
            "\(fontSize)",
            NSColor(accentColor).hexString
        ].joined(separator: "\u{1F}")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onLoadingChange: (Bool) -> Void
        var onScrollChange: (Double) -> Void
        var onFileDrop: ([URL]) -> Void

        init(onLoadingChange: @escaping (Bool) -> Void, onScrollChange: @escaping (Double) -> Void, onFileDrop: @escaping ([URL]) -> Void) {
            self.onLoadingChange = onLoadingChange
            self.onScrollChange = onScrollChange
            self.onFileDrop = onFileDrop
        }

        func setLoading(_ isLoading: Bool) {
            DispatchQueue.main.async {
                self.onLoadingChange(isLoading)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            openLink(url)
        }

        private func openLink(_ requestedURL: URL) {
            let url = PreviewLocalResources.fileURL(for: requestedURL) ?? requestedURL
            if url.isFileURL, ["md", "markdown", "mdown", "mkd"].contains(url.pathExtension.lowercased()) {
                onFileDrop([url])
            } else if url.isFileURL || ["http", "https", "mailto", "xmpp"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            setLoading(false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            setLoading(false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            setLoading(false)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "openLink", let value = message.body as? String, let url = URL(string: value) {
                openLink(url)
                return
            }
            guard message.name == "scroll" else { return }

            if let value = message.body as? Double {
                onScrollChange(value)
            } else if let value = message.body as? NSNumber {
                onScrollChange(value.doubleValue)
            }
        }
    }
}

final class DroppableMarkdownWebView: WKWebView {
    var renderFingerprint: String?
    var onFileDrop: ([URL]) -> Void = { _ in }
    // A custom scheme lets WebKit read relative image assets on macOS versions
    // that block file:// subresources of pages created with loadHTMLString.
    // HTML export continues to use the document's original file:// base URL.
    func loadPreviewHTML(_ html: String, baseURL: URL?) {
        guard let baseURL, baseURL.isFileURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            loadHTMLString(html, baseURL: baseURL)
            return
        }
        components.scheme = PreviewLocalResources.scheme
        let rebasedHTML = html.replacingOccurrences(of: "<base href=\"file:", with: "<base href=\"\(PreviewLocalResources.scheme):")
        loadHTMLString(rebasedHTML, baseURL: components.url)
    }

    override init(frame frameRect: NSRect, configuration: WKWebViewConfiguration) {
        configuration.setURLSchemeHandler(PreviewLocalResources(), forURLScheme: PreviewLocalResources.scheme)
        super.init(frame: frameRect, configuration: configuration)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        onFileDrop(urls)
        return true
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty {
            return urls
        }

        if let value = pasteboard.string(forType: .fileURL),
           let url = URL(string: value) {
            return [url]
        }

        if let value = pasteboard.string(forType: .URL),
           let url = URL(string: value),
           url.isFileURL {
            return [url]
        }

        if let value = pasteboard.string(forType: .string) {
            if let url = URL(string: value), url.isFileURL {
                return [url]
            }
            let paths = value
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return paths.map { URL(fileURLWithPath: $0) }
        }

        return []
    }
}

final class PreviewLocalResources: NSObject, WKURLSchemeHandler {
    static let scheme = "mdviewer-local"

    static func fileURL(for url: URL) -> URL? {
        guard url.scheme == scheme, url.host == nil || url.host == "" else { return nil }
        return URL(fileURLWithPath: url.path).standardizedFileURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url, let fileURL = Self.fileURL(for: requestURL) else {
            urlSchemeTask.didFailWithError(URLError(.unsupportedURL))
            return
        }
        do {
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            let mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            let response = URLResponse(url: requestURL, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // File reads above complete synchronously; no pending request to cancel.
    }
}

enum MarkdownHTMLRenderer {
    static func html(
        for markdown: String,
        title: String,
        fontName: String = "Vazirmatn-Regular",
        fontSize: Double = 16,
        accent: String = "#109ECC",
        initialScrollY: Double = 0,
        baseURL: URL? = nil
    ) -> String {
        let markdownEngineScript = ResourceLoader.string("markdown-engine.min", "js")
        let highlightScript = ResourceLoader.string("highlight.min", "js")
        let highlightCSS = ResourceLoader.string("highlight-github.min", "css")
        let mermaidScript = ResourceLoader.string("mermaid.min", "js")
        let vazirmatnFont = ResourceLoader.base64("Fonts/Vazirmatn-Regular", "ttf")
        let source = jsonString(markdown)
        let escapedTitle = escapeHTML(title)
        let cssFontName = fontName == "Vazirmatn-Regular" ? "Vazirmatn" : fontName

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapedTitle)</title>
          \(baseURL.map { "<base href=\"\(escapeHTML($0.absoluteString.hasSuffix("/") ? $0.absoluteString : $0.absoluteString + "/"))\">" } ?? "")
          <style>
            @font-face {
              font-family: 'Vazirmatn';
              src: url(data:font/truetype;charset=utf-8;base64,\(vazirmatnFont)) format('truetype');
              font-weight: 100 900;
              font-style: normal;
            }

            \(highlightCSS)

            :root {
              --accent: \(accent);
              --ink: #141d2b;
              --muted: #717684;
              --paper: #ffffff;
              --soft: #f4f5f7;
              --line: #dfe3e8;
              --code-bg: #f2f3f5;
              --font-size: \(fontSize)px;
              --reader-font: '\(cssFontName)', Vazirmatn, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              --mono-font: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
            }

            html, body {
              margin: 0;
              min-height: 100%;
              width: 100%;
              min-width: 0;
              background: var(--paper);
              color: var(--ink);
              font-family: var(--reader-font);
              font-size: var(--font-size);
              line-height: 1.72;
              text-size-adjust: 100%;
              -webkit-font-smoothing: antialiased;
            }

            body {
              overflow: auto;
            }

            .markdown-body {
              box-sizing: border-box;
              width: min(100%, 1040px);
              max-width: 100%;
              min-width: 0;
              position: relative;
              margin: 0 auto;
              padding: 46px 56px 80px;
              overflow-wrap: anywhere;
              user-select: text;
            }

            /* HTML width attributes must never enlarge the document viewport.
               Wide code and tables keep their own scrollable containers. */
            .markdown-body > *,
            .markdown-body [width],
            .markdown-body :is(pre, table, details, blockquote, .markdown-alert, .diagram-shell) {
              box-sizing: border-box;
              max-width: 100%;
            }

            .markdown-body:empty::before {
              content: "Open a Markdown file";
              color: var(--muted);
              font-weight: 700;
            }

            h1, h2, h3, h4, h5, h6 {
              margin: 1.3em 0 .58em;
              line-height: 1.26;
              font-weight: 850;
              letter-spacing: 0;
            }

            h1:first-child, h2:first-child, h3:first-child {
              margin-top: 0;
            }

            h1 {
              font-size: clamp(2.15rem, 2.15rem, 2.15rem);
              padding-bottom: .28em;
              border-bottom: 6px solid var(--accent);
            }

            h2 {
              font-size: 1.58rem;
              padding-bottom: .2em;
            }

            h3 { font-size: 1.25rem; }
            h4 { font-size: 1.08rem; }
            h5, h6 { font-size: 1rem; color: var(--muted); }

            p, blockquote, ul, ol, table, pre, .diagram-shell {
              margin-top: 0;
              margin-bottom: 1.18em;
            }

            a {
              color: var(--accent);
              text-decoration-thickness: 1px;
              text-underline-offset: 3px;
            }

            strong { font-weight: 800; }
            em { font-style: italic; }

            blockquote {
              color: #424a57;
              border-left: 4px solid var(--line);
              padding: .2em 1em;
              background: #fafafa;
              border-radius: 0 7px 7px 0;
            }

            [dir="rtl"] {
              direction: rtl;
              text-align: right;
              unicode-bidi: isolate;
            }

            [dir="rtl"] blockquote,
            blockquote[dir="rtl"] {
              border-left: 0;
              border-right: 4px solid var(--line);
              border-radius: 7px 0 0 7px;
            }

            ul, ol {
              padding-left: 1.65em;
            }

            li {
              margin: .24em 0;
              padding-left: .08em;
            }

            li[dir="rtl"] {
              padding-left: 0;
              padding-right: .08em;
            }

            ul[dir="rtl"], ol[dir="rtl"] {
              padding-left: 0;
              padding-right: 1.65em;
            }

            .task-list-item {
              list-style: none;
            }

            .task-list-item input[type="checkbox"] {
              appearance: none;
              width: 15px;
              height: 15px;
              margin: 0 .48em 0 0;
              vertical-align: -2px;
              border: 1px solid #c7ccd4;
              border-radius: 4px;
              background: #e9ebef;
              display: inline-grid;
              place-content: center;
            }

            .task-list-item[dir="rtl"] input[type="checkbox"] {
              margin: 0 0 0 .48em;
            }

            .task-list-item input[type="checkbox"]:checked::after {
              content: "✓";
              color: #293241;
              font-size: 12px;
              font-weight: 900;
              line-height: 1;
            }

            code {
              font-family: var(--mono-font);
              color: #6e7380;
              background: rgba(27, 31, 36, .055);
              border-radius: 5px;
              padding: .14em .34em;
              direction: ltr;
              unicode-bidi: isolate;
              overflow-wrap: anywhere;
            }

            pre {
              box-sizing: border-box;
              overflow: auto;
              padding: 16px 18px;
              border-radius: 8px;
              border: 1px solid rgba(27, 31, 36, .08);
              background: var(--code-bg);
              line-height: 1.55;
              direction: ltr;
              text-align: left;
            }

            pre code {
              display: block;
              padding: 0;
              color: #24292f;
              background: transparent;
              border-radius: 0;
              white-space: pre;
              overflow-wrap: normal;
              word-break: normal;
            }

            table {
              display: block;
              width: max-content;
              max-width: 100%;
              overflow: auto;
              border-collapse: collapse;
              border-spacing: 0;
              border: 1px solid var(--line);
              border-radius: 8px;
            }

            thead {
              background: #f1f3f5;
            }

            th, td {
              min-width: 120px;
              padding: 10px 13px;
              border: 1px solid var(--line);
              vertical-align: top;
              text-align: left;
            }

            th {
              font-weight: 800;
            }

            th[dir="rtl"], td[dir="rtl"] {
              text-align: right;
            }

            th[align="left"], td[align="left"] { text-align: left; }
            th[align="right"], td[align="right"] { text-align: right; }
            th[align="center"], td[align="center"] { text-align: center; }

            img {
              max-width: 100%;
              height: auto;
              border-radius: 8px;
            }

            details { margin-bottom: 1.18em; }
            summary { cursor: pointer; font-weight: 700; }
            kbd { padding: 2px 5px; border: 1px solid var(--line); border-radius: 4px; box-shadow: inset 0 -1px var(--line); font: .85em var(--mono-font); }
            .footnotes { border-top: 1px solid var(--line); font-size: .9em; margin-top: 2em; }
            .sr-only { position: absolute; inset-inline-start: 0; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0,0,0,0); }
            .markdown-alert { border-inline-start: 4px solid #0969da; padding: .4em 1em; margin-bottom: 1.18em; }
            .markdown-alert-title { font-weight: 700; color: #0969da; margin-bottom: .5em; }
            .markdown-alert-tip { border-color: #1a7f37; }
            .markdown-alert-tip > .markdown-alert-title { color: #1a7f37; }
            .markdown-alert-important { border-color: #8250df; }
            .markdown-alert-important > .markdown-alert-title { color: #8250df; }
            .markdown-alert-warning { border-color: #9a6700; }
            .markdown-alert-warning > .markdown-alert-title { color: #9a6700; }
            .markdown-alert-caution { border-color: #cf222e; }
            .markdown-alert-caution > .markdown-alert-title { color: #cf222e; }
            math { direction: ltr; unicode-bidi: isolate; }
            math[display="block"] { max-width: 100%; overflow-x: auto; padding: 1em 0; }
            pre code.hljs { background: transparent; padding: 0; }

            hr {
              height: 1px;
              border: 0;
              background: var(--line);
              margin: 2em 0;
            }

            .diagram-shell {
              position: relative;
              border: 1px solid var(--line);
              border-radius: 10px;
              background: #f7f8fa;
              overflow: hidden;
            }

            .diagram-toolbar {
              position: absolute;
              top: 10px;
              right: 10px;
              z-index: 4;
              display: flex;
              gap: 6px;
            }

            .diagram-toolbar button {
              min-width: 32px;
              height: 30px;
              padding: 0 9px;
              border: 1px solid rgba(20, 29, 43, .12);
              border-radius: 7px;
              background: rgba(255, 255, 255, .92);
              color: var(--ink);
              font: 800 13px var(--reader-font);
              line-height: 1;
              white-space: nowrap;
              cursor: pointer;
            }

            .diagram-stage {
              min-height: 360px;
              overflow: hidden;
              cursor: grab;
              touch-action: none;
            }

            .diagram-stage.dragging {
              cursor: grabbing;
            }

            .diagram-content {
              width: max-content;
              min-width: 100%;
              min-height: 360px;
              transform-origin: 0 0;
              display: grid;
              place-items: center;
              padding: 56px 36px 36px;
              box-sizing: border-box;
            }

            .diagram-content svg {
              max-width: none !important;
              height: auto !important;
              overflow: visible;
            }

            .diagram-content svg text,
            .diagram-content svg tspan,
            .diagram-content .label,
            .diagram-content .nodeLabel,
            .diagram-content foreignObject,
            .diagram-content foreignObject div,
            .diagram-content foreignObject span {
              font-family: Vazirmatn, var(--reader-font) !important;
            }

            .diagram-content .rtl-label,
            .diagram-content .rtl-label * {
              direction: rtl !important;
              text-align: right !important;
              unicode-bidi: plaintext !important;
            }

            .diagram-shell.fullscreen {
              position: fixed;
              inset: 18px;
              z-index: 9999;
              background: #f7f8fa;
              box-shadow: 0 22px 80px rgba(0, 0, 0, .24);
            }

            .diagram-shell.fullscreen .diagram-stage,
            .diagram-shell.fullscreen .diagram-content {
              min-height: calc(100vh - 36px);
            }

            .render-error {
              padding: 18px;
              color: #8a1f17;
              background: #fff3f2;
              border: 1px solid #ffd1cc;
              border-radius: 8px;
              white-space: pre-wrap;
            }

            @media (max-width: 760px) {
              .markdown-body {
                padding: 30px 22px 64px;
              }

              h1 {
                font-size: 1.75rem;
              }

              th, td {
                min-width: 96px;
              }
            }
          </style>
        </head>
        <body>
          <main id="content" class="markdown-body"></main>

          <script>\(markdownEngineScript)</script>
          <script>\(highlightScript)</script>
          <script>\(mermaidScript)</script>
          <script>
            const markdownSource = \(source);
            const initialScrollY = \(max(0, initialScrollY));
            const rtlPattern = /[\\u0590-\\u05FF\\u0600-\\u06FF\\u0750-\\u077F\\u08A0-\\u08FF\\uFB50-\\uFDFF\\uFE70-\\uFEFF]/;

            function escapeHtml(value) {
              return String(value)
                .replaceAll('&', '&amp;')
                .replaceAll('<', '&lt;')
                .replaceAll('>', '&gt;')
                .replaceAll('"', '&quot;');
            }

            function hasRTL(value) {
              return rtlPattern.test(value || '');
            }

            function enhanceCode(root) {
              root.querySelectorAll('pre > code').forEach((code) => {
                if (code.classList.contains('language-mermaid')) {
                  const shell = document.createElement('section');
                  shell.className = 'diagram-shell';
                  shell.innerHTML = `<div class="diagram-toolbar">
                    <button type="button" data-action="zoom-out" title="Zoom out">−</button>
                    <button type="button" data-action="reset" title="Reset">1:1</button>
                    <button type="button" data-action="zoom-in" title="Zoom in">+</button>
                    <button type="button" data-action="fullscreen" title="Fullscreen">⛶</button>
                    </div><div class="diagram-stage"><div class="diagram-content"><pre class="mermaid"></pre></div></div>`;
                  shell.querySelector('.mermaid').textContent = code.textContent;
                  code.parentElement.replaceWith(shell);
                } else if (window.hljs) {
                  // Unknown languages remain plain code; do not guess a language.
                  const lang = Array.from(code.classList).find(c => c.startsWith('language-'))?.slice(9);
                  if (lang && hljs.getLanguage(lang)) {
                    code.innerHTML = hljs.highlight(code.textContent, {language: lang, ignoreIllegals: true}).value;
                    code.classList.add('hljs');
                  }
                }
              });
            }

            function normalizeDirection(root) {
              const blockSelector = 'h1,h2,h3,h4,h5,h6,p,li,blockquote,th,td';
              root.querySelectorAll(blockSelector).forEach((node) => {
                if (hasRTL(node.textContent)) {
                  node.setAttribute('dir', 'rtl');
                }
              });

              root.querySelectorAll('ul,ol').forEach((list) => {
                const directText = Array.from(list.children).map((item) => item.textContent).join(' ');
                if (hasRTL(directText)) {
                  list.setAttribute('dir', 'rtl');
                }
              });

              root.querySelectorAll('table').forEach((table) => {
                if (hasRTL(table.textContent)) {
                  table.setAttribute('dir', 'rtl');
                }
              });
            }

            function normalizeTaskLists(root) {
              root.querySelectorAll('li input[type=checkbox]').forEach((input) => {
                input.closest('li')?.classList.add('task-list-item');
              });
            }

            function wireDiagramControls(shell) {
              const stage = shell.querySelector('.diagram-stage');
              const content = shell.querySelector('.diagram-content');
              if (!stage || !content) return;

              let scale = 1;
              let x = 0;
              let y = 0;
              let dragging = false;
              let startX = 0;
              let startY = 0;

              const apply = () => {
                content.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
              };

              const zoom = (nextScale) => {
                scale = Math.max(.35, Math.min(4, nextScale));
                apply();
              };

              shell.querySelector('[data-action="zoom-in"]')?.addEventListener('click', () => zoom(scale + .16));
              shell.querySelector('[data-action="zoom-out"]')?.addEventListener('click', () => zoom(scale - .16));
              shell.querySelector('[data-action="reset"]')?.addEventListener('click', () => {
                scale = 1;
                x = 0;
                y = 0;
                apply();
              });
              shell.querySelector('[data-action="fullscreen"]')?.addEventListener('click', () => {
                shell.classList.toggle('fullscreen');
              });

              stage.addEventListener('wheel', (event) => {
                if (!event.metaKey && !event.ctrlKey) return;
                event.preventDefault();
                zoom(scale + (event.deltaY < 0 ? .12 : -.12));
              }, { passive: false });

              stage.addEventListener('pointerdown', (event) => {
                dragging = true;
                startX = event.clientX - x;
                startY = event.clientY - y;
                stage.classList.add('dragging');
                stage.setPointerCapture(event.pointerId);
              });

              stage.addEventListener('pointermove', (event) => {
                if (!dragging) return;
                x = event.clientX - startX;
                y = event.clientY - startY;
                apply();
              });

              stage.addEventListener('pointerup', () => {
                dragging = false;
                stage.classList.remove('dragging');
              });

              stage.addEventListener('pointercancel', () => {
                dragging = false;
                stage.classList.remove('dragging');
              });
            }

            function normalizeMermaidRTL(root) {
              root.querySelectorAll('.diagram-content text, .diagram-content tspan, .diagram-content foreignObject, .diagram-content foreignObject *').forEach((node) => {
                if (hasRTL(node.textContent)) {
                  node.classList.add('rtl-label');
                  node.setAttribute('direction', 'rtl');
                  node.setAttribute('dir', 'rtl');
                }
              });
            }

            function scrollElement() {
              return document.scrollingElement || document.documentElement || document.body;
            }

            function restoreScroll() {
              const element = scrollElement();
              const maxScroll = Math.max(0, element.scrollHeight - window.innerHeight);
              element.scrollTop = Math.min(initialScrollY, maxScroll);
            }

            let scrollTicking = false;
            function reportScroll() {
              if (scrollTicking) return;
              scrollTicking = true;
              requestAnimationFrame(() => {
                scrollTicking = false;
                const y = scrollElement().scrollTop || 0;
                try {
                  window.webkit?.messageHandlers?.scroll?.postMessage(y);
                } catch (_) {}
              });
            }

            window.addEventListener('scroll', reportScroll, { passive: true });

            async function render() {
              const root = document.getElementById('content');
              try {
                root.innerHTML = MarkdownEngine.render(markdownSource);
                enhanceCode(root);
                normalizeTaskLists(root);
                normalizeDirection(root);

                if (window.mermaid) {
                  mermaid.initialize({
                    startOnLoad: false,
                    securityLevel: 'strict',
                    theme: 'base',
                    themeVariables: {
                      fontFamily: 'Vazirmatn, -apple-system, BlinkMacSystemFont, sans-serif',
                      primaryColor: '#ffffff',
                      primaryTextColor: '#141d2b',
                      primaryBorderColor: '#cfd6df',
                      lineColor: '#57606a',
                      secondaryColor: '#eef7fb',
                      tertiaryColor: '#f7f8fa'
                    },
                    flowchart: { htmlLabels: true, useMaxWidth: false },
                    sequence: { useMaxWidth: false },
                    gantt: { useMaxWidth: false }
                  });
                  // One invalid diagram must not hide the rest of the document.
                  for (const node of root.querySelectorAll('.mermaid')) {
                    const source = node.textContent;
                    try { await mermaid.run({nodes: [node], suppressErrors: false}); }
                    catch (_) { node.textContent = source; node.classList.add('render-error'); }
                  }
                  normalizeMermaidRTL(root);
                }

                root.querySelectorAll('.diagram-shell').forEach(wireDiagramControls);
                requestAnimationFrame(() => {
                  restoreScroll();
                  requestAnimationFrame(() => {
                    restoreScroll();
                    reportScroll();
                  });
                });
              } catch (error) {
                root.innerHTML = `<div class="render-error">${escapeHtml(error?.message || error)}</div>`;
              }
            }

            document.addEventListener('click', (event) => {
              const link = event.target.closest('a[href]');
              const href = link?.getAttribute('href');
              if (!href) return;
              if (!href.startsWith('#')) {
                const handler = window.webkit?.messageHandlers?.openLink;
                if (handler) { event.preventDefault(); handler.postMessage(link.href); }
                return;
              }
              let id;
              try { id = decodeURIComponent(href.slice(1)); } catch (_) { return; }
              const target = document.getElementById(id) || document.getElementById('user-content-' + id);
              if (target) { event.preventDefault(); target.scrollIntoView(); }
            });
            render().finally(() => { window.renderComplete = true; });
          </script>
        </body>
        </html>
        """
    }

    private static func jsonString(_ value: String) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
            let json = String(data: data, encoding: .utf8),
            json.count >= 2
        else {
            return "\"\""
        }
        return String(json.dropFirst().dropLast()).replacingOccurrences(of: "<", with: "\\u003c")
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private enum ResourceLoader {
    static func string(_ name: String, _ ext: String) -> String {
        guard
            let url = resourceURL(name, ext),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return ""
        }
        return content
    }

    static func base64(_ name: String, _ ext: String) -> String {
        guard
            let url = resourceURL(name, ext),
            let data = try? Data(contentsOf: url)
        else {
            return ""
        }
        return data.base64EncodedString()
    }

    private static func resourceURL(_ name: String, _ ext: String) -> URL? {
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        return Bundle.module.resourceURL?.appendingPathComponent("\(name).\(ext)")
    }
}

extension NSColor {
    var hexString: String {
        guard let color = usingColorSpace(.deviceRGB) else { return "#109ECC" }
        return String(format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
    }
}
