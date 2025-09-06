//
//  ElementView.swift
//  Reeeed
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import CachedAsyncImage

struct ReaderElementView: View {
    @Environment(\.openURL) var openURL
    
    let element: ArticleElement
    
    var body: some View {
        switch element.type {
        case .heading(let text, let level):
            Text(text)
                .font(headingFont(for: level))
                .fontWeight(.bold)
                .lineLimit(nil)
                .padding(.vertical, 4)
                
        case .paragraph(let text):
            Text(parseAttributedText(text))
                .padding(.vertical, 2)
                
        case .image(let url, let alt):
            CachedAsyncImage(url: URL(string: url), targetSize: .init(width: 600, height: 450))
                .aspectRatio(contentMode: .fit)
                .cornerRadius(5)
                .padding(.vertical, 4)
            
        case .blockquote(let text):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 4)
                
                Text(text)
                    .italic()
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
                        
                        Text(item)
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
        var attributedString = AttributedString(text)
        
        do {
            let linkRegex = try NSRegularExpression(pattern: "<a\\s+[^>]*href\\s*=\\s*[\"']([^\"']*)[\"'][^>]*>([^<]*)</a>", options: [])
            let matches = linkRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            for match in matches.reversed() {
                if let urlRange = Range(match.range(at: 1), in: text),
                   let textRange = Range(match.range(at: 2), in: text),
                   let fullRange = Range(match.range, in: text) {
                    
                    let url = String(text[urlRange])
                    let linkText = String(text[textRange])
                    
                    if let attributedRange = Range(fullRange, in: attributedString) {
                        attributedString.removeSubrange(attributedRange)
                        var linkAttributedString = AttributedString(linkText)
                        linkAttributedString.foregroundColor = .accentColor
                        linkAttributedString.underlineStyle = .single
                        if let linkURL = URL(string: url) {
                            linkAttributedString.link = linkURL
                        }
                        attributedString.insert(linkAttributedString, at: attributedRange.lowerBound)
                    }
                }
            }
        } catch {
            print("Failed to parse links: \(error)")
        }
        
        return attributedString
    }
}
