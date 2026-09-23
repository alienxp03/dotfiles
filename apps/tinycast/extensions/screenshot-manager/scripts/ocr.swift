import CoreGraphics
import Darwin
import Foundation
import Vision

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else {
    fail("Usage: screenshot-ocr <image>")
}

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

 do {
    let handler = VNImageRequestHandler(url: imageURL, options: [:])
    try handler.perform([request])

    let observations = request.results ?? []
    let text = observations
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    FileHandle.standardOutput.write(Data(text.utf8))
} catch {
    fail(error.localizedDescription)
}
