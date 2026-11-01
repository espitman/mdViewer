import AppKit
import WebKit
import XCTest
@testable import mdViewer

final class MarkdownPreviewTests: XCTestCase {
    @MainActor
    func testBundledPreviewAndExportInWebKit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // A real local image checks relative resolution and WebKit file access.
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("image.png"))
        let markdown = """
        # عنوان فارسی

        [Jump](#عنوان-فارسی) · [Other document](other.md)

        > [!NOTE]
        > متن **مهم**

        1. [x] انجام شد
        2. [ ] باقی مانده

        | left | right |
        | :--- | ---: |
        | a | b |

        Inline $x^2$ and $`a_b`$.

        ```math
        \\frac{1}{2}
        ```

        Text[^note]. :smile:

        [^note]: A footnote.

        <details><summary>More</summary>

        **Inside**

        </details>

        ![local](image.png)

        ```swift
        let x = 1
        ```

        ```md
        - [x] literal
        </script><script>window.pwned = true</script>
        ```

        ```mermaid
        graph TD
          A --> B
        ```

        ```mermaid
        deliberately invalid diagram
        ```

        ## Still visible

        Inline comment: <!-- **visible**--->

        https://example.com

        <style>body { display: none }</style>

        <img src="missing" onerror="window.pwned=true">
        """
        let html = MarkdownHTMLRenderer.html(for: markdown, title: "Test", baseURL: directory)
        var openedURLs: [URL] = []
        let coordinator = MarkdownPreview.Coordinator(onLoadingChange: { _ in }, onScrollChange: { _ in }, onFileDrop: { openedURLs = $0 })
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(coordinator, name: "openLink")
        let web = DroppableMarkdownWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 1600), configuration: configuration)
        web.navigationDelegate = coordinator
        web.loadPreviewHTML(html, baseURL: directory)
        var ready = false
        for _ in 0..<300 {
            if (try? await web.evaluateJavaScript("window.renderComplete === true")) as? Bool == true {
                ready = true
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(ready, "Preview completed without JavaScript initialization errors")
        guard ready else { return }
        // Rendering the Markdown/diagrams does not imply that WebKit's separate
        // networking process has finished loading dynamically inserted images.
        for _ in 0..<100 {
            if (try? await web.evaluateJavaScript("document.querySelector('img[alt=local]')?.complete === true")) as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let imageState = try await web.evaluateJavaScript("JSON.stringify([...document.querySelectorAll('img')].map(i => ({src:i.currentSrc, complete:i.complete, width:i.naturalWidth})))")
        let checks = """
        (() => {
          const root = document.getElementById('content');
          return {
            heading: root.querySelector('h1')?.getAttribute('dir') === 'rtl',
            alert: !!root.querySelector('.markdown-alert-note strong'),
            tasks: root.querySelectorAll('input[type=checkbox]').length === 2,
            table: getComputedStyle(root.querySelector('th[align=right]')).textAlign === 'right',
            math: root.querySelectorAll('math').length === 3,
            footnote: !!root.querySelector('[data-footnotes]'),
            details: !!root.querySelector('details strong'),
            highlighted: !!root.querySelector('code.language-swift .hljs-keyword'),
            literalCode: root.querySelector('code.language-md').textContent.includes('- [x] literal'),
            mermaid: !!root.querySelector('.diagram-content svg'),
            invalidDiagram: !!root.querySelector('.mermaid.render-error'),
            preserved: !!root.querySelector('#still-visible'),
            localImage: root.querySelector('img[alt=local]').naturalWidth === 2,
            safe: window.pwned !== true && !root.querySelector('[onerror],script'),
            emoji: root.textContent.includes('😄'),
            malformedComment: root.textContent.includes('<!-- visible--->') && [...root.querySelectorAll('strong')].some(node => node.textContent === 'visible'),
            nofollow: root.querySelector('a[href="https://example.com"]')?.rel === 'nofollow',
            literalStyle: root.textContent.includes('<style>body { display: none }</style>') && ![...root.querySelectorAll('style')].some(node => !node.closest('svg')) && getComputedStyle(document.body).display !== 'none',
            untranslatedCode: !!root.querySelector('code.notranslate')
          };
        })()
        """
        let result = try await web.evaluateJavaScript(checks) as! [String: Bool]
        for (feature, passed) in result { XCTAssertTrue(passed, feature == "localImage" ? "localImage: \(String(describing: imageState))" : feature) }
        _ = try await web.evaluateJavaScript("document.querySelector('a[href=\"other.md\"]').click()")
        for _ in 0..<30 {
            if !openedURLs.isEmpty { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(openedURLs.first?.lastPathComponent, "other.md", "Local Markdown link routes to the app's document loader")
        let snapshot = try await web.takeSnapshot(configuration: nil)
        if let data = snapshot.tiffRepresentation, let rep = NSBitmapImageRep(data: data) {
            try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/mdviewer-render-verification.png"))
        }
    }
    @MainActor
    func testWideContentStaysInsidePreview() async throws {
        let longCode = String(repeating: "LongServiceName.method(argument); ", count: 120)
        let columns = Array(repeating: "column", count: 28).joined(separator: " | ")
        let separators = Array(repeating: "---", count: 28).joined(separator: " | ")
        let values = Array(repeating: "محتوای جدول `Service.kt`", count: 28).joined(separator: " | ")
        let markdown = """
        # گزارش فارسی

        توضیح فارسی همراه با `\(String(repeating: "NotificationsPageApiService", count: 60))` و ادامه متن برای خواندن.

        - `source_setting` به `destination_setting`، `instant_reserve` به `instant_accommodation_reservation` و `base_price` به همان `base_price` نگاشت می‌شوند. مقصد `/statistics/opportunities` است؛ انتخاب‌گر فقط برای فرصتی که API برمی‌گرداند باز می‌شود. مقدار ناشناخته فقط فهرست را باز می‌کند، مطابق `ReportViewModel.checkOpportunity`.
        - PNL ورودی مستقیم، `monthName` عددی یا نام ماه و `hideResultBanner` را رعایت می‌کند. انتخاب صریح ماه بر ماه بنر مقدم است.
        - یک مورد فارسی با کد `host/opportunity` و توضیحات بیشتر.
          - زیرمورد فارسی همراه با متن English و آدرس https://example.com/\(String(repeating: "long-path-", count: 100))

        ```text
        \(longCode)
        ```

        | \(columns) |
        | \(separators) |
        | \(values) |

        <table width="9000"><tr><td width="8000">جدول HTML عریض</td><td>ستون دوم</td></tr></table>

        <details><summary>توضیحات بیشتر</summary>

        ```text
        \(longCode)
        ```

        </details>

        <hr width="9000">

        > <hr width="9000">

        متن آخر سند[^note].

        [^note]: پانویس فارسی
        """
        let web = DroppableMarkdownWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
        web.loadPreviewHTML(MarkdownHTMLRenderer.html(for: markdown, title: "Wide document"), baseURL: nil)
        var ready = false
        for _ in 0..<300 {
            if (try? await web.evaluateJavaScript("window.renderComplete === true")) as? Bool == true {
                ready = true
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(ready)
        guard ready else { return }
        _ = try await web.evaluateJavaScript("document.querySelector('details').open = true")
        for width in [480, 900, 1600] {
            web.setFrameSize(NSSize(width: width, height: 700))
            _ = try await web.evaluateJavaScript("document.documentElement.style.setProperty('--font-size', '\(width == 900 ? 24 : 16)px')")
            try await Task.sleep(for: .milliseconds(100))
            let dimensions = try await web.evaluateJavaScript("""
            (() => {
              const root = document.getElementById('content');
              const page = document.scrollingElement;
              const rect = root.getBoundingClientRect();
              return {
                viewport: page.clientWidth, page: page.scrollWidth,
                left: rect.left, right: rect.right,
                blocksFit: [...root.children].every(node => {
                  const box = node.getBoundingClientRect();
                  return box.left >= -1 && box.right <= page.clientWidth + 1;
                }),
                codeScrolls: [...root.querySelectorAll('pre')].every(node => [node, node.querySelector('code')].some(part => part && part.scrollWidth > part.clientWidth)),
                tableScrolls: root.querySelector('table').scrollWidth > root.querySelector('table').clientWidth
              };
            })()
            """) as! [String: Any]
            let viewport = (dimensions["viewport"] as! NSNumber).doubleValue
            let page = (dimensions["page"] as! NSNumber).doubleValue
            XCTAssertLessThanOrEqual(page, viewport + 1, "Document overflows at width \(width): \(dimensions)")
            XCTAssertGreaterThanOrEqual((dimensions["left"] as! NSNumber).doubleValue, 0)
            XCTAssertLessThanOrEqual((dimensions["right"] as! NSNumber).doubleValue, viewport + 1)
            XCTAssertEqual(dimensions["blocksFit"] as? Bool, true, "Content remains visible inside the viewport")
            XCTAssertEqual(dimensions["codeScrolls"] as? Bool, true, "Wide code retains local scrolling")
            XCTAssertEqual(dimensions["tableScrolls"] as? Bool, true, "Wide tables retain local scrolling")
        }
    }

}
