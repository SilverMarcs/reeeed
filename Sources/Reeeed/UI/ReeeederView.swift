import SwiftUI
import WebKit

public struct ReeeederViewOptions {
    public var onLinkClicked: ((URL) -> Void)?
    public init(onLinkClicked: ((URL) -> Void)? = nil) {
        self.onLinkClicked = onLinkClicked
    }
}

public struct ReeeederView: View {
    var url: URL
    var options: ReeeederViewOptions
    
    public init(url: URL, options: ReeeederViewOptions = .init()) {
        self.url = url
        self.options = options
    }
    
    enum Status: Equatable {
        case fetching
        case failedToExtractContent
        case extractedContent(readableDoc: ReadableDoc)
    }
    
    @State private var status = Status.fetching
    @State private var titleFromFallbackWebView: String?
    
    public var body: some View {
        content
            .navigationTitle(title ?? url.hostWithoutWWW)
            .toolbarTitleDisplayMode(.inline)
            .task {
                do {
                    let result = try await Reeeed.fetchAndExtractContent(fromURL: url)
                    self.status = .extractedContent(readableDoc: result)
                } catch {
                    status = .failedToExtractContent
                }
            }
    }
    
    @ViewBuilder
    private var content: some View {
        switch status {
        case .fetching:
            ProgressView()
                .controlSize(.extraLarge)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failedToExtractContent:
            FallBackWebView(url: url)
        case .extractedContent(let readableDoc):
            SwiftUIReaderView(readableDoc: readableDoc, onLinkClicked: onLinkClicked)
        }
    }
    
    private var title: String? {
        switch status {
        case .fetching:
            return nil
        case .failedToExtractContent:
            return titleFromFallbackWebView
        case .extractedContent(let readableDoc):
            return readableDoc.title
        }
    }
    
    private func onLinkClicked(_ url: URL) {
        options.onLinkClicked?(url)
    }
}

struct FallBackWebView: View {
    let url: URL
    
    @State private var page = WebPage()
    
    var body: some View {
        WebView(page)
            .navigationTitle(page.title)
            .toolbarTitleDisplayMode(.inline)
            .task {
                await page.load(url)
            }
    }
}

