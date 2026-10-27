import AVFoundation
import SwiftUI

struct CameraPage: View {
    @StateObject private var camera = CameraBox()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if camera.running {
                CameraPreview(session: camera.session)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(camera.message)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                    Button("Show camera") { camera.ask() }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer(minLength: 0)
        }
        .onDisappear { camera.stop() }
    }
}

final class CameraBox: ObservableObject {
    let session = AVCaptureSession()
    @Published var running = false
    @Published var message = "The mirror stays off until you ask."

    func ask() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                Task { @MainActor in
                    if ok { self.start() } else { self.message = "Camera access is off." }
                }
            }
        default:
            message = "Camera access is off."
        }
    }

    func start() {
        session.beginConfiguration()
        session.sessionPreset = .low
        defer { session.commitConfiguration() }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            message = "No camera found."
            return
        }
        session.addInput(input)
        session.startRunning()
        running = session.isRunning
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
        running = false
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.frame = nsView.bounds
    }
}
