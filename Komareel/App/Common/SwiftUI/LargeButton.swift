//
//  LargeButton.swift
//  Aidoku
//
//  Created by Skitty on 9/24/25.
//

import SwiftUI

struct LargeButton<Content: View>: View {
    var action: () -> Void
    @ContentBuilder var label: Content

    var body: some View {
        Button {
            action()
        } label: {
            label
                .padding(16)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea()
        }
        .background(
            Color(uiColor: .init(dynamicProvider: { collection in
                if collection.userInterfaceStyle == .dark {
                    .init(red: 0.20, green: 0.12, blue: 0.15, alpha: 1)
                } else {
                    .init(red: 0.95, green: 0.87, blue: 0.91, alpha: 1)
                }
            }))
            .opacity(0.8)
        )
        .padding(0)
        .listRowInsets(.zero)
        .listRowSpacing(0)
    }
}
