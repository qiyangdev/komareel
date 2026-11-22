//
//  DoneButton.swift
//  Aidoku
//
//  Created by Skitty on 9/21/25.
//

import SwiftUI

struct DoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(role: .confirm) {
            action()
        }
    }
}
