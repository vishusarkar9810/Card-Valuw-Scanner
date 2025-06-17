import Foundation
import Vision
import UIKit
import CoreImage

class CardScannerService {
    
    // Common Pokemon card types for better recognition
    private let pokemonTypes = [
        "Normal", "Fire", "Water", "Grass", "Electric", "Ice", "Fighting", "Poison",
        "Ground", "Flying", "Psychic", "Bug", "Rock", "Ghost", "Dragon", "Dark",
        "Steel", "Fairy", "Colorless", "Lightning", "Metal"
    ]
    
    // Common Pokemon card terms that might help identify cards
    private let pokemonTerms = [
        "HP", "Pokemon", "Trainer", "Energy", "Basic", "Stage", "EX", "GX", "V", "VMAX",
        "VSTAR", "Attack", "Weakness", "Resistance", "Retreat", "Evolves", "Item",
        "Supporter", "Stadium", "Tool", "Special"
    ]
    
    // Common set abbreviations to help with set identification
    private let setAbbreviations = [
        "SV", "SWSH", "SM", "XY", "BW", "DP", "PL", "RG", "EX", "NEO", "GYM", "TR", 
        "BS", "POGO", "CRE", "VIV", "DAA", "RCL", "SSH", "CPA", "HIF", "UNB", "TEU", 
        "LOT", "CES", "FLI", "UPR", "CIN", "SUM"
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
        
        // Create a separate function to handle the request completion
        func handleRecognizedText(request: VNRequest, error: Error?) {
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion([])
                return
            }
            
            // Get multiple candidates for better accuracy
            let recognizedStrings = observations.flatMap { observation in
                observation.topCandidates(3).compactMap { $0.string }
            }
            
            // Filter and process the results
            let filteredStrings = recognizedStrings.filter { str in
                let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.count >= 2
            }
            
            // Sort strings by length (longer strings often contain more useful information)
            let sortedStrings = filteredStrings.sorted { $0.count > $1.count }
            
            completion(sortedStrings)
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: processedCGImage, options: [:])
        
        // Create the text recognition request
        let textRecognitionRequest = VNRecognizeTextRequest(completionHandler: handleRecognizedText)
        
        // Configure for accurate text recognition
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
        textRecognitionRequest.recognitionLanguages = ["en-US"]
        
