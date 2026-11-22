//
//  CloseButton.swift
//  Aidoku
//
//  Created by Skitty on 12/31/24.
//

import SwiftUI

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(role: .close) {
            action()
        }
    }
}
