import AppKit
import Foundation
import Vision

actor OCRService {
    static let shared = OCRService()

    struct Result {
        let ok: Bool
        let text: String
    }

    /// Recognize text from an image file path using macOS Vision.
    /// - Returns: recognized plain text (may be empty). Caller is responsible for truncation.
    func recognizeText(filePath: String) async -> Result {
        guard FileManager.default.fileExists(atPath: filePath) else {
            return Result(ok: false, text: "")
        }

        guard let nsImage = NSImage(contentsOfFile: filePath) else {
            return Result(ok: false, text: "")
        }

        var rect = CGRect(origin: .zero, size: nsImage.size)
        guard let cg = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            return Result(ok: false, text: "")
        }

        return await withCheckedContinuation { cont in
            let req = VNRecognizeTextRequest { request, error in
                if error != nil {
                    cont.resume(returning: Result(ok: false, text: ""))
                    return
                }

                let obs = (request.results as? [VNRecognizedTextObservation]) ?? []
                var lines: [String] = []
                lines.reserveCapacity(obs.count)

                for o in obs {
                    guard let best = o.topCandidates(1).first else { continue }
                    let s = best.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !s.isEmpty {
                        lines.append(s)
                    }
                }

                cont.resume(returning: Result(ok: true, text: lines.joined(separator: "\n")))
            }

            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            req.minimumTextHeight = 0.02
            // Languages: Chinese + English + Japanese
            req.recognitionLanguages = ["zh-Hans", "en-US", "ja-JP"]

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([req])
            } catch {
                cont.resume(returning: Result(ok: false, text: ""))
            }
        }
    }
}
