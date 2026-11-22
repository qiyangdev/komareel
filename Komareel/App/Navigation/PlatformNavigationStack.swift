//
//  PlatformNavigationStack.swift
//  Aidoku
//
//  Created by Skitty on 10/6/23.
//

import SwiftUI

struct PlatformNavigationStack<Content: View>: View {
    @ContentBuilder let content: Content

    var body: some View {
        NavigationStack {
            content
        }
    }
}
