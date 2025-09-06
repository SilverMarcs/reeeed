import Foundation
import SwiftUI
import Fuzi


extension String {
    var asJSString: String {
        let data = try! JSONSerialization.data(withJSONObject: self, options: .fragmentsAllowed)
        return String(data: data, encoding: .utf8)!
    }
    
    var nilIfEmpty: String? {
        return isEmpty ? nil : self
    }
}

extension URL {
    var inferredFaviconURL: URL {
        return URL(string: "/favicon.ico", relativeTo: self)!
    }

    var hostWithoutWWW: String {
        var parts = (host ?? "").components(separatedBy: ".")
        if parts.first == "www" {
            parts.remove(at: 0)
        }
        return parts.joined(separator: ".")
    }
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



extension DateFormatter {
    static let shortDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}
