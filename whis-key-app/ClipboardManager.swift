import Foundation
import SwiftUI

class ClipboardManager {
    func copyToClipboard(text: String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = text
    }
}
