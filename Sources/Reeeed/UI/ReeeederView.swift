import SwiftUI

public struct ReeeederView<ImageRenderer: View>: View {
    var url: URL
    var onExtractedText: ((String?) -> Void)?
    var imageRenderer: ((URL) -> ImageRenderer)?
    
    public init(url: URL, onExtractedText: ((String?) -> Void)? = nil, imageRenderer: ((URL) -> ImageRenderer)? = nil) {
        self.url = url
        self.onExtractedText = onExtractedText
        self.imageRenderer = imageRenderer
    }
    
    enum Status: Equatable {
        case fetching
        case failedToExtractContent
        case extractedContent(readableDoc: ReadableDoc)
    }
    
    @State private var status = Status.fetching
    @State private var showWebView = false
    @Environment(\.openURL) private var openURL
    
    public var body: some View {
        content
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Open in Safari") {
                            #if canImport(UIKit) && !os(watchOS)
                                UIApplication.shared.open(url)
                            #elseif canImport(AppKit)
                                NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        Label(
                            showWebView ? "Show Reader" : "Show Web View",
                            systemImage: showWebView ? "text.page" : "globe"
                        )
                    } primaryAction: {
                        showWebView.toggle()
                    }
                }
            }
            .task {
                do {
                    let result = try await Reeeed.fetchAndExtractContent(fromURL: url)
                    self.status = .extractedContent(readableDoc: result)
                    onExtractedText?(extractedText)
                } catch {
                    status = .failedToExtractContent
                    onExtractedText?(nil)
                }
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if showWebView || status == .failedToExtractContent {
            FallBackWebView(url: url)
        } else {
            switch status {
            case .fetching:
                ProgressView()
                    .controlSize(.extraLarge)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failedToExtractContent:
                FallBackWebView(url: url)
            case .extractedContent(let readableDoc):
                NativeReaderView(readableDoc: readableDoc, imageRenderer: imageRenderer)
            }
        }
    }
    
    private var title: String {
        switch status {
        case .fetching:
            return "Loading"
        case .failedToExtractContent:
            return url.hostWithoutWWW
        case .extractedContent(let readableDoc):
            return readableDoc.title ?? url.hostWithoutWWW
        }
    }
    
    private var extractedText: String? {
        if case .extractedContent(let readableDoc) = status {
            return readableDoc.extracted.extractPlainText
        }
        return nil
    }
}
