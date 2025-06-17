import Foundation
import Vision
import UIKit

class CardScannerService {
    
    // Common Pokemon card types for better recognition
    private let pokemonTypes = [
        "Normal", "Fire", "Water", "Grass", "Electric", "Ice", "Fighting", "Poison",
        "Ground", "Flying", "Psychic", "Bug", "Rock", "Ghost", "Dragon", "Dark",
        "Steel", "Fairy", "Colorless"
    ]
    
    // Common Pokemon card terms that might help identify cards
    private let pokemonTerms = [
        "HP", "Pokemon", "Trainer", "Energy", "Basic", "Stage", "EX", "GX", "V", "VMAX",
        "VSTAR", "Attack", "Weakness", "Resistance", "Retreat", "Evolves"
    ]
    
    /// Recognizes text in the provided image
    /// - Parameters:
    ///   - image: The image to recognize text from
    ///   - completion: Callback with recognized strings or empty array if failed
    func recognizeText(in image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        // Process the image to enhance text recognition
        let processedImage = preprocessImage(image)
        guard let processedCGImage = processedImage.cgImage else {
            completion([])
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: processedCGImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion([])
                return
            }
            
            // Get multiple candidates for better accuracy
            let recognizedStrings = observations.flatMap { observation in
                observation.topCandidates(3).compactMap { $0.string }
            }
            
            completion(recognizedStrings)
        }
        
        // Configure for accurate text recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform text recognition: \(error)")
            completion([])
        }
    }
    
    /// Preprocess image to enhance text recognition
    /// - Parameter image: Original image
    /// - Returns: Processed image
    private func preprocessImage(_ image: UIImage) -> UIImage {
        // Simple preprocessing for now - just ensure proper orientation
        if image.imageOrientation != .up {
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return normalizedImage ?? image
        }
        return image
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
        var potentialNames: [String] = []
        var confidenceScores: [String: Int] = [:]
        
        print("Recognized text: \(recognizedText)")
        
        // First pass: Look for Pokemon names (typically first few lines of text on a card)
        for text in recognizedText {
            // Clean up the text
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip very short texts
            if cleanText.count < 3 {
                continue
            }
            
            // Skip texts that are likely not Pokemon names
            if cleanText.contains("/") || 
               cleanText.contains("HP") ||
               cleanText.lowercased() == "pokemon" ||
               cleanText.lowercased() == "trainer" ||
               cleanText.lowercased() == "energy" {
                continue
            }
            
            // Check if text contains any Pokemon type
            let containsPokemonType = pokemonTypes.contains { cleanText.contains($0) }
            
            // Check if text contains any Pokemon term
            let containsPokemonTerm = pokemonTerms.contains { cleanText.contains($0) }
            
            // If text doesn't contain Pokemon types or terms, it might be a name
            if !containsPokemonType && !containsPokemonTerm && 
               cleanText.rangeOfCharacter(from: .uppercaseLetters) != nil {
                potentialNames.append(cleanText)
            }
        }
        
        // Second pass: Calculate confidence scores for each potential name
        for name in potentialNames {
            var score = 0
            
            // Longer names are more likely to be Pokemon names (but not too long)
            if name.count >= 4 && name.count <= 15 {
                score += 2
            }
            
            // Names that start with uppercase are more likely to be Pokemon names
            if name.first?.isUppercase == true {
                score += 2
            }
            
            // Names that don't contain digits are more likely to be Pokemon names
            if name.rangeOfCharacter(from: .decimalDigits) == nil {
                score += 1
            }
            
            // Store the score
            confidenceScores[name] = score
        }
        
        // Find the name with the highest confidence score
        if let bestName = confidenceScores.max(by: { $0.value < $1.value })?.key {
            cardInfo["name"] = bestName
        } else if let firstPotentialName = potentialNames.first {
            // Fallback to the first potential name if no clear winner
            cardInfo["name"] = firstPotentialName
        }
        
        // Look for card number (typically in format like "123/456")
        for text in recognizedText {
            if let range = text.range(of: #"\d+/\d+"#, options: .regularExpression) {
                cardInfo["number"] = String(text[range])
                break
            }
        }
        
        // Look for HP value
        for text in recognizedText {
            if let range = text.range(of: #"HP\s*\d+"#, options: [.regularExpression, .caseInsensitive]) {
                let hpText = String(text[range])
                // Extract just the digits from the HP text
                let hpDigits = hpText.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !hpDigits.isEmpty {
                    cardInfo["hp"] = hpDigits
                }
                break
            }
        }
        
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