//
//  ReaderToolbarView.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 8/15/22.
//

import UIKit

final class ReaderToolbarView: UIView {
    var currentPage: Int? {
        didSet { updateAccessibilityValue() }
    }
    var totalPages: Int? {
        didSet {
            sliderView.isEnabled = (totalPages ?? 0) > 1
            updateAccessibilityValue()
        }
    }

    let sliderView = ReaderSliderView()
    weak var pagePreviewHost: UIView?

    private let feedback = UISelectionFeedbackGenerator()
    private var previewPage: Int?

    private let pageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        )
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private lazy var pagePreview: UIVisualEffectView = {
        let preview = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        preview.clipsToBounds = true
        preview.isUserInteractionEnabled = false
        preview.accessibilityElementsHidden = true
        preview.contentView.addSubview(pageLabel)
        return preview
    }()

    init() {
        super.init(frame: .zero)
        sliderView.isEnabled = false
        sliderView.accessibilityLabel = NSLocalizedString("PAGE_PLURAL")
        sliderView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sliderView)

        NSLayoutConstraint.activate([
            sliderView.topAnchor.constraint(equalTo: topAnchor),
            sliderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            sliderView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            sliderView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func beginPagePreview() {
        guard let host = pagePreviewHost, sliderView.isEnabled else { return }
        host.addSubview(pagePreview)
        feedback.prepare()
        displayPage(currentPage ?? 1)
    }

    func endPagePreview() {
        pagePreview.removeFromSuperview()
        previewPage = nil
        updateAccessibilityValue()
    }

    func displayPage(_ page: Int) {
        guard sliderView.isScrubbing, let page = boundedPage(page) else { return }
        if page != previewPage {
            if previewPage != nil { feedback.selectionChanged() }
            previewPage = page
        }
        updateAccessibilityValue()
        guard let host = pagePreview.superview else { return }
        pageLabel.text = sliderView.accessibilityValue
        let textSize = pageLabel.intrinsicContentSize
        let width = max(64, textSize.width + 24)
        let height = max(32, textSize.height + 12)
        let thumb = sliderView.convert(sliderView.thumbCenter, to: host)
        let safeBounds = host.bounds.inset(by: host.safeAreaInsets).insetBy(dx: 12, dy: 0)
        let x = min(max(thumb.x - width / 2, safeBounds.minX), max(safeBounds.minX, safeBounds.maxX - width))
        pagePreview.frame = CGRect(x: x, y: thumb.y - height - 24, width: width, height: height)
        pagePreview.layer.cornerRadius = height / 2
        pageLabel.frame = pagePreview.bounds
    }

    func updateSliderPosition() {
        guard let currentPage, let totalPages else { return }
        sliderView.move(toValue: CGFloat(currentPage - 1) / max(CGFloat(totalPages - 1), 1))
    }

    private func boundedPage(_ page: Int) -> Int? {
        guard let totalPages, totalPages > 0 else { return nil }
        return min(max(page, 1), totalPages)
    }

    private func updateAccessibilityValue() {
        guard let page = boundedPage(previewPage ?? currentPage ?? 1), let totalPages else {
            sliderView.accessibilityValue = nil
            return
        }
        sliderView.accessibilityValue = String(format: NSLocalizedString("%i_OF_%i"), page, totalPages)
    }
}
