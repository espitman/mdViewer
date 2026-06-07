import CoreText
import Foundation

enum FontRegistrar {
    static func registerBundledFonts() {
        guard let fontURL = Bundle.module.url(forResource: "Vazirmatn-Regular", withExtension: "ttf", subdirectory: "Fonts") else {
            return
        }

        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }
}
