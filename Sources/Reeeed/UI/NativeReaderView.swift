import SwiftUI
import Fuzi
import SwiftUI
import CachedAsyncImage

struct ArticleElement {
    enum ElementType {
        case text(String)
        case heading(String, level: Int)
        case paragraph(String)
        case image(url: String, alt: String?)
        case link(text: String, url: String)
        case blockquote(String)
        case code(String)
        case list([String])
    }
    
    let type: ElementType
}

struct NativeReaderView: View {
    let readableDoc: ReadableDoc
    
    @State private var elements: [ArticleElement] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if readableDoc.insertHeroImage, let heroURL = readableDoc.metadata.heroImage {
                    CachedAsyncImage(url: heroURL, targetSize: .init(width: 600, height: 450))
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                }
                
                if let title = readableDoc.title {
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                HStack {
                    if let author = readableDoc.extracted.author {
                        Text(author)
                    }
                    
                    if readableDoc.extracted.author != nil, readableDoc.date != nil {
                        Text("·")
                    }
                    
                    if let date = readableDoc.date {
                        Text(DateFormatter.shortDateOnly.string(from: date))
                    }
                    
                    if (readableDoc.extracted.author != nil || readableDoc.date != nil) {
                        Text("·")
                    }
                    
                    Text(readableDoc.metadata.url.hostWithoutWWW)
                        
                    
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .font(.headline)
                
                ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
                    ReaderElementView(element: element)
                        .lineSpacing(5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .textSelection(.enabled)
        .task {
            await parseHTML()
        }
    }
    
    private func parseHTML() async {
        guard let htmlContent = readableDoc.extracted.content else {
            return
        }
        
        do {
            let document = try HTMLDocument(string: htmlContent)
            var parsedElements: [ArticleElement] = []
            
            if let body = document.body {
                parseElement(body, into: &parsedElements)
            }
            
            self.elements = parsedElements
        } catch {
            print("Failed to parse HTML: \(error)")
        }
    }
    
    private func parseElement(_ element: Fuzi.XMLElement, into elements: inout [ArticleElement]) {
        let tagName = element.tag?.lowercased() ?? ""
        
        switch tagName {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(tagName.dropFirst()) ?? 1
            let text = element.rawXML.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                elements.append(ArticleElement(type: .heading(text, level: level)))
            }
            
        case "p":
            // Keep raw HTML so that inline elements like <a> are preserved for later parsing.
            // Trimming outer whitespace but not stripping tags here.
            let raw = element.rawXML.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty {
                elements.append(ArticleElement(type: .paragraph(raw)))
            }
            
        case "img":
            if let src = element["src"], !src.isEmpty {
                let alt = element["alt"]
                elements.append(ArticleElement(type: .image(url: src, alt: alt)))
            }
            
        case "blockquote":
            let text = element.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                elements.append(ArticleElement(type: .blockquote(text)))
            }
            
        case "pre", "code":
            let text = element.stringValue
            if !text.isEmpty {
                elements.append(ArticleElement(type: .code(text)))
            }
            
        case "ul", "ol":
            var listItems: [String] = []
            for child in element.children {
                if child.tag?.lowercased() == "li" {
                    // Preserve raw HTML for list items to keep inline anchors.
                    let raw = child.rawXML.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !raw.isEmpty {
                        listItems.append(raw)
                    }
                }
            }
            if !listItems.isEmpty {
                elements.append(ArticleElement(type: .list(listItems)))
            }
            
        default:
            for child in element.children {
                parseElement(child, into: &elements)
            }
        }
    }
}
