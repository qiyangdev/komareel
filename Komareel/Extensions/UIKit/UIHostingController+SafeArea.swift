//
//  UIHostingController+SafeArea.swift
//  Aidoku
//
//  Created by Skitty on 6/3/25.
//

import SwiftUI

extension UIHostingController {
    convenience init(rootView: Content, ignoreSafeArea: Bool) {
        self.init(rootView: rootView)

        if ignoreSafeArea {
            disableSafeArea()
        }
    }

    func disableSafeArea() {
        self.safeAreaRegions = []
    }
}
