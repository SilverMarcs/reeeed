import Foundation
import Fuzi

public struct ReadableDoc: Equatable, Codable {
    public var extracted: ExtractedContent
    public var html: String
    public var insertHeroImage: Bool
    public var metadata: SiteMetadata
    public var date: Date?

    public init?(extracted: ExtractedContent, insertHeroImage: Bool? /* autodetect if nil */, metadata: SiteMetadata, date: Date? = nil) {
        guard let html = extracted.content else {
            return nil
        }
        self.html = html
        self.extracted = extracted
        if let insertHeroImage {
            self.insertHeroImage = insertHeroImage
        } else if let html = extracted.content {
            self.insertHeroImage = (try? estimateLinesUntilFirstImage(html: html) ?? 999 >= 10) ?? false
        } else {
            self.insertHeroImage = false
        }
        self.metadata = metadata
        self.date = date ?? extracted.datePublished
    }

    public var title: String? {
        extracted.title ?? metadata.title
    }

    public var url: URL {
        metadata.url
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
