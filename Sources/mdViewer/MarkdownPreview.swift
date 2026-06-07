import AppKit
import Foundation
import SwiftUI
import WebKit

struct MarkdownPreview: NSViewRepresentable {
    let markdown: String
    let fontName: String
    let fontSize: Double
    let accentColor: Color
    var onFileDrop: (URL) -> Void = { _ in }

    func makeNSView(context: Context) -> DroppableMarkdownWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = DroppableMarkdownWebView(frame: .zero, configuration: configuration)
        webView.onFileDrop = onFileDrop
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        webView.loadHTMLString(html, baseURL: Bundle.module.resourceURL)
        return webView
    }

    func updateNSView(_ webView: DroppableMarkdownWebView, context: Context) {
        webView.onFileDrop = onFileDrop
        webView.loadHTMLString(html, baseURL: Bundle.module.resourceURL)
    }

    private var html: String {
        MarkdownHTMLRenderer.html(
            for: markdown,
            title: "Preview",
            fontName: fontName,
            fontSize: fontSize,
            accent: NSColor(accentColor).hexString
        )
    }
}

final class DroppableMarkdownWebView: WKWebView {
    var onFileDrop: (URL) -> Void = { _ in }

    override init(frame frameRect: NSRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frameRect, configuration: configuration)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURL(from: sender.draggingPasteboard) == nil ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURL(from: sender.draggingPasteboard) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = fileURL(from: sender.draggingPasteboard) else { return false }
        onFileDrop(url)
        return true
    }

    private func fileURL(from pasteboard: NSPasteboard) -> URL? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            return url
        }

        if let value = pasteboard.string(forType: .fileURL),
           let url = URL(string: value) {
            return url
        }

        if let value = pasteboard.string(forType: .URL),
           let url = URL(string: value),
           url.isFileURL {
            return url
        }

        if let value = pasteboard.string(forType: .string) {
            if let url = URL(string: value), url.isFileURL {
                return url
            }
            return URL(fileURLWithPath: value)
        }

        return nil
    }
}

enum MarkdownHTMLRenderer {
    static func html(
        for markdown: String,
        title: String,
        fontName: String = "Vazirmatn-Regular",
        fontSize: Double = 16,
        accent: String = "#109ECC"
    ) -> String {
        let markdownItScript = ResourceLoader.string("markdown-it.min", "js")
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
              margin: 0 auto;
              padding: 46px 56px 80px;
              overflow-wrap: anywhere;
              user-select: text;
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
              unicode-bidi: plaintext;
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
            }

            table {
              display: block;
              width: 100%;
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

            img {
              max-width: 100%;
              border-radius: 8px;
            }

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
              width: 32px;
              height: 30px;
              border: 1px solid rgba(20, 29, 43, .12);
              border-radius: 7px;
              background: rgba(255, 255, 255, .92);
              color: var(--ink);
              font: 800 13px var(--reader-font);
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

          <script>\(markdownItScript)</script>
          <script>\(highlightScript)</script>
          <script>\(mermaidScript)</script>
          <script>
            const markdownSource = \(source);
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

            function prepareTaskLists(source) {
              return source.replace(/^(\\s*[-+*]\\s+)\\[( |x|X)\\]\\s+/gm, (_, prefix, checked) => {
                const isChecked = checked.toLowerCase() === 'x' ? ' checked' : '';
                return `${prefix}<input class="task-list-checkbox" type="checkbox" disabled${isChecked}> `;
              });
            }

            const md = window.markdownit({
              html: true,
              linkify: true,
              typographer: false,
              breaks: true,
              highlight: (str, lang) => {
                if (window.hljs && lang && hljs.getLanguage(lang)) {
                  try {
                    return `<pre class="hljs"><code>${hljs.highlight(str, { language: lang, ignoreIllegals: true }).value}</code></pre>`;
                  } catch (_) {}
                }
                if (window.hljs) {
                  try {
                    return `<pre class="hljs"><code>${hljs.highlightAuto(str).value}</code></pre>`;
                  } catch (_) {}
                }
                return `<pre class="hljs"><code>${escapeHtml(str)}</code></pre>`;
              }
            });

            const defaultFence = md.renderer.rules.fence;
            md.renderer.rules.fence = (tokens, idx, options, env, self) => {
              const token = tokens[idx];
              const info = token.info.trim().split(/\\s+/)[0].toLowerCase();
              const content = token.content.trim();
              const looksMermaid = /^(flowchart|graph|sequenceDiagram|classDiagram|stateDiagram|stateDiagram-v2|erDiagram|journey|gantt|pie|mindmap|timeline|gitGraph)\\b/.test(content);
              if (info === 'mermaid' || (!info && looksMermaid)) {
                return `
                  <section class="diagram-shell">
                    <div class="diagram-toolbar">
                      <button type="button" data-action="zoom-out" title="Zoom out">−</button>
                      <button type="button" data-action="reset" title="Reset">1:1</button>
                      <button type="button" data-action="zoom-in" title="Zoom in">+</button>
                      <button type="button" data-action="fullscreen" title="Fullscreen">⛶</button>
                    </div>
                    <div class="diagram-stage">
                      <div class="diagram-content"><pre class="mermaid">${escapeHtml(content)}</pre></div>
                    </div>
                  </section>`;
              }
              return defaultFence(tokens, idx, options, env, self);
            };

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
              root.querySelectorAll('li input.task-list-checkbox').forEach((input) => {
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

            async function render() {
              const root = document.getElementById('content');
              try {
                root.innerHTML = md.render(prepareTaskLists(markdownSource));
                normalizeTaskLists(root);
                normalizeDirection(root);

                if (window.mermaid) {
                  mermaid.initialize({
                    startOnLoad: false,
                    securityLevel: 'loose',
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
                  await mermaid.run({ nodes: root.querySelectorAll('.mermaid') });
                  normalizeMermaidRTL(root);
                }

                root.querySelectorAll('.diagram-shell').forEach(wireDiagramControls);
              } catch (error) {
                root.innerHTML = `<div class="render-error">${escapeHtml(error?.message || error)}</div>`;
              }
            }

            render();
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
        return String(json.dropFirst().dropLast())
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
