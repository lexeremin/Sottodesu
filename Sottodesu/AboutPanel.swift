import AppKit

/// The standard "About" window, with a short description, the author and a link to the project.
enum AboutPanel {
    static let projectURL = URL(string: "https://github.com/lexeremin/Sottodesu")!
    static let authorURL = URL(string: "https://github.com/lexeremin")!

    @MainActor
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits()])
    }

    static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 6
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        func link(_ text: String, _ url: URL) -> NSAttributedString {
            var attributes = base
            attributes[.link] = url
            return NSAttributedString(string: text, attributes: attributes)
        }

        let result = NSMutableAttributedString()
        result.append(NSAttributedString(
            string: String(localized: "Sorts the files in a folder into neat folders by type and remembers every sort, so you can undo it.") + "\n",
            attributes: base))
        result.append(NSAttributedString(string: String(localized: "Developed by") + " ", attributes: base))
        result.append(link("@lexeremin", authorURL))
        result.append(NSAttributedString(string: "\n", attributes: base))
        result.append(link(String(localized: "Source code on GitHub"), projectURL))
        return result
    }
}
