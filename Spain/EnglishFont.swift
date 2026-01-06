//
//  EnglishFont.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import SwiftUI
import UIKit

enum EnglishFontOption: String, CaseIterable, Identifiable {
    case system
    case timesNewRoman

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "San Francisco"
        case .timesNewRoman:
            return "Times New Roman"
        }
    }

    func font(for style: Font.TextStyle) -> Font {
        switch self {
        case .system:
            return .system(style)
        case .timesNewRoman:
            let size = UIFont.preferredFont(forTextStyle: style.uiTextStyle).pointSize
            return .custom("Times New Roman", size: size)
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .system:
            return .system(size: size)
        case .timesNewRoman:
            return .custom("Times New Roman", size: size)
        }
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title1
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .body:
            return .body
        case .callout:
            return .callout
        case .footnote:
            return .footnote
        case .caption:
            return .caption1
        case .caption2:
            return .caption2
        @unknown default:
            return .body
        }
    }
}

struct EnglishText: View {
    @AppStorage("english_font_option") private var fontOptionRaw = EnglishFontOption.system.rawValue
    let text: String
    var style: Font.TextStyle = .body
    var size: CGFloat? = nil
    var weight: Font.Weight? = nil

    private var fontOption: EnglishFontOption {
        EnglishFontOption(rawValue: fontOptionRaw) ?? .system
    }

    var body: some View {
        Text(text)
            .font(size.map { fontOption.font(size: $0) } ?? fontOption.font(for: style))
            .fontWeight(weight)
    }
}

struct MeaningText: View {
    let text: String
    let language: MeaningLanguage
    var style: Font.TextStyle = .body
    var size: CGFloat? = nil
    var weight: Font.Weight? = nil

    var body: some View {
        if language == .english {
            EnglishText(text: text, style: style, size: size, weight: weight)
        } else {
            Text(text)
                .font(size.map { .system(size: $0) } ?? .system(style))
                .fontWeight(weight)
        }
    }
}
