//
//  UnavailableView.swift
//  Aidoku
//
//  Created by Skitty on 9/23/25.
//

import SwiftUI

struct UnavailableView: View {
    let title: String
    let systemImage: String
    var description: Text?

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: description)
    }

    @ContentBuilder
    static func search(text: String) -> some View {
        ContentUnavailableView.search(text: text)
    }
}
