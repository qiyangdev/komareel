//
//  SourceListingViewController.swift
//  Aidoku
//
//  Created by Skitty on 12/27/24.
//

import SwiftUI
import KomareelSourceKit

class SourceListingViewController: MangaListViewController {
    init(source: KomareelSourceKit.Source, listing: KomareelSourceKit.Listing) {
        super.init(
            source: source,
            title: listing.name,
            listingKind: listing.kind
        )
        self.getEntries = { page in
            try await source.getMangaList(listing: listing, page: page)
        }
    }
}
