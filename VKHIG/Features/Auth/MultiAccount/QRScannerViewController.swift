import SwiftUI
import UIKit
import AVFoundation

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "vkhig.qr.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var handled = false

    var onCode: ((String) -> Void)?
    var onFailure: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                DispatchQueue.main.async { ok ? self?.configure() : self?.onFailure?("Нет доступа к камере") }
            }
        default: onFailure?("Нет доступа к камере. Разрешите его в Настройках.")
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { onFailure?("Камера недоступна"); return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { onFailure?("Камера недоступна"); return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
        sessionQueue.async { [session] in session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !handled,
              let value = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        handled = true
        onCode?(value)
    }

    /// Lets the owner resume scanning after a rejected code.
    func resume() { handled = false }
}

struct QRScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    var onFailure: (String) -> Void
    var resumeToken: Int = 0

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCode = onCode
        vc.onFailure = onFailure
        return vc
    }
    func updateUIViewController(_ vc: QRScannerViewController, context: Context) {
        vc.onCode = onCode
        vc.onFailure = onFailure
        if context.coordinator.lastResume != resumeToken {
            context.coordinator.lastResume = resumeToken
            vc.resume()
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var lastResume = 0 }
}
