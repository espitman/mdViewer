import SwiftUI

enum MarkdownInline {
    static func attributed(_ source: String, base: Font, color: Color = AppColor.ink) -> AttributedString {
        var output = AttributedString()
        var index = source.startIndex

        while index < source.endIndex {
            if source[index] == "`",
               let end = source[source.index(after: index)...].firstIndex(of: "`") {
                var run = AttributedString(String(source[source.index(after: index)..<end]))
                run.font = .system(.body, design: .monospaced)
                run.foregroundColor = AppColor.mutedInk
                output += run
                index = source.index(after: end)
            } else if source[index...].hasPrefix("**"),
                      let end = source[source.index(index, offsetBy: 2)...].range(of: "**")?.lowerBound {
                var run = AttributedString(String(source[source.index(index, offsetBy: 2)..<end]))
                run.font = base.bold()
                run.foregroundColor = color
                output += run
                index = source.index(end, offsetBy: 2)
            } else if source[index] == "*",
                      let end = source[source.index(after: index)...].firstIndex(of: "*") {
                var run = AttributedString(String(source[source.index(after: index)..<end]))
                run.font = base.italic()
                run.foregroundColor = color
                output += run
                index = source.index(after: end)
            } else {
                var next = source.index(after: index)
                while next < source.endIndex,
                      source[next] != "`",
                      source[next] != "*" {
                    next = source.index(after: next)
                }
                var run = AttributedString(String(source[index..<next]))
                run.font = base
                run.foregroundColor = color
                output += run
                index = next
            }
        }

        return output
    }
}
