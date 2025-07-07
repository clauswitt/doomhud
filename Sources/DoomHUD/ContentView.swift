import SwiftUI

struct ContentView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @StateObject private var trackingCoordinator: TrackingCoordinator
    
    init() {
        let dbManager = DatabaseManager()
        _trackingCoordinator = StateObject(wrappedValue: TrackingCoordinator(databaseManager: dbManager))
    }
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(DoomColors.darkBackground.opacity(0.9))
                .frame(width: DoomSizes.hudWidth, height: DoomSizes.hudHeight)
                .border(DoomColors.dimText, width: DoomSizes.borderWidth)
            
            HStack(spacing: 0) {
                // Left Panel - Input Metrics
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("INPUT METRICS")
                            .font(DoomFonts.labelFont)
                            .foregroundColor(DoomColors.brightText)
                        Spacer()
                        Text(trackingCoordinator.getSessionDurationString())
                            .font(DoomFonts.labelFont)
                            .foregroundColor(DoomColors.timeColor)
                    }
                    
                    HStack {
                        MetricDisplayView(
                            label: "MOUSE",
                            value: trackingCoordinator.mouseTracker.totalClickCount,
                            color: DoomColors.mouseColor,
                            isActive: trackingCoordinator.isTracking
                        )
                        
                        MetricDisplayView(
                            label: "KEYS",
                            value: trackingCoordinator.keystrokeTracker.keystrokeCount,
                            color: DoomColors.keystrokeColor,
                            isActive: trackingCoordinator.isTracking
                        )
                    }
                    
                    MetricDisplayView(
                        label: "CONTEXT",
                        value: trackingCoordinator.contextTracker.contextShiftCount,
                        color: DoomColors.contextColor,
                        isActive: trackingCoordinator.isTracking
                    )
                }
                .frame(width: DoomSizes.panelWidth)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Center - Webcam
                WebcamView(
                    webcamManager: trackingCoordinator.webcamManager,
                    size: DoomSizes.webcamSize
                )
                .padding(.vertical, 0)
                
                // Right Panel - Git & Time Metrics
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Text("ACTIVITY")
                            .font(DoomFonts.labelFont)
                            .foregroundColor(trackingCoordinator.activityDetector.isActive ? DoomColors.active : DoomColors.inactive)
                        Spacer()
                        Text("GIT COMMITS")
                            .font(DoomFonts.labelFont)
                            .foregroundColor(DoomColors.brightText)
                    }
                    
                    HStack {
                        BigMetricDisplayView(
                            label: "SESSION",
                            value: trackingCoordinator.gitTracker.sessionCommits,
                            color: DoomColors.gitColor,
                            isActive: trackingCoordinator.isTracking
                        )
                        
                        BigMetricDisplayView(
                            label: "TODAY",
                            value: trackingCoordinator.gitTracker.todayCommits,
                            color: DoomColors.gitColor,
                            isActive: trackingCoordinator.isTracking
                        )
                        
                        BigMetricDisplayView(
                            label: "WEEK",
                            value: trackingCoordinator.gitTracker.weekCommits,
                            color: DoomColors.gitColor,
                            isActive: trackingCoordinator.isTracking
                        )
                    }
                }
                .frame(width: DoomSizes.panelWidth)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .onAppear {
            trackingCoordinator.startTracking()
        }
        .onDisappear {
            trackingCoordinator.stopTracking()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DatabaseManager())
        .background(Color.black)
}