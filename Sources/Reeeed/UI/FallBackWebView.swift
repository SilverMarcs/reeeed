//
//  FallBackWebView.swift
//  Reeeed
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import WebKit

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
