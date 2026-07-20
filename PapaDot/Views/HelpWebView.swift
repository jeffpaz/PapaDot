// Views/HelpWebView.swift
import SwiftUI
import UIKit
import WebKit

// MARK: - Help Web View

struct HelpWebView: View {
    var anchor: String? = nil
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var reloadID = UUID()

    // Known-valid at compile time — the one force-unwrap here can never fail.
    private static let baseURL = URL(string: "https://endopp.com/projects/papadot/docs/")!

    private var url: URL {
        guard let anchor, let anchored = URL(string: "\(Self.baseURL.absoluteString)#\(anchor)") else {
            return Self.baseURL
        }
        return anchored
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if !loadFailed {
                    WebViewRepresentable(url: url, isLoading: $isLoading, loadFailed: $loadFailed)
                        .id(reloadID)
                        .ignoresSafeArea(edges: .bottom)
                }

                if isLoading && !loadFailed {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                }

                if loadFailed {
                    VStack(spacing: 20) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                        Text("Unable to Load Guide")
                            .font(.headline)
                        Text("Check your internet connection and try again.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Retry") {
                            loadFailed = false
                            isLoading = true
                            reloadID = UUID()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                }
            }
            .navigationTitle("PapaDot Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - WKWebView Representable

private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        init(_ parent: WebViewRepresentable) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.loadFailed = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadFailed = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadFailed = true
        }
    }
}

// MARK: - Contextual Help Button

struct HelpButton: View {
    let anchor: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            HelpWebView(anchor: anchor)
        }
    }
}
