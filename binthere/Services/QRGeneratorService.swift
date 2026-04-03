import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum QRGeneratorService {
    static func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        guard let data = string.data(using: .ascii) else { return nil }
        filter.message = data
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Generates a print-ready label with QR code, large bin code text, and branding
    static func generateQRLabel(code: String, binID: String) -> UIImage? {
        guard let qrImage = generateQRCode(from: binID) else { return nil }

        let labelWidth: CGFloat = 400
        let qrSize: CGFloat = 280
        let padding: CGFloat = 30
        let labelHeight = padding + qrSize + 20 + 60 + 10 + 20 + padding

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: labelWidth, height: labelHeight))
        return renderer.image { ctx in
            // White background
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: labelWidth, height: labelHeight))

            // QR code centered
            let qrX = (labelWidth - qrSize) / 2
            qrImage.draw(in: CGRect(x: qrX, y: padding, width: qrSize, height: qrSize))

            // Bin code in large bold text
            let codeFont = UIFont.systemFont(ofSize: 48, weight: .bold)
            let codeAttrs: [NSAttributedString.Key: Any] = [
                .font: codeFont,
                .foregroundColor: UIColor.black,
            ]
            let codeString = NSString(string: code)
            let codeSize = codeString.size(withAttributes: codeAttrs)
            let codeX = (labelWidth - codeSize.width) / 2
            let codeY = padding + qrSize + 20
            codeString.draw(at: CGPoint(x: codeX, y: codeY), withAttributes: codeAttrs)

            // "binthere" branding
            let brandFont = UIFont.systemFont(ofSize: 14, weight: .medium)
            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: brandFont,
                .foregroundColor: UIColor.darkGray,
            ]
            let brandString = NSString(string: "binthere")
            let brandSize = brandString.size(withAttributes: brandAttrs)
            let brandX = (labelWidth - brandSize.width) / 2
            let brandY = codeY + codeSize.height + 10
            brandString.draw(at: CGPoint(x: brandX, y: brandY), withAttributes: brandAttrs)
        }
    }
}
