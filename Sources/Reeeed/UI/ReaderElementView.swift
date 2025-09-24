//
//  ElementView.swift
//  Reeeed
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI

struct ReaderElementView<ImageRenderer: View>: View {
    @Environment(\.openURL) var openURL
    
    let element: ArticleElement
    let imageRenderer: ((URL) -> ImageRenderer)?
    
    var body: some View {
        switch element.type {
        case .heading(let text, let level):
            Text(parseAttributedText(text))
                .font(headingFont(for: level))
                .fontWeight(.bold)
                .lineLimit(nil)
                .padding(.vertical, 4)
                
        case .paragraph(let text):
            // text may still include <p> wrapper and inline anchors – parse into attributed string
            Text(parseAttributedText(text))
                .padding(.vertical, 2)
                
        case .image(let url, let alt):
            if let imageURL = URL(string: url) {
                if let imageRenderer = imageRenderer {
                    imageRenderer(imageURL)
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(5)
                        .padding(.vertical, 4)
                } else {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(5)
                    .padding(.vertical, 4)
                }
            }
            
        case .blockquote(let text):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(.secondary)
                    .frame(width: 4)
                
                Text(text)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
            .padding(.vertical, 8)
            
        case .code(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.vertical, 4)
                
        case .list(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        // Each list item may contain inline HTML (links, emphasis)
                        Text(parseAttributedText(item))
                            .lineLimit(nil)
                    }
                }
            }
            .padding(.vertical, 4)
            
        case .text(let text):
            Text(text)

        case .link(let text, let url):
            Button(text) {
                if let url = URL(string: url) {
                    openURL(url, prefersInApp: true)
                }
            }
            .foregroundStyle(.link)
        }
    }
    
    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        case 4: return .headline
        case 5: return .subheadline
        default: return .subheadline
        }
    }
    
    private func parseAttributedText(_ text: String) -> AttributedString {
        // Remove common outer wrappers (<p>...</p>) while preserving inner HTML
        var working = text
            .replacingOccurrences(of: "^<p[^>]*>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "</p>$", with: "", options: .regularExpression)

        // Replace <br> variants with newline to keep structure
        working = working.replacingOccurrences(of: "<br ?/?>", with: "\n", options: .regularExpression)

        // We'll iteratively detect anchors and build an AttributedString
        var attributed = AttributedString("")
        var cursor = working.startIndex

        let pattern = "<a\\s+[^>]*href\\s*=\\s*[\"']([^\"']*)[\"'][^>]*>(.*?)</a>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return AttributedString(working.htmlStripped())
        }

        let nsWorking = working as NSString
        let matches = regex.matches(in: working, options: [], range: NSRange(location: 0, length: nsWorking.length))

        func appendPlain(_ substring: Substring) {
            if substring.isEmpty { return }
            let plain = String(substring).htmlStripped()
            if !plain.isEmpty { attributed.append(AttributedString(plain)) }
        }

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let hrefRange = Range(match.range(at: 1), in: working),
                  let innerRange = Range(match.range(at: 2), in: working),
                  let fullRange = Range(match.range(at: 0), in: working) else { continue }

            let before = working[cursor..<fullRange.lowerBound]
            appendPlain(before)

            let urlString = String(working[hrefRange])
            let linkInnerRaw = String(working[innerRange])
            let linkInner = linkInnerRaw.htmlStripped()
            var linkAttr = AttributedString(linkInner)
            linkAttr.foregroundColor = .accentColor
            linkAttr.underlineStyle = .single
            if let parsedURL = URL(string: urlString) { linkAttr.link = parsedURL }
            attributed.append(linkAttr)

            cursor = fullRange.upperBound
        }

        if cursor < working.endIndex {
            appendPlain(working[cursor..<working.endIndex])
        }

        return attributed
    }
}

private extension String {
    func htmlStripped() -> String {
        // Very lightweight stripping of residual tags; not a full HTML parser but fine for inline tags
        self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
