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
    
    // Processing strategies for multi-stage recognition
    enum ProcessingStrategy {
        case normal      // Standard processing
        case enhanced    // Enhanced contrast and sharpening
        case brightened  // Increased brightness for dark cards
        case focused     // Focus on text regions only
        case edges       // Focus on card edges and borders
    }
    
    // MARK: - Card Detection and Recognition
    
    /// Recognizes text in the provided image with multiple processing strategies
    /// - Parameters:
    ///   - image: The image to recognize text from
    ///   - strategy: The processing strategy to use
    ///   - completion: Callback with recognized strings or empty array if failed
    func recognizeText(in image: UIImage, strategy: ProcessingStrategy = .normal, completion: @escaping ([String]) -> Void) {
        guard let _ = image.cgImage else {
            completion([])
            return
        }
        
        // Process the image based on the selected strategy
        let processedImage = preprocessImage(image, strategy: strategy)
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
                // Get more candidates for better accuracy
                observation.topCandidates(5).compactMap { $0.string }
            }
            
            // Filter and process the results
            let filteredStrings = recognizedStrings.filter { str in
                let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.count >= 2
            }
            
            // Sort strings by length and confidence (longer strings often contain more useful information)
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
        
        // Customize recognition parameters based on strategy
        switch strategy {
        case .focused:
            // Optimize for text regions
            textRecognitionRequest.minimumTextHeight = 0.01 // Detect smaller text
        case .edges:
            // Optimize for card numbers and set symbols
            textRecognitionRequest.minimumTextHeight = 0.02
        default:
            textRecognitionRequest.minimumTextHeight = 0.015
        }
        
        do {
            // Perform the request
            try requestHandler.perform([textRecognitionRequest])
        } catch {
            print("Failed to perform text recognition: \(error)")
            completion([])
        }
    }
    
    /// Preprocess image to enhance text recognition based on strategy
    /// - Parameters:
    ///   - image: Original image
    ///   - strategy: Processing strategy to apply
    /// - Returns: Processed image
    private func preprocessImage(_ image: UIImage, strategy: ProcessingStrategy = .normal) -> UIImage {
        // Create a CIImage from the UIImage
        guard let ciImage = CIImage(image: image) else {
            return image
        }
        
        // Create a context to perform CIFilter operations
        let context = CIContext(options: nil)
        
        // Apply different processing based on strategy
        var processedImage = ciImage
        
        switch strategy {
        case .normal:
            // Standard processing
            processedImage = applyNormalization(to: ciImage)
            processedImage = applySharpen(to: processedImage)
            processedImage = applyContrast(to: processedImage)
            
        case .enhanced:
            // Enhanced processing for better text recognition
            processedImage = applyNormalization(to: ciImage)
            processedImage = applySharpen(to: processedImage, intensity: 1.5)
            processedImage = applyContrast(to: processedImage, amount: 1.3)
            
        case .brightened:
            // Brighten dark images
            processedImage = applyNormalization(to: ciImage)
            processedImage = applyBrightness(to: processedImage, amount: 0.2)
            processedImage = applySharpen(to: processedImage)
            processedImage = applyContrast(to: processedImage)
            
        case .focused:
            // Focus on text regions
            processedImage = applyNormalization(to: ciImage)
            processedImage = applySharpen(to: processedImage, intensity: 2.0)
            processedImage = applyContrast(to: processedImage, amount: 1.5)
            processedImage = applyNoiseReduction(to: processedImage)
            
        case .edges:
            // Enhance edges for better card detection
            processedImage = applyEdgeDetection(to: ciImage)
        }
        
        // Convert back to UIImage
        if let cgImage = context.createCGImage(processedImage, from: processedImage.extent) {
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
        
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(1.1, forKey: "inputContrast") // Slightly increase contrast
        filter.setValue(0.0, forKey: "inputBrightness") // Keep brightness neutral
        filter.setValue(1.0, forKey: "inputSaturation") // Keep saturation neutral
        
        return filter.outputImage ?? image
    }
    
    /// Apply sharpening filter to enhance edges
    private func applySharpen(to image: CIImage, intensity: Float = 1.0) -> CIImage {
        guard let filter = CIFilter(name: "CIUnsharpMask") else {
            return image
        }
        
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(0.8, forKey: "inputRadius") // Radius of effect
        filter.setValue(intensity, forKey: "inputIntensity") // Intensity of effect
        
        return filter.outputImage ?? image
    }
    
    /// Apply contrast adjustment
    private func applyContrast(to image: CIImage, amount: Float = 1.1) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return image
        }
        
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(amount, forKey: "inputContrast") // Increase contrast
        
        return filter.outputImage ?? image
    }
    
    /// Apply brightness adjustment
    private func applyBrightness(to image: CIImage, amount: Float = 0.1) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return image
        }
        
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(amount, forKey: "inputBrightness") // Adjust brightness
        
        return filter.outputImage ?? image
    }
    
    /// Apply noise reduction to improve text recognition
    private func applyNoiseReduction(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CINoiseReduction") else {
            return image
        }
        
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(0.02, forKey: "inputNoiseLevel")
        filter.setValue(0.40, forKey: "inputSharpness")
        
        return filter.outputImage ?? image
    }
    
    /// Apply edge detection to find card boundaries
    private func applyEdgeDetection(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIEdges") else {
            return image
        }
        
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(2.0, forKey: "inputIntensity")
        
        return filter.outputImage ?? image
    }
    
    /// Detect card edges in the image
    /// - Parameter image: The image to detect card edges in
    /// - Returns: Cropped image containing just the card, or original if detection fails
    func detectAndCropCard(_ image: UIImage) -> UIImage {
        // First try to detect rectangular shapes that might be cards
        let edgeProcessedImage = preprocessImage(image, strategy: .edges)
        
        // For now, we'll implement a basic version that looks for rectangular shapes
        // In a complete implementation, we'd use VNDetectRectanglesRequest to find the card
        
        // Create a CIDetector for rectangles
        guard let detector = CIDetector(ofType: CIDetectorTypeRectangle, 
                                       context: nil, 
                                       options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else {
            return image
        }
        
        guard let ciImage = CIImage(image: edgeProcessedImage) else {
            return image
        }
        
        // Detect rectangles
        let features = detector.features(in: ciImage)
        
        // Find the largest rectangle that might be our card
        if let cardFeature = features.first as? CIRectangleFeature {
            // Create a perspective correction transform
            let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")
            perspectiveCorrection?.setValue(ciImage, forKey: "inputImage")
            perspectiveCorrection?.setValue(CIVector(cgPoint: cardFeature.topLeft), forKey: "inputTopLeft")
            perspectiveCorrection?.setValue(CIVector(cgPoint: cardFeature.topRight), forKey: "inputTopRight")
            perspectiveCorrection?.setValue(CIVector(cgPoint: cardFeature.bottomRight), forKey: "inputBottomRight")
            perspectiveCorrection?.setValue(CIVector(cgPoint: cardFeature.bottomLeft), forKey: "inputBottomLeft")
            
            if let output = perspectiveCorrection?.outputImage {
                let context = CIContext(options: nil)
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        
        // If we couldn't detect a card, return the original image
        return image
    }
    
    /// Async version of text recognition with multiple strategies
    /// - Parameter image: The image to recognize text from
    /// - Returns: Array of recognized strings
    func recognizeText(in image: UIImage) async -> [String] {
        // Try multiple processing strategies and combine results for better accuracy
        let normalResults = await withCheckedContinuation { continuation in
            recognizeText(in: image, strategy: .normal) { strings in
                continuation.resume(returning: strings)
            }
        }
        
        let enhancedResults = await withCheckedContinuation { continuation in
            recognizeText(in: image, strategy: .enhanced) { strings in
                continuation.resume(returning: strings)
            }
        }
        
        // Combine and deduplicate results
        var combinedResults = normalResults
        for string in enhancedResults {
            if !combinedResults.contains(string) {
                combinedResults.append(string)
            }
        }
        
        return combinedResults
    }
    
    /// Extracts potential card information from recognized text
    /// - Parameter recognizedText: Array of recognized text strings
    /// - Returns: Dictionary with potential card name, number, and set
    func extractCardInfo(from recognizedText: [String]) -> [String: String] {
        var cardInfo: [String: String] = [:]
        var potentialNames: [(name: String, score: Int)] = []
        var potentialSets: [(set: String, score: Int)] = []
        var potentialNumbers: [(number: String, score: Int)] = []
        
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
                let number = String(cleanText[range])
                potentialNumbers.append((number, 3)) // High confidence for standard format
                
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
        
        // Find the number with the highest confidence score
        if let bestNumber = potentialNumbers.max(by: { $0.score < $1.score })?.number {
            cardInfo["number"] = bestNumber
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
            
            // Common Pokemon name patterns like "Pikachu V" or "Charizard GX"
            if text.contains(" V") || text.contains(" GX") || text.contains(" EX") || 
               text.contains(" VMAX") || text.contains(" VSTAR") {
                score += 3
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
    
    /// Identifies a card from an image using multiple strategies
    /// - Parameters:
    ///   - image: The card image
    ///   - completion: Callback with potential card info or empty dictionary if failed
    func identifyCard(from image: UIImage, completion: @escaping ([String: String]) -> Void) {
        // First try to detect and crop the card
        let croppedImage = detectAndCropCard(image)
        
        // Then recognize text from the cropped image
        recognizeText(in: croppedImage) { recognizedText in
            let cardInfo = self.extractCardInfo(from: recognizedText)
            completion(cardInfo)
        }
    }
    
    /// Async version of card identification with multiple processing strategies
    /// - Parameter image: The card image
    /// - Returns: Dictionary with potential card info
    func identifyCard(from image: UIImage) async -> [String: String] {
        // First try to detect and crop the card
        let croppedImage = detectAndCropCard(image)
        
        // Try multiple processing strategies for better results
        let normalResults = await withCheckedContinuation { continuation in
            recognizeText(in: croppedImage, strategy: .normal) { strings in
                continuation.resume(returning: strings)
            }
        }
        
        let enhancedResults = await withCheckedContinuation { continuation in
            recognizeText(in: croppedImage, strategy: .enhanced) { strings in
                continuation.resume(returning: strings)
            }
        }
        
        if croppedImage.size != image.size {
            // If we successfully cropped the card, also try brightened strategy
            let brightenedResults = await withCheckedContinuation { continuation in
                recognizeText(in: croppedImage, strategy: .brightened) { strings in
                    continuation.resume(returning: strings)
                }
            }
            
            // Combine all results
            var combinedResults = normalResults
            for string in enhancedResults {
                if !combinedResults.contains(string) {
                    combinedResults.append(string)
                }
            }
            
            for string in brightenedResults {
                if !combinedResults.contains(string) {
                    combinedResults.append(string)
                }
            }
            
            return extractCardInfo(from: combinedResults)
        } else {
            // If cropping failed, just use normal and enhanced
            var combinedResults = normalResults
            for string in enhancedResults {
                if !combinedResults.contains(string) {
                    combinedResults.append(string)
                }
            }
            
            return extractCardInfo(from: combinedResults)
        }
    }
} 