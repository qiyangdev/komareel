//
//  ReaderSliderView.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 1/20/22.
//

import UIKit

final class ReaderSliderView: UISlider {
    enum SliderDirection {
        case forward
        case backward
    }

    var direction: SliderDirection = .forward {
        didSet {
            semanticContentAttribute = direction == .forward ? .forceLeftToRight : .forceRightToLeft
        }
    }

    private(set) var isScrubbing = false

    var currentValue: CGFloat { CGFloat(value) }

    var thumbCenter: CGPoint {
        let thumb = thumbRect(forBounds: bounds, trackRect: trackRect(forBounds: bounds), value: value)
        return CGPoint(x: thumb.midX, y: thumb.midY)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .forceLeftToRight
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func move(toValue value: CGFloat) {
        guard !isScrubbing else { return }
        setValue(Float(value), animated: false)
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        isScrubbing = true
        guard super.beginTracking(touch, with: event) else {
            isScrubbing = false
            return false
        }
        sendActions(for: .editingDidBegin)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        finishScrubbing()
    }

    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        finishScrubbing()
    }

    private func finishScrubbing() {
        guard isScrubbing else { return }
        isScrubbing = false
        sendActions(for: .editingDidEnd)
    }
}
