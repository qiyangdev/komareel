//
//  ReaderPageDescriptionButtonView.swift
//  Aidoku
//
//  Created by Skitty on 5/20/25.
//

import KomareelSourceKit
import MarkdownUI
import SwiftUI

struct ReaderPageDescriptionButtonView: View {
    let source: KomareelSourceKit.Source?
    let pages: [KomareelSourceKit.Page]

    @State private var showingDescription = false

    var body: some View {
        Button {
            showingDescription = true
        } label: {
            if showingDescription {
                Image(systemName: "info.circle.fill")
            } else {
                Image(systemName: "info.circle")
            }
        }
        .sheet(isPresented: $showingDescription) {
            PageDescriptionView(source: source, pages: pages)
                .presentationDetents([.medium, .large])
        }
    }
}

struct PageDescriptionView: View {
    let source: KomareelSourceKit.Source?
    let pages: [KomareelSourceKit.Page]

    @Environment(\.dismiss) private var dismiss

    @State private var description: String?
    @State private var error: Error?

    var body: some View {
        PlatformNavigationStack {
            Group {
                if let error {
                    ErrorView(
                        error: error,
                        retry: {
                            self.error = nil
                            await loadDescription()
                        }
                    )
                } else {
                    ScrollView(.vertical) {
                        if let description {
                            Markdown(description)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadDescription()
        }
    }

    func loadDescription() async {
        do {
            description = try await pages
                .asyncCompactMap { (page: KomareelSourceKit.Page) async throws -> String? in
                    if let description = page.description {
                        description
                    } else if page.hasDescription {
                        if let source {
                            try await source.getPageDescription(page: page)
                        } else  {
                            NSLocalizedString("UNAVAILABLE")
                        }
                    } else {
                        nil
                    }
                }
                .joined(separator: "\n\n")
        } catch {
            withAnimation {
                self.error = error
            }
        }
    }
}
