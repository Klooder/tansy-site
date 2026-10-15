// Blank Greene Climacteric Scale for printing: one A4 page, the scale's own wording
// from the app's Greene.json (the same file the app prints from).
//
//   swift tools/greene-pdf.swift ../Betony/Engine/Resources/Greene.json \
//       menopause-symptom-checklist-for-doctor/greene-climacteric-scale.pdf
//
// The text fits A4 and US Letter alike: the drawn area is 515 × 690 pt.

import AppKit
import Foundation

struct Scale: Decodable {
    struct Item: Decodable { let id: Int; let text: String }
    struct Subscale: Decodable { let title: String; let first: Int; let last: Int }
    let source: String
    let instruction: String
    let options: [String]
    let items: [Item]
    let subscales: [Subscale]
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { fatalError("usage: greene-pdf.swift Greene.json out.pdf") }
let scale = try! JSONDecoder().decode(Scale.self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))
let output = URL(fileURLWithPath: arguments[2])
try! FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)

var box = CGRect(x: 0, y: 0, width: 595, height: 842)
guard let context = CGContext(output as CFURL, mediaBox: &box, [
    kCGPDFContextTitle: "Greene Climacteric Scale",
    kCGPDFContextCreator: "Tansy",
] as CFDictionary) else { fatalError("PDF не пишется") }

context.beginPDFPage(nil)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
context.translateBy(x: 0, y: box.height)
context.scaleBy(x: 1, y: -1)

let margin: CGFloat = 40
let width = box.width - margin * 2
let ink = NSColor.black
let grey = NSColor(white: 0.35, alpha: 1)

@discardableResult
func text(_ string: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular,
          color: NSColor = ink, width: CGFloat? = nil, align: NSTextAlignment = .left) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style,
    ]
    let available = width ?? (box.width - margin - point.x)
    let bounds = (string as NSString).boundingRect(with: CGSize(width: available, height: 400),
                                                   options: [.usesLineFragmentOrigin], attributes: attributes)
    (string as NSString).draw(with: CGRect(x: point.x, y: point.y, width: available, height: bounds.height),
                              options: [.usesLineFragmentOrigin], attributes: attributes)
    return ceil(bounds.height)
}

func line(from start: CGPoint, to end: CGPoint, width lineWidth: CGFloat = 0.5) {
    context.setStrokeColor(grey.cgColor)
    context.setLineWidth(lineWidth)
    context.move(to: start)
    context.addLine(to: end)
    context.strokePath()
}

var y = margin
y += text("Greene Climacteric Scale", at: CGPoint(x: margin, y: y), size: 18, weight: .semibold) + 6
y += text("Name ____________________________    Date ______________", at: CGPoint(x: margin, y: y), size: 10, color: grey) + 10
y += text(scale.instruction + ".", at: CGPoint(x: margin, y: y), size: 10, width: width) + 10

// Columns: item text, then one column per answer with its number.
let column: CGFloat = 62
let firstColumn = box.width - margin - column * CGFloat(scale.options.count)
for (index, option) in scale.options.enumerated() {
    let x = firstColumn + column * CGFloat(index)
    text("\(option)\n(\(index))", at: CGPoint(x: x, y: y), size: 8, weight: .semibold, color: grey, width: column, align: .center)
}
y += 26
line(from: CGPoint(x: margin, y: y), to: CGPoint(x: box.width - margin, y: y), width: 0.8)

let row: CGFloat = 22
for item in scale.items {
    text("\(item.id). \(item.text)", at: CGPoint(x: margin, y: y + 5), size: 10, width: firstColumn - margin - 8)
    for index in scale.options.indices {
        let center = firstColumn + column * (CGFloat(index) + 0.5)
        let square = CGRect(x: center - 5, y: y + 6, width: 10, height: 10)
        context.setStrokeColor(ink.cgColor)
        context.setLineWidth(0.8)
        context.stroke(square)
    }
    y += row
    line(from: CGPoint(x: margin, y: y), to: CGPoint(x: box.width - margin, y: y))
}

y += 14
y += text("Totals (add the numbers of the answers)", at: CGPoint(x: margin, y: y), size: 10, weight: .semibold) + 6
for subscale in scale.subscales {
    let items = subscale.first == subscale.last ? "item \(subscale.first)" : "items \(subscale.first)–\(subscale.last)"
    text("\(subscale.title) (\(items))", at: CGPoint(x: margin, y: y), size: 9.5, width: 260)
    line(from: CGPoint(x: margin + 270, y: y + 11), to: CGPoint(x: margin + 330, y: y + 11))
    y += 16
}
text("Total (items 1–21)", at: CGPoint(x: margin, y: y), size: 9.5, weight: .semibold, width: 260)
line(from: CGPoint(x: margin + 270, y: y + 11), to: CGPoint(x: margin + 330, y: y + 11))

let footer = "Source: \(scale.source) This checklist describes symptoms; it is not a diagnosis. Printable copy from Tansy — klooder.github.io/tansy-site"
text(footer, at: CGPoint(x: margin, y: box.height - margin - 24), size: 7.5, color: grey, width: width)

NSGraphicsContext.restoreGraphicsState()
context.endPDFPage()
context.closePDF()
print(output.path)
