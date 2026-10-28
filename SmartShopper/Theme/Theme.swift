//
//  Theme.swift
//  SmartShopper
//
//  All colours used in the app live here.
//  Every colour is a Colour Set in Assets.xcassets that has a Light AND a Dark value,
//  so the whole app switches to dark mode automatically ;no "if dark" checks needed.


import SwiftUI

extension Color {
// Brand greens
    static let brandPrimary = Color("AppPrimary")        // main buttons, selected tab, toggles
    static let brandAccent = Color("AppAccent")          // bright icons, progress fills
    static let brandMint = Color("AppMint")              // light green badges / secondary buttons
    static let brandMintSoft = Color("AppMintSoft")      // icon circles, privacy cards
    static let heroGreen = Color("AppHero")              // big green "Shop Along Your Route" card

//Backgrounds
    static let canvas = Color("AppCanvas")               // screen background
    static let surface = Color("AppSurface")             // cards and rows
    static let surfaceMuted = Color("AppSurfaceMuted")   // text fields, grey chips
    static let separatorLine = Color("AppSeparator")     // card borders, dividers

// Text
    static let textPrimary = Color("AppTextPrimary")
    static let textSecondary = Color("AppTextSecondary")
    static let textTertiary = Color("AppTextTertiary")
    static let onPrimary = Color("AppOnPrimary")         // text drawn on top of brandPrimary

    // Status colours
    static let infoBlue = Color("AppInfo")
    static let infoSoft = Color("AppInfoSoft")
    static let warningOrange = Color("AppWarning")
    static let warningSoft = Color("AppWarningSoft")
    static let dangerRed = Color("AppDanger")
    static let dangerSoft = Color("AppDangerSoft")
}


enum AppLayout {
    static let screenPadding: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 14
    static let fieldRadius: CGFloat = 12
    static let sectionSpacing: CGFloat = 16
    static let buttonHeight: CGFloat = 52
}

// Money formatting
enum AppFormat {
    //Change to ANY CURRENCY
    static let currencyCode = "LKR"

    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    // "15m ago", "2h ago", "Yesterday"
    static func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // 350 m / 1.2 km
    static func distance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}