        do {
            // Perform the request
            try requestHandler.perform([textRecognitionRequest])
        } catch {
            print("Failed to perform text recognition: \(error)")
            completion([])
        }
    }
    
    /// Preprocess image to enhance text recognition
    /// - Parameter image: Original image
    /// - Returns: Processed image
    private func preprocessImage(_ image: UIImage) -> UIImage {
        // Create a CIImage from the UIImage
        guard let ciImage = CIImage(image: image) else {
            return image
        }
        
        // Create a context to perform CIFilter operations
        let context = CIContext(options: nil)
        
        // Apply a series of filters to enhance text visibility
        
        // 1. Normalize the image to improve contrast
        let normalizedImage = applyNormalization(to: ciImage)
        
        // 2. Apply unsharp mask to enhance edges (text boundaries)
        let sharpenedImage = applySharpen(to: normalizedImage)
        
        // 3. Apply contrast adjustment
        let contrastedImage = applyContrast(to: sharpenedImage)
        
        // Convert back to UIImage
        if let cgImage = context.createCGImage(contrastedImage, from: contrastedImage.extent) {
            // Ensure proper orientation
            let processedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            
            // If the image is not in the up orientation, normalize it
            if processedImage.imageOrientation != .up {
                UIGraphicsBeginImageContextWithOptions(processedImage.size, false, processedImage.scale)
                processedImage.draw(in: CGRect(origin: .zero, size: processedImage.size))
                let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return normalizedImage ?? processedImage
            }
            
            return processedImage
        }
        
        return image
    }
    
    /// Apply normalization filter to enhance image
    private func applyNormalization(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.1, forKey: kCIInputContrastKey) // Slightly increase contrast
        filter.setValue(0.0, forKey: kCIInputBrightnessKey) // Keep brightness neutral
        filter.setValue(1.0, forKey: kCIInputSaturationKey) // Keep saturation neutral
        
        return filter.outputImage ?? image
    }
    
    /// Apply sharpening filter to enhance edges
    private func applySharpen(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIUnsharpMask") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.8, forKey: kCIInputRadiusKey) // Radius of effect
        filter.setValue(1.0, forKey: kCIInputIntensityKey) // Intensity of effect
        
        return filter.outputImage ?? image
    }
    
    /// Apply contrast adjustment
    private func applyContrast(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.1, forKey: kCIInputContrastKey) // Increase contrast
        
        return filter.outputImage ?? image
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
        var potentialNames: [(name: String, score: Int)] = []
        var potentialSets: [(set: String, score: Int)] = []
        
        print("Recognized text: \(recognizedText)")
        
        // First pass: Look for Pokemon names and other card information
        for text in recognizedText {
            // Clean up the text
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip very short texts
            if cleanText.count < 3 {
                continue
            }
            
            // Look for card number (typically in format like "123/456")
            if let range = cleanText.range(of: #"\d+/\d+"#, options: .regularExpression) {
                cardInfo["number"] = String(cleanText[range])
                
                // Try to extract set information from the same string
                // Card numbers often appear with set abbreviations like "SV01 123/456"
                for abbr in setAbbreviations {
                    if cleanText.contains(abbr) {
                        potentialSets.append((abbr, 3)) // High confidence if found with card number
                    }
                }
            }
            
            // Look for HP value
            if let range = cleanText.range(of: #"HP\s*\d+"#, options: [.regularExpression, .caseInsensitive]) {
                let hpText = String(cleanText[range])
                // Extract just the digits from the HP text
                let hpDigits = hpText.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !hpDigits.isEmpty {
                    cardInfo["hp"] = hpDigits
                }
            }
            
            // Look for potential card names
            evaluatePotentialCardName(cleanText, potentialNames: &potentialNames)
            
            // Look for set information
            evaluatePotentialSetInfo(cleanText, potentialSets: &potentialSets)
        }
        
        // Find the name with the highest confidence score
        if let bestName = potentialNames.max(by: { $0.score < $1.score })?.name {
            cardInfo["name"] = bestName
        }
        
        // Find the set with the highest confidence score
        if let bestSet = potentialSets.max(by: { $0.score < $1.score })?.set {
            cardInfo["set"] = bestSet
        }
        
        return cardInfo
    }
    
    /// Evaluate if text could be a Pokemon card name and score its likelihood
    private func evaluatePotentialCardName(_ text: String, potentialNames: inout [(name: String, score: Int)]) {
        // Skip texts that are likely not Pokemon names
        if text.contains("/") || 
           text.lowercased().contains("hp") ||
           text.lowercased() == "pokemon" ||
           text.lowercased() == "trainer" ||
           text.lowercased() == "energy" {
            return
        }
        
        // Check if text contains any Pokemon type or term
        let containsPokemonType = pokemonTypes.contains { text.contains($0) }
        let containsPokemonTerm = pokemonTerms.contains { text.contains($0) }
        
        // If text doesn't contain Pokemon types or terms, it might be a name
        if !containsPokemonType && !containsPokemonTerm && 
           text.rangeOfCharacter(from: .uppercaseLetters) != nil {
            
            var score = 0
            
            // Longer names are more likely to be Pokemon names (but not too long)
            if text.count >= 4 && text.count <= 20 {
                score += 2
            }
            
            // Names that start with uppercase are more likely to be Pokemon names
            if text.first?.isUppercase == true {
                score += 2
            }
            
            // Names that don't contain digits are more likely to be Pokemon names
            if text.rangeOfCharacter(from: .decimalDigits) == nil {
                score += 1
            }
            
            // Names that are all caps are less likely to be Pokemon names
            if text == text.uppercased() && text.count > 3 {
                score -= 1
            }
            
            // Names with spaces are more likely to be full Pokemon names
            if text.contains(" ") {
                score += 1
            }
            
            // Add to potential names if score is positive
            if score > 0 {
                potentialNames.append((text, score))
            }
        }
    }
    
    /// Evaluate if text could contain set information
    private func evaluatePotentialSetInfo(_ text: String, potentialSets: inout [(set: String, score: Int)]) {
        // Look for set abbreviations
        for abbr in setAbbreviations {
            if text.contains(abbr) {
                var score = 1
                
                // If it's a standalone abbreviation, higher confidence
                if text.trimmingCharacters(in: .whitespacesAndNewlines) == abbr {
                    score += 2
                }
                
                // If it's followed by numbers, higher confidence
                let pattern = "\(abbr)\\s*\\d+"
                if let _ = text.range(of: pattern, options: .regularExpression) {
                    score += 2
                }
                
                potentialSets.append((abbr, score))
            }
        }
        
        // Look for common set names
        let commonSetNames = ["Sword & Shield", "Brilliant Stars", "Astral Radiance", 
                             "Lost Origin", "Silver Tempest", "Crown Zenith", 
                             "Scarlet & Violet", "Paldea Evolved", "Obsidian Flames"]
        
        for setName in commonSetNames {
            if text.contains(setName) {
                potentialSets.append((setName, 3)) // High confidence for full set names
            }
        }
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