import SwiftUI
import AVFoundation

struct WebcamView: View {
    @ObservedObject var webcamManager: WebcamManager
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(DoomColors.darkBackground)
                .frame(width: size, height: size)
                .border(DoomColors.dimText, width: DoomSizes.borderWidth)
            
            if webcamManager.isWebcamActive {
                // Webcam preview
                WebcamPreviewView(webcamManager: webcamManager)
                    .frame(width: size - 4, height: size - 4)
                    .clipped()
                
                // Motion indicator
                if webcamManager.isMotionDetected {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(DoomColors.active)
                                .frame(width: 8, height: 8)
                                .padding(4)
                        }
                        Spacer()
                    }
                }
            } else {
                // No webcam placeholder
                VStack {
                    Text("CAM")
                        .font(DoomFonts.hudFont)
                        .foregroundColor(DoomColors.inactive)
                    
                    Text("OFFLINE")
                        .font(DoomFonts.labelFont)
                        .foregroundColor(DoomColors.inactive)
                }
            }
        }
        .onAppear {
            webcamManager.startCapture()
        }
        .onDisappear {
            webcamManager.stopCapture()
        }
    }
}

struct WebcamPreviewView: NSViewRepresentable {
    let webcamManager: WebcamManager
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        if let previewLayer = webcamManager.getPreviewLayer() {
            previewLayer.frame = view.bounds
            view.layer = previewLayer
            view.wantsLayer = true
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let previewLayer = webcamManager.getPreviewLayer() {
            previewLayer.frame = nsView.bounds
        }
    }
}

#Preview {
    WebcamView(webcamManager: WebcamManager(), size: 120)
        .background(DoomColors.darkBackground)
}