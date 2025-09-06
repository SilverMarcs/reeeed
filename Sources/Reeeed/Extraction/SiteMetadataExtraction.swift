import Foundation
import Fuzi

public struct SiteMetadata: Equatable, Codable {
    public var url: URL
    public var title: String?
    public var description: String?
    public var heroImage: URL?
    public var favicon: URL?

    private struct MetadataParseError: Error {}

    public init(url: URL, title: String? = nil, description: String? = nil, heroImage: URL? = nil, favicon: URL? = nil) {
        self.url = url
        self.title = title
        self.description = description
        self.heroImage = heroImage
        self.favicon = favicon
    }

    public static func extractMetadata(fromHTML html: String, baseURL: URL) async throws -> SiteMetadata {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.metadataExtractorQueue.async {
                do {
                    let doc = try HTMLDocument(string: html)
                    var md = SiteMetadata(url: baseURL)
                    md.title = (doc.ogTitle ?? doc.title)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    md.heroImage = doc.ogImage(baseURL: baseURL)
                    md.description = doc.metaDescription?.nilIfEmpty
                    md.favicon = doc.favicon(baseURL: baseURL) ?? baseURL.inferredFaviconURL
                    continuation.resume(returning: md)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension DispatchQueue {
    static let metadataExtractorQueue = DispatchQueue(label: "MetadataExtractor", qos: .default, attributes: .concurrent)
}

private extension Fuzi.HTMLDocument {
    private func getAttribute(selector: String, attribute: String) -> String? {
        return css(selector).first?.attr(attribute)
    }

    var metaDescription: String? {
        getAttribute(selector: "meta[name='description']", attribute: "content")
    }

    var ogTitle: String? {
        getAttribute(selector: "meta[property='og:title']", attribute: "content")
    }

    var title: String? {
        return css("title").first?.stringValue
    }

    func ogImage(baseURL: URL) -> URL? {
        if let link = getAttribute(selector: "meta[property='og:image']", attribute: "content") {
            return URL(string: link, relativeTo: baseURL)
        }
        return nil
    }

    func favicon(baseURL: URL) -> URL? {
        for item in css("link") {
            if let rel = item.attr("rel"),
               (rel == "icon" || rel == "shortcut icon"),
               let val = item.attr("href"),
               let resolved = URL(string: val, relativeTo: baseURL) {
                return resolved
            }
        }
        return nil
    }
}
