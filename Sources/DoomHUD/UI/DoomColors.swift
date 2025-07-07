import SwiftUI

struct DoomColors {
    // Primary DOOM colors
    static let red = Color(red: 0.8, green: 0.0, blue: 0.0)
    static let green = Color(red: 0.0, green: 0.8, blue: 0.0)
    static let blue = Color(red: 0.0, green: 0.0, blue: 0.8)
    static let yellow = Color(red: 1.0, green: 1.0, blue: 0.0)
    static let orange = Color(red: 1.0, green: 0.5, blue: 0.0)
    static let purple = Color(red: 0.5, green: 0.0, blue: 1.0)
    static let cyan = Color(red: 0.0, green: 1.0, blue: 1.0)
    
    // Background colors
    static let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let mediumBackground = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let lightBackground = Color(red: 0.3, green: 0.3, blue: 0.3)
    
    // Text colors
    static let brightText = Color.white
    static let dimText = Color(red: 0.7, green: 0.7, blue: 0.7)
    
    // Status colors
    static let active = green
    static let inactive = red
    static let warning = orange
    static let info = cyan
    
    // Metric colors
    static let mouseColor = red
    static let keystrokeColor = green
    static let contextColor = yellow
    static let gitColor = cyan
    static let timeColor = purple
}

struct DoomFonts {
    static let hudFont = Font.system(size: 16, weight: .bold, design: .monospaced)
    static let metricFont = Font.system(size: 20, weight: .heavy, design: .monospaced)
    static let labelFont = Font.system(size: 12, weight: .semibold, design: .monospaced)
    static let bigNumberFont = Font.system(size: 24, weight: .black, design: .monospaced)
}

struct DoomSizes {
    static let hudWidth: CGFloat = 800
    static let hudHeight: CGFloat = 120
    static let webcamSize: CGFloat = 120
    static let panelWidth: CGFloat = 280
    static let borderWidth: CGFloat = 2
    static let cornerRadius: CGFloat = 4
}