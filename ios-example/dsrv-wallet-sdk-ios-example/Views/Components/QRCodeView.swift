import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let content: String
    var size: CGFloat = 220

    var body: some View {
        ZStack {
            Color.white
            if let image = generate(content: content, side: size) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size + 32, height: size + 32)
    }

    private func generate(content: String, side: CGFloat) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = side / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
