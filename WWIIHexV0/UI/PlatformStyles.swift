import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PlatformStyles {
    static var systemBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var secondarySystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    static var tertiarySystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(uiColor: .tertiarySystemBackground)
        #endif
    }

    static var panelStroke: Color {
        .secondary.opacity(0.28)
    }

    static var selectionTint: Color {
        .yellow.opacity(0.18)
    }
}

enum NapoleonicDesignTokens {
    static let panelPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 10
    static let metricSpacing: CGFloat = 2
    static let cornerRadius: CGFloat = 8
    static let compactCornerRadius: CGFloat = 6

    static var campaignPanelBackground: Color {
        PlatformStyles.systemBackground
    }

    static var campaignPanelStroke: Color {
        Color(red: 0.20, green: 0.24, blue: 0.29).opacity(0.34)
    }

    static var mapPaperWash: Color {
        Color(red: 0.74, green: 0.68, blue: 0.54).opacity(0.12)
    }

    static var imperialBlue: Color {
        Color(red: 0.11, green: 0.23, blue: 0.42)
    }

    static var coalitionRed: Color {
        Color(red: 0.56, green: 0.16, blue: 0.16)
    }

    static var brass: Color {
        Color(red: 0.66, green: 0.47, blue: 0.16)
    }

    static var steady: Color {
        Color(red: 0.13, green: 0.42, blue: 0.30)
    }

    static var warning: Color {
        Color(red: 0.72, green: 0.42, blue: 0.08)
    }

    static var critical: Color {
        Color(red: 0.62, green: 0.12, blue: 0.14)
    }
}
