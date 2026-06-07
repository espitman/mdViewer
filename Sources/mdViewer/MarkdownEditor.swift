import AppKit
import SwiftUI

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionRequest: EditorSelectionRequest?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(red: 0.17, green: 0.19, blue: 0.29, alpha: 1)
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting()
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
            context.coordinator.applyHighlighting()
        }

        context.coordinator.applySelectionRequest(selectionRequest)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        private var isHighlighting = false
        private var lastSelectionRequestID: UUID?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.string
            applyHighlighting()
        }

        func applyHighlighting() {
            guard let textView, !isHighlighting else { return }
            isHighlighting = true
            defer { isHighlighting = false }

            let selectedRanges = textView.selectedRanges
            let storage = textView.textStorage ?? NSTextStorage()
            let fullRange = NSRange(location: 0, length: storage.length)
            let baseFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor(red: 0.17, green: 0.19, blue: 0.29, alpha: 1)
            ], range: fullRange)

            let source = textView.string as NSString
            source.enumerateSubstrings(in: NSRange(location: 0, length: source.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
                let line = source.substring(with: lineRange)
                self.colorLine(line, range: lineRange, storage: storage)
            }

            textView.selectedRanges = selectedRanges
        }

        func applySelectionRequest(_ request: EditorSelectionRequest?) {
            guard let request, request.id != lastSelectionRequestID, let textView else { return }
            lastSelectionRequestID = request.id
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(request.range)
            textView.scrollRangeToVisible(request.range)
        }

        private func colorLine(_ line: String, range: NSRange, storage: NSTextStorage) {
            let purple = NSColor(red: 0.58, green: 0.42, blue: 0.95, alpha: 1)
            let cyan = NSColor(red: 0.33, green: 0.86, blue: 0.95, alpha: 1)
            let green = NSColor(red: 0.38, green: 0.74, blue: 0.25, alpha: 1)
            let pink = NSColor(red: 0.96, green: 0.20, blue: 0.53, alpha: 1)
            let orange = NSColor(red: 1.00, green: 0.61, blue: 0.12, alpha: 1)

            if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                storage.addAttribute(.foregroundColor, value: purple, range: range)
            }

            if line.trimmingCharacters(in: .whitespaces).hasPrefix("![") {
                storage.addAttribute(.foregroundColor, value: pink, range: range)
            }

            if line.trimmingCharacters(in: .whitespaces).hasPrefix("* ") ||
                line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                let bulletRange = NSRange(location: range.location, length: min(1, range.length))
                storage.addAttribute(.foregroundColor, value: cyan, range: bulletRange)
            }

            applyRegex(#"\*\*[^*]+\*\*"#, color: cyan, in: line, lineRange: range, storage: storage)
            applyRegex(#"\*[^*]+\*"#, color: green, in: line, lineRange: range, storage: storage)
            applyRegex(#"`[^`]+`"#, color: orange, in: line, lineRange: range, storage: storage)
        }

        private func applyRegex(_ pattern: String, color: NSColor, in line: String, lineRange: NSRange, storage: NSTextStorage) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsLine = line as NSString
            let localRange = NSRange(location: 0, length: nsLine.length)
            regex.enumerateMatches(in: line, range: localRange) { match, _, _ in
                guard let match else { return }
                let absolute = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
                storage.addAttribute(.foregroundColor, value: color, range: absolute)
            }
        }
    }
}

struct EditorSelectionRequest: Equatable {
    let id = UUID()
    let range: NSRange
}
