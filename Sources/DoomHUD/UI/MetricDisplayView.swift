import SwiftUI

struct MetricDisplayView: View {
    let label: String
    let value: String
    let color: Color
    let isActive: Bool
    
    init(label: String, value: Int, color: Color, isActive: Bool = true) {
        self.label = label
        self.value = String(value)
        self.color = color
        self.isActive = isActive
    }
    
    init(label: String, value: String, color: Color, isActive: Bool = true) {
        self.label = label
        self.value = value
        self.color = color
        self.isActive = isActive
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DoomFonts.labelFont)
                .foregroundColor(isActive ? DoomColors.dimText : DoomColors.inactive)
            
            Text(value)
                .font(DoomFonts.metricFont)
                .foregroundColor(isActive ? color : DoomColors.inactive)
                .opacity(isActive ? 1.0 : 0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BigMetricDisplayView: View {
    let label: String
    let value: String
    let color: Color
    let isActive: Bool
    
    init(label: String, value: Int, color: Color, isActive: Bool = true) {
        self.label = label
        self.value = String(value)
        self.color = color
        self.isActive = isActive
    }
    
    init(label: String, value: String, color: Color, isActive: Bool = true) {
        self.label = label
        self.value = value
        self.color = color
        self.isActive = isActive
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DoomFonts.bigNumberFont)
                .foregroundColor(isActive ? color : DoomColors.inactive)
                .opacity(isActive ? 1.0 : 0.5)
            
            Text(label)
                .font(DoomFonts.labelFont)
                .foregroundColor(isActive ? DoomColors.dimText : DoomColors.inactive)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HStack {
        VStack {
            MetricDisplayView(label: "MOUSE", value: 1337, color: DoomColors.mouseColor)
            MetricDisplayView(label: "KEYS", value: 2048, color: DoomColors.keystrokeColor)
            MetricDisplayView(label: "CONTEXT", value: 42, color: DoomColors.contextColor, isActive: false)
        }
        
        Spacer()
        
        HStack {
            BigMetricDisplayView(label: "SESSION", value: 25, color: DoomColors.gitColor)
            BigMetricDisplayView(label: "TODAY", value: 87, color: DoomColors.gitColor)
            BigMetricDisplayView(label: "WEEK", value: 203, color: DoomColors.gitColor)
        }
    }
    .padding()
    .background(DoomColors.darkBackground)
}