import SwiftUI

public struct ReeeederView: View {
    var url: URL
    
    public init(url: URL) {
        self.url = url
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Open in Safari") {
                            openURL(url)
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
                } catch {
                    status = .failedToExtractContent
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
                NativeReaderView(readableDoc: readableDoc)
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
}
