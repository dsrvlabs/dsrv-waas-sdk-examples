import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned) }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        let onScanned: (String) -> Void
        private var fired = false

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        func scanner(_ scanner: ScannerViewController, didScan value: String) {
            guard !fired else { return }
            fired = true
            onScanned(value)
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func scanner(_ scanner: ScannerViewController, didScan value: String)
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            renderUnavailable()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            renderUnavailable()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.layer.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    private func renderUnavailable() {
        let label = UILabel()
        label.text = "카메라를 사용할 수 없습니다"
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let metaObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metaObj.type == .qr,
              let str = metaObj.stringValue else { return }
        session.stopRunning()
        delegate?.scanner(self, didScan: str)
    }
}
