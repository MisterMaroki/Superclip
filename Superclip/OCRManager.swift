//
//  OCRManager.swift
//  Superclip
//

import AppKit
import Vision

enum OCRError: Error, LocalizedError {
    case noTextFound
    case recognitionFailed(Error)
    case invalidImage
    case screenCaptureFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text was found in the selected region. Make sure you're selecting an area with visible text."
        case .recognitionFailed(let error):
            return "Text recognition failed: \(error.localizedDescription)\n\nError type: \(type(of: error))"
        case .invalidImage:
            return "Could not process the captured image. The screen capture may have failed."
        case .screenCaptureFailed(let error):
            return "Screen capture failed: \(error.localizedDescription)\n\nError type: \(type(of: error))\n\nMake sure Superclip has Screen Recording permission."
        }
    }
}

class OCRManager {
    static let shared = OCRManager()

    private init() {}

    /// Recognizes text in the given image using Vision framework
    /// - Parameter image: The NSImage to process
    /// - Returns: Result containing the recognized text or an error
    func recognizeText(in image: NSImage) -> Result<String, OCRError> {
        // Convert NSImage to CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .failure(.invalidImage)
        }

        var recognizedText = ""
        var recognitionError: Error?

        // Create a semaphore for synchronous execution
        let semaphore = DispatchSemaphore(value: 0)

        // Create the text recognition request
        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }

            if let error = error {
                recognitionError = error
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            // Extract text from all observations, sorted by position (top to bottom, left to right)
            let sortedObservations = observations.sorted { first, second in
                // Sort by Y position (top to bottom), then by X position (left to right)
                if abs(first.boundingBox.minY - second.boundingBox.minY) < 0.01 {
                    return first.boundingBox.minX < second.boundingBox.minX
                }
                // Note: Vision uses bottom-left origin, so higher minY is higher on screen
                return first.boundingBox.minY > second.boundingBox.minY
            }

            let textLines = sortedObservations.compactMap { observation -> String? in
                // Get the top candidate for each observation
                observation.topCandidates(1).first?.string
            }

            recognizedText = textLines.joined(separator: "\n")
        }

        // Configure the request for accurate recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Create and perform the request handler
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return .failure(.recognitionFailed(error))
        }

        // Wait for completion
        semaphore.wait()

        // Check for errors
        if let error = recognitionError {
            return .failure(.recognitionFailed(error))
        }

        // Check if any text was found
        let trimmedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            return .failure(.noTextFound)
        }

        return .success(trimmedText)
    }

    /// Asynchronous version of recognizeText
    func recognizeTextAsync(in image: NSImage, completion: @escaping (Result<String, OCRError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.recognizeText(in: image)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
