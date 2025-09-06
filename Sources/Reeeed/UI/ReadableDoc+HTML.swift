import Foundation
import Fuzi

extension ReadableDoc {
    public func html(includeExitReaderButton: Bool, theme: ReaderTheme = .init()) -> String {
        let escapedTitle = htmlEscape(title?.byStrippingSiteNameFromPageTitle ?? "")

        var heroHTML: String = ""
        if insertHeroImage, let hero = metadata.heroImage {
            let safeURL = htmlEscape(hero.absoluteString)
            heroHTML = "<img class='__hero' src=\"\(safeURL)\" />"
        }

        let subtitle: String = {
            var partsHTML = [String]()

            let separatorHTML = "<span class='__separator'> · </span>"
            func appendSeparatorIfNecessary() {
                if partsHTML.count > 0 {
                    partsHTML.append(separatorHTML)
                }
            }
            if let author = extracted.author {
                partsHTML.append(htmlEscape(author))
            }
            if let date {
                appendSeparatorIfNecessary()
                partsHTML.append(DateFormatter.shortDateOnly.string(from: date))
            }
            
            appendSeparatorIfNecessary()
            partsHTML.append(metadata.url.hostWithoutWWW)

            return "<p class='__subtitle'>\(partsHTML.joined())</p>"
        }()

        let wrapped = """
<!DOCTYPE html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>\(escapedTitle)</title>
<style id='__themeStyle'>
\(theme.css)
</style>
<body>
<div id='__content' style='opacity: 0'>
    \(heroHTML)
    
    <h1 id='__title'>\(escapedTitle)</h1>
        \(subtitle)
        \(extracted.content ?? "")
</div>

<script>
    setTimeout(() => {
        document.getElementById('__content').style.opacity = 1;
    }, 100);
</script>

</body>
"""
        return wrapped
    }
}

// HTML escaping function to replace SwiftSoup's Entities.escape
private func htmlEscape(_ string: String) -> String {
    return string
        .replacingOccurrences(of: "&", with: "&")
        .replacingOccurrences(of: "<", with: "<")
        .replacingOccurrences(of: ">", with: ">")
        .replacingOccurrences(of: "\"", with: "")
        .replacingOccurrences(of: "'", with: "'")
}

extension ReaderTheme {
    public var css: String {
        let (fgLight, fgDark) = foreground.hexPair
        let (bgLight, bgDark) = background.hexPair
        let (linkLight, linkDark) = link.hexPair

        return """
        html, body {
            margin: 0;
        }

        body {
            color: \(fgLight);
            background-color: \(bgLight);
            overflow-wrap: break-word;
            font: -apple-system-body;
        }

        .__hero {
            display: block;
            width: 100%;
            height: 50vw;
            max-height: 300px;
            object-fit: cover;
            overflow: hidden;
            border-radius: 7px;
        }

        #__content {
            line-height: 1.5;
            font-size: 1.1em;
            overflow-x: hidden;
        }

        @media screen and (min-width: 650px) {
            #__content { font-size: 1.35em; line-height: 1.5; }
        }

        h1, h2, h3, h4, h5, h6 {
            line-height: 1.2;
            font-family: -apple-system;
            font-size: 1.5em;
            font-weight: 800;
        }

        #__title {
            font-size: 1.8em;
        }

        img, iframe, object, video {
            max-width: 100%;
            height: auto;
            border-radius: 7px;
        }

        pre {
            max-width: 100%;
            overflow-x: auto;
        }

        table {
            display: block;
            max-width: 100%;
            overflow-x: auto;
        }

        a:link {
            color: \(linkLight);
        }

        figure {
            margin-left: 0;
            margin-right: 0;
        }

        figcaption, cite {
            opacity: 0.5;
            font-size: small;
        }

        @media screen and (max-width: 500px) {
            dd {
                margin-inline-start: 20px; /* normally 40px */
            }
            blockquote {
                margin-inline-start: 20px; /* normally 40px */
                margin-inline-end: 20px; /* normally 40px */
            }
        }

        .__subtitle {
            font-weight: bold;
            vertical-align: baseline;
            opacity: 0.5;
            font-size: 0.9em;
        }

        .__subtitle .__icon {
            width: 1.2em;
            height: 1.2em;
            object-fit: cover;
            overflow: hidden;
            border-radius: 3px;
            margin-right: 0.3em;
            position: relative;
            top: 0.3em;
        }

        .__subtitle .__separator {
            opacity: 0.5;
        }

        #__content {
            padding: 0.75em;
            margin: auto;
            max-width: 700px;
        }

        @media (prefers-color-scheme: dark) {
            body {
                color: \(fgDark);
                background-color: \(bgDark);
            }
            a:link { color: \(linkDark); }
        }

        \(additionalCSS ?? "")
        """
    }
}

func estimateLinesUntilFirstImage(html: String) throws -> Int? {
    let doc = try HTMLDocument(string: html)
    var lines = 0
    var linesBeforeFirst: Int?
    
    func traverseElement(_ element: XMLElement) {
        if element.tag?.lowercased() == "img", linesBeforeFirst == nil {
            linesBeforeFirst = lines
        }
        lines += element.estLineCount
        
        for child in element.children {
            traverseElement(child)
        }
    }
    
    if let root = doc.root {
        traverseElement(root)
    }
    
    return linesBeforeFirst
}

extension Fuzi.XMLElement {
    func traverse(_ block: (Fuzi.XMLElement) -> Void) throws {
        for child in children {
            block(child)
            try child.traverse(block)
        }
    }
    var estLineCount: Int {
        if let tag = self.tag?.lowercased() {
            switch tag {
            case "video", "embed": return 5
            case "h1", "h2", "h3", "h4", "h5", "h6", "p", "li":
                return Int(ceil(Double(stringValue.count) / 60)) + 1
            case "tr": return 1
            default: return 0
            }
        }
        return 0
    }
}

extension DateFormatter {
    static let shortDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

//extension SwiftSoup.Node {
//    func traverseElements(_ block: @escaping (Element) -> Void) throws {
//        let visitor = BlockNodeVisitor(headCallback: { (node, _depth) in
//            if let el = node as? Element {
//                block(el)
//            }
//        }, tailCallback: nil)
//        try traverse(visitor)
//    }
//}
//
//private struct BlockNodeVisitor: NodeVisitor {
//    var headCallback: ((Node, Int) -> Void)?
//    var tailCallback: ((Node, Int) -> Void)?
//
//    func head(_ node: Node, _ depth: Int) throws {
//        headCallback?(node, depth)
//    }
//
//    func tail(_ node: Node, _ depth: Int) throws {
//        tailCallback?(node, depth)
//    }
//}
