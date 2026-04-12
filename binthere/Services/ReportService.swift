import UIKit
import SwiftData

enum ReportService {

    // MARK: - CSV Export

    static func generateCSV(zones: [Zone], bins: [Bin]) -> Data? {
        var csv = "Zone,Bin Code,Bin Label,Item Name,Description,Value,Tags,Color,Checked Out,Checked Out To,Notes\n"

        for bin in bins.sorted(by: { $0.code < $1.code }) {
            let zoneName = bin.zone?.name ?? ""
            for item in bin.items.sorted(by: { $0.name < $1.name }) {
                let activeCheckout = item.checkoutHistory.first(where: { $0.isActive })
                let row = [
                    escapeCSV(zoneName),
                    escapeCSV(bin.code),
                    escapeCSV(bin.name),
                    escapeCSV(item.name),
                    escapeCSV(item.itemDescription),
                    item.value.map { String(format: "%.2f", $0) } ?? "",
                    escapeCSV(item.tags.joined(separator: "; ")),
                    escapeCSV(item.color),
                    item.isCheckedOut ? "Yes" : "No",
                    escapeCSV(activeCheckout?.checkedOutTo ?? ""),
                    escapeCSV(item.notes),
                ].joined(separator: ",")
                csv += row + "\n"
            }
        }

        return csv.data(using: .utf8)
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - Insurance Report PDF

    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 50
    private static var contentWidth: CGFloat { pageWidth - margin * 2 }

    static func generateInsuranceReport(zones: [Zone], bins: [Bin]) -> Data? {
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)

        drawCoverPage(zones: zones, bins: bins)
        drawContentPages(bins: bins)

        UIGraphicsEndPDFContext()
        return pdfData as Data
    }

    private static func drawCoverPage(zones: [Zone], bins: [Bin]) {
        UIGraphicsBeginPDFPage()
        var yPos = margin + 200

        yPos = drawText("binthere", at: CGPoint(x: margin, y: yPos), width: contentWidth,
                        font: .systemFont(ofSize: 36, weight: .bold), alignment: .center)
        yPos = drawText("Inventory Report", at: CGPoint(x: margin, y: yPos + 10), width: contentWidth,
                        font: .systemFont(ofSize: 24, weight: .medium), color: .darkGray, alignment: .center)
        yPos = drawText(Date().formatted(date: .long, time: .omitted),
                        at: CGPoint(x: margin, y: yPos + 20), width: contentWidth,
                        font: .systemFont(ofSize: 14), color: .gray, alignment: .center)

        let totalItems = bins.reduce(0) { $0 + $1.items.count }
        let totalValue = bins.reduce(0.0) { $0 + $1.totalValue }

        yPos += 60
        yPos = drawText("\(bins.count) Bins · \(totalItems) Items · \(zones.count) Zones",
                        at: CGPoint(x: margin, y: yPos), width: contentWidth,
                        font: .systemFont(ofSize: 16), color: .darkGray, alignment: .center)
        _ = drawText("Total Value: \(CurrencyFormatter.format(totalValue))",
                     at: CGPoint(x: margin, y: yPos + 10), width: contentWidth,
                     font: .systemFont(ofSize: 20, weight: .semibold), alignment: .center)
    }

    private static func drawContentPages(bins: [Bin]) {
        let grouped = Dictionary(grouping: bins) { $0.zone?.name ?? "No Zone" }
        var yPos = margin

        for zoneName in grouped.keys.sorted() {
            guard let zoneBins = grouped[zoneName] else { continue }

            yPos = ensureSpace(yPosition: yPos, needed: 80, pageHeight: pageHeight, margin: margin)
            yPos = drawText(zoneName, at: CGPoint(x: margin, y: yPos), width: contentWidth,
                            font: .systemFont(ofSize: 18, weight: .bold))
            let zoneValue = zoneBins.reduce(0.0) { $0 + $1.totalValue }
            if zoneValue > 0 {
                yPos = drawText("Zone total: \(CurrencyFormatter.format(zoneValue))",
                                at: CGPoint(x: margin, y: yPos), width: contentWidth,
                                font: .systemFont(ofSize: 12), color: .gray)
            }
            yPos += 10

            for bin in zoneBins.sorted(by: { $0.code < $1.code }) {
                yPos = drawBinSection(bin: bin, yPosition: yPos)
            }
        }
    }

    private static func drawBinSection(bin: Bin, yPosition: CGFloat) -> CGFloat {
        var yPos = ensureSpace(yPosition: yPosition, needed: 50, pageHeight: pageHeight, margin: margin)
        let binTitle = bin.name.isEmpty ? bin.code : "\(bin.code) — \(bin.name)"
        yPos = drawText(binTitle, at: CGPoint(x: margin + 10, y: yPos), width: contentWidth - 10,
                        font: .systemFont(ofSize: 14, weight: .semibold))
        if bin.totalValue > 0 {
            yPos = drawText("\(bin.items.count) items · \(CurrencyFormatter.format(bin.totalValue))",
                            at: CGPoint(x: margin + 10, y: yPos), width: contentWidth - 10,
                            font: .systemFont(ofSize: 10), color: .gray)
        }
        yPos += 5

        for item in bin.items.sorted(by: { $0.name < $1.name }) {
            yPos = drawItemRow(item: item, yPosition: yPos)
        }
        return yPos + 10
    }

