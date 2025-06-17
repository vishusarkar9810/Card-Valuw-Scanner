import Foundation
import Vision
import UIKit

class CardScannerService {
    
    /// Recognizes text in the provided image
    /// - Parameters:
    ///   - image: The image to recognize text from
    ///   - completion: Callback with recognized strings or empty array if failed
    func recognizeText(in image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion([])
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            completion(recognizedStrings)
        }
        
        // Configure for accurate text recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform text recognition: \(error)")
            completion([])
        }
    }
    
    /// Async version of text recognition
    /// - Parameter image: The image to recognize text from
    /// - Returns: Array of recognized strings
    func recognizeText(in image: UIImage) async -> [String] {
        return await withCheckedContinuation { continuation in
            recognizeText(in: image) { strings in
                continuation.resume(returning: strings)
            }
        }
    }
    
    /// Extracts potential card information from recognized text
    /// - Parameter recognizedText: Array of recognized text strings
    /// - Returns: Dictionary with potential card name, number, and set
    func extractCardInfo(from recognizedText: [String]) -> [String: String] {
        var cardInfo: [String: String] = [:]
        
        // Look for potential card name (usually capitalized words)
        for text in recognizedText {
            // Card names are typically capitalized and don't contain numbers
            if text.rangeOfCharacter(from: .uppercaseLetters) != nil && 
               text.rangeOfCharacter(from: .decimalDigits) == nil &&
               text.count > 3 {
                cardInfo["name"] = text
                break
            }
        }
        
        // Look for card number (typically in format like "123/456")
        for text in recognizedText {
            if let range = text.range(of: #"\d+/\d+"#, options: .regularExpression) {
                cardInfo["number"] = String(text[range])
                break
            }
        }
        
        // Look for set information
        // This is more complex and might require specific pattern matching for Pokemon sets
        
        return cardInfo
    }
    
    /// Identifies a card from an image
    /// - Parameters:
    ///   - image: The card image
    ///   - completion: Callback with potential card info or empty dictionary if failed
    func identifyCard(from image: UIImage, completion: @escaping ([String: String]) -> Void) {
        recognizeText(in: image) { recognizedText in
            let cardInfo = self.extractCardInfo(from: recognizedText)
            completion(cardInfo)
        }
    }
    
    /// Async version of card identification
    /// - Parameter image: The card image
    /// - Returns: Dictionary with potential card info
    func identifyCard(from image: UIImage) async -> [String: String] {
        let recognizedText = await recognizeText(in: image)
        return extractCardInfo(from: recognizedText)
    }
} 