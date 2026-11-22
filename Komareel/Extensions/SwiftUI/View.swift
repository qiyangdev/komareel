//
//  View.swift
//  Aidoku
//
//  Created by Skitty on 7/21/22.
//

import SwiftUI

struct NoHitTesting: ViewModifier {
    func body(content: Content) -> some View {
        SwiftUIWrapper { content }.allowsHitTesting(false)
    }
}

struct SwiftUIWrapper<T: View>: UIViewControllerRepresentable {
    let content: () -> T
    func makeUIViewController(context: Context) -> UIHostingController<T> {
        UIHostingController(rootView: content())
    }
    func updateUIViewController(_ uiViewController: UIHostingController<T>, context: Context) {}
}

extension View {
    @ContentBuilder
    func userInteractionDisabled(_ disabled: Bool = true) -> some View {
        if disabled {
            self.modifier(NoHitTesting())
        } else {
            self
        }
    }

//    @ContentBuilder
//    func hidden(_ hidden: Bool) -> some View {
//        if hidden {
//            self.hidden()
//        } else {
//            self
//        }
//    }
}

extension View {
    @ContentBuilder
    func offsetListSeparator() -> some View {
        self.alignmentGuide(.listRowSeparatorLeading) { d in
            d[.leading]
        }
    }
}

extension View {
    func scrollClipDisabledPlease() -> some View {
        self.scrollClipDisabled()
    }

    func scrollTargetLayoutPlease(isEnabled: Bool = true) -> some View {
        self.scrollTargetLayout(isEnabled: isEnabled)
    }

    func scrollViewAlignedPlease() -> some View {
        self.scrollTargetBehavior(.viewAligned)
    }

    func scrollBackgroundHiddenPlease() -> some View {
        self.scrollContentBackground(.hidden)
    }

    func scrollPositionPlease(id: Binding<(some Hashable)?>, anchor: UnitPoint? = nil) -> some View {
        self.scrollPosition(id: id, anchor: anchor)
    }

    func contentTransitionDisabledPlease() -> some View {
        self.contentTransition(.identity)
    }

    func listSectionSpacingPlease(_ spacing: CGFloat) -> some View {
        self.listSectionSpacing(spacing)
    }

    func scrollDismissesKeyboardInteractively() -> some View {
        self.scrollDismissesKeyboard(.interactively)
    }

    func scrollDismissesKeyboardImmediately() -> some View {
        self.scrollDismissesKeyboard(.immediately)
    }

    func contentMarginsPlease(
        _ edges: Edge.Set = .all,
        _ length: CGFloat?,
    ) -> some View {
        self.contentMargins(edges, length)
    }

    func matchedTransitionSourcePlease(id: some Hashable, in namespace: Namespace.ID) -> some View {
        self.matchedTransitionSource(id: id, in: namespace)
    }

    func navigationTransitionZoom(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
    }

    func menuActionDismissDisabled() -> some View {
        self.menuActionDismissBehavior(.disabled)
    }

    func centerScrollAnchorPlease() -> some View {
        self.defaultScrollAnchor(.center, for: .alignment)
    }

    func onChangeWrapper<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        self.onChange(of: value, initial: initial, action)
    }
}

extension View {
    @ContentBuilder
    func tag<T: Hashable>(_ tag: T, selectable: Bool) -> some View {
        self
            .tag(tag)
            .selectionDisabled(!selectable)
    }
}

enum AnimationOptions {
    case linear
    case easeIn
    case easeOut
    case easeInOut
}

extension View {
    static func animate(
        duration: CGFloat,
        options: AnimationOptions = .linear,
        _ execute: @escaping () -> Void
    ) async {
        await withCheckedContinuation { continuation in
            let animation: Animation = switch options {
                case .linear:
                    .linear(duration: duration)
                case .easeIn:
                    .easeIn(duration: duration)
                case .easeOut:
                    .easeOut(duration: duration)
                case .easeInOut:
                    .easeInOut(duration: duration)
            }
            withAnimation(animation) {
                execute()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                continuation.resume()
            }
        }
    }

    func animate(
        duration: CGFloat,
        options: AnimationOptions = .linear,
        _ execute: @escaping () -> Void
    ) async {
        await Self.animate(duration: duration, options: options, execute)
    }
}

extension View {
    /// Focuses next field in sequence, from the given `FocusState`.
    /// Requires a currently active focus state and a next field available in the sequence.
    ///
    /// Example usage:
    /// ```
    /// .onSubmit { self.focusNextField($focusedField) }
    /// ```
    /// Given that `focusField` is an enum that represents the focusable fields. For example:
    /// ```
    /// @FocusState private var focusedField: Field?
    /// enum Field: Int, Hashable {
    ///    case name
    ///    case country
    ///    case city
    /// }
    /// ```
    func focusNextField<F: RawRepresentable>(_ field: FocusState<F?>.Binding) where F.RawValue == Int {
        guard let currentValue = field.wrappedValue else { return }
        let nextValue = currentValue.rawValue + 1
        if let newValue = F(rawValue: nextValue) {
            field.wrappedValue = newValue
        }
    }
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ContentBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension View {
    @ContentBuilder func modifier<Content: View>(@ContentBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }
}
