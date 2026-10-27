//
//  ExportHelpers.swift
//  SmartShopper
//
//  CSV export for History ("Export CSV"), receipt text for "Share Receipt",
//  and the invite QR code for the Family screen.
//

import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

enum CSVExporter {

    /// One row per trip item. Quotes are doubled so commas in names do not break the file.
    static func makeCSV(trips: [ShoppingTrip]) -> String {
        var lines = ["Date,Store,Item,Category,Quantity,Price,Added By"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        for trip in trips {
            for item in trip.items {
                let row = [
                    formatter.string(from: trip.date),
                    escape(trip.storeName),
                    escape(item.name),
                    item.category.title,
                    String(item.quantity),
                    String(format: "%.2f", item.price),
                    escape(item.addedByName)
                ]
                lines.append(row.joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n")
    }

    static func escape(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return text
    }

    /// Writes the CSV to a temporary file so ShareLink can share it.
    static func writeFile(trips: [ShoppingTrip]) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SmartShopper-History.csv")
        do {
            try makeCSV(trips: trips).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// Plain-text receipt for "Share Receipt".
    static func receiptText(for trip: ShoppingTrip) -> String {
        var text = "SmartShopper receipt - \(trip.storeName)\n"
        text += trip.date.formatted(date: .abbreviated, time: .shortened) + "\n\n"
        for item in trip.items {
            text += "\(item.name) x\(item.quantity)  \(AppFormat.money(item.price * Double(item.quantity)))\n"
        }
        text += "\nTotal: \(AppFormat.money(trip.total))"
        return text
    }
}

enum QRCodeMaker {
    /// Makes a QR code image from text (used for the family invite).
    static func image(from text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