    private static func drawItemRow(item: Item, yPosition: CGFloat) -> CGFloat {
        var yPos = ensureSpace(yPosition: yPosition, needed: 60, pageHeight: pageHeight, margin: margin)

        if let path = item.imagePaths.first,
           let image = ImageStorageService.loadImage(filename: path) {
            image.draw(in: CGRect(x: margin + 20, y: yPos, width: 40, height: 40))
        }

        let textX = margin + 70
        let textWidth = contentWidth - 70
        let nameY = drawText(item.name, at: CGPoint(x: textX, y: yPos), width: textWidth,
                             font: .systemFont(ofSize: 12, weight: .medium))

        var detailParts: [String] = []
        if let value = item.value { detailParts.append(CurrencyFormatter.format(value)) }
        if !item.tags.isEmpty { detailParts.append(item.tags.joined(separator: ", ")) }
        if !detailParts.isEmpty {
            _ = drawText(detailParts.joined(separator: " · "), at: CGPoint(x: textX, y: nameY), width: textWidth,
                         font: .systemFont(ofSize: 10), color: .gray)
        }

        return max(yPos + 45, nameY + 15)
    }

    // MARK: - Bin Manifest PDF

    static func generateBinManifest(bin: Bin) -> Data? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)
        UIGraphicsBeginPDFPage()

        var yPosition = margin

        // Bin header with QR
        yPosition = drawText(bin.code, at: CGPoint(x: margin, y: yPosition), width: contentWidth,
                             font: .systemFont(ofSize: 30, weight: .bold))
        if !bin.name.isEmpty {
            yPosition = drawText(bin.name, at: CGPoint(x: margin, y: yPosition), width: contentWidth,
                                 font: .systemFont(ofSize: 16), color: .darkGray)
        }

        // QR code
        if let qrImage = QRGeneratorService.generateQRCode(from: bin.id.uuidString) {
            let qrRect = CGRect(x: pageWidth - margin - 80, y: margin, width: 80, height: 80)
            qrImage.draw(in: qrRect)
        }

        if let zone = bin.zone {
            yPosition = drawText("Zone: \(zone.name)", at: CGPoint(x: margin, y: yPosition), width: contentWidth,
                                 font: .systemFont(ofSize: 12), color: .gray)
        }

        yPosition = drawText("\(bin.items.count) items · \(CurrencyFormatter.format(bin.totalValue))",
                             at: CGPoint(x: margin, y: yPosition), width: contentWidth,
                             font: .systemFont(ofSize: 12), color: .gray)
        yPosition += 20

        // Divider
        UIColor.lightGray.setStroke()
        let dividerPath = UIBezierPath()
        dividerPath.move(to: CGPoint(x: margin, y: yPosition))
        dividerPath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
        dividerPath.stroke()
        yPosition += 15

        // Items
        for item in bin.items.sorted(by: { $0.name < $1.name }) {
            yPosition = ensureSpace(yPosition: yPosition, needed: 55, pageHeight: pageHeight, margin: margin)

            if let path = item.imagePaths.first,
               let image = ImageStorageService.loadImage(filename: path) {
                image.draw(in: CGRect(x: margin, y: yPosition, width: 40, height: 40))
            }

            let textX = margin + 50
            let nameY = drawText(item.name, at: CGPoint(x: textX, y: yPosition), width: contentWidth - 50,
                                 font: .systemFont(ofSize: 13, weight: .medium))

            var detail = ""
            if let value = item.value { detail = CurrencyFormatter.format(value) }
            if !item.itemDescription.isEmpty {
                if !detail.isEmpty { detail += " — " }
                detail += item.itemDescription
            }
            if !detail.isEmpty {
                _ = drawText(detail, at: CGPoint(x: textX, y: nameY), width: contentWidth - 50,
                             font: .systemFont(ofSize: 10), color: .gray)
            }

            yPosition = max(yPosition + 45, nameY + 15)
        }

        UIGraphicsEndPDFContext()
        return pdfData as Data
    }

    // MARK: - Drawing Helpers

    @discardableResult
    private static func drawText(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont = .systemFont(ofSize: 12),
        color: UIColor = .black,
        alignment: NSTextAlignment = .left
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]

        let attrString = NSAttributedString(string: text, attributes: attrs)
        let boundingRect = attrString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        attrString.draw(in: CGRect(x: point.x, y: point.y, width: width, height: boundingRect.height))
        return point.y + boundingRect.height
    }

    private static func ensureSpace(yPosition: CGFloat, needed: CGFloat, pageHeight: CGFloat, margin: CGFloat) -> CGFloat {
        if yPosition + needed > pageHeight - margin {
            UIGraphicsBeginPDFPage()
            return margin
        }
        return yPosition
    }
}
