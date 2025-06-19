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
    
    // Common Pokemon names to help with name identification
    private let commonPokemonNames = [
        "Pikachu", "Charizard", "Bulbasaur", "Squirtle", "Eevee", "Mewtwo", "Gengar",
        "Lucario", "Gardevoir", "Rayquaza", "Snorlax", "Jigglypuff", "Gyarados", "Mew",
        "Dragonite", "Blastoise", "Venusaur", "Machamp", "Alakazam", "Tyranitar",
        "Umbreon", "Espeon", "Vaporeon", "Jolteon", "Flareon", "Glaceon", "Leafeon",
        "Sylveon", "Arcanine", "Lapras", "Zapdos", "Articuno", "Moltres", "Lugia",
        "Ho-Oh", "Celebi", "Suicune", "Entei", "Raikou", "Dialga", "Palkia", "Giratina"
    ]
    
    // Processing strategies for multi-stage recognition
    enum ProcessingStrategy {
        case normal      // Standard processing
        case enhanced    // Enhanced contrast and sharpening
        case brightened  // Increased brightness for dark cards
        case focused     // Focus on text regions only
        case edges       // Focus on card edges and borders
        case topSection  // Focus on the top section of the card (for card name)
        case hpSection   // Focus on the top-right corner where HP is typically located
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
                observation.topCandidates(10).compactMap { candidate in
                    // Store confidence with the string for better filtering
                    let confidence = candidate.confidence
                    let string = candidate.string
                    
                    // Only include strings with decent confidence
                    return confidence > 0.3 ? string : nil
                }
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
        case .topSection:
            // Optimize for card name at the top
            textRecognitionRequest.minimumTextHeight = 0.02
        case .hpSection:
            // Optimize for HP text which is usually larger
            textRecognitionRequest.minimumTextHeight = 0.03
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
    public func preprocessImage(_ image: UIImage, strategy: ProcessingStrategy = .normal) -> UIImage {
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
            
        case .topSection:
            // Crop to the top 20% of the card where the name usually is
            let extent = ciImage.extent
            let topSection = CGRect(x: extent.origin.x, 
                                   y: extent.origin.y + extent.height * 0.8, 
                                   width: extent.width, 
                                   height: extent.height * 0.2)
            processedImage = ciImage.cropped(to: topSection)
            processedImage = applyNormalization(to: processedImage)
            processedImage = applySharpen(to: processedImage, intensity: 2.0)
            processedImage = applyContrast(to: processedImage, amount: 1.5)
            
        case .hpSection:
            // Crop to the top-right corner where HP is typically located
            let extent = ciImage.extent
            let hpSection = CGRect(x: extent.origin.x + extent.width * 0.6, 
                                  y: extent.origin.y + extent.height * 0.8, 
                                  width: extent.width * 0.4, 
                                  height: extent.height * 0.2)
            processedImage = ciImage.cropped(to: hpSection)
            processedImage = applyNormalization(to: processedImage)
            processedImage = applySharpen(to: processedImage, intensity: 2.5)
            processedImage = applyContrast(to: processedImage, amount: 1.7)
            // Higher contrast for HP numbers which are often bold and red
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
        
        // Add top section strategy specifically for card name detection
        let topSectionResults = await withCheckedContinuation { continuation in
            recognizeText(in: image, strategy: .topSection) { strings in
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
        
        // Give priority to top section results as they're likely to contain the card name
        for string in topSectionResults {
            if !combinedResults.contains(string) {
                // Insert at the beginning to give higher priority
                combinedResults.insert(string, at: 0)
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
        var potentialHPs: [(hp: String, score: Int)] = []
        
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
            
            // Look for HP value - multiple formats and common OCR errors
            extractHPValue(from: cleanText, potentialHPs: &potentialHPs)
            
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
        
        // Find the HP with the highest confidence score
        if let bestHP = potentialHPs.max(by: { $0.score < $1.score })?.hp {
            cardInfo["hp"] = bestHP
        }
        
        return cardInfo
    }
    
    /// Extract HP value from text with multiple pattern matching for better accuracy
    /// - Parameters:
    ///   - text: The text to extract HP from
    ///   - potentialHPs: Array to store potential HP values with confidence scores
    private func extractHPValue(from text: String, potentialHPs: inout [(hp: String, score: Int)]) {
        // Common patterns for HP values
        let patterns = [
            #"HP\s*(\d+)"#,             // Standard format: "HP 120"
            #"(\d+)\s*HP"#,             // Reversed format: "120 HP"
            #"HP[\s:-]*(\d+)"#,         // With various separators: "HP: 120", "HP-120"
            #"(\d+)[\s:-]*HP"#,         // Reversed with separators: "120: HP", "120-HP"
            #"[HM]P\s*(\d+)"#,          // Common OCR error: "MP 120" (H read as M)
            #"(\d+)\s*[HM]P"#,          // Common OCR error reversed: "120 MP"
            #"(\d+)\s*[Hh][Pp]"#,       // Mixed case: "120 Hp"
            #"[Hh][Pp]\s*(\d+)"#,       // Mixed case: "Hp 120"
            #"H[Pp]\s*(\d+)"#,          // Mixed case: "Hp 120"
            #"(\d+)\s*H[Pp]"#           // Mixed case: "120 Hp"
        ]
        
        // Try all patterns
        for (index, pattern) in patterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    // Extract the HP value (the first capture group)
                    if let matchRange = Range(match.range(at: 1), in: text) {
                        let hpValue = String(text[matchRange])
                        
                        // Score based on pattern reliability (earlier patterns are more reliable)
                        let baseScore = 5 - min(index, 4) // 5 for first pattern, decreasing for later ones
                        
                        // Additional scoring factors
                        var score = baseScore
                        
                        // Common HP values get higher scores
                        let commonHPs = ["30", "40", "50", "60", "70", "80", "90", "100", "110", "120", 
                                        "130", "140", "150", "160", "170", "180", "190", "200", "210", 
                                        "220", "230", "240", "250", "260", "270", "280", "290", "300", 
                                        "310", "320", "330", "340"]
                        
                        if commonHPs.contains(hpValue) {
                            score += 2
                        }
                        
                        // HP values that are multiples of 10 are more common
                        if Int(hpValue)?.isMultiple(of: 10) == true {
                            score += 1
                        }
                        
                        // Very high HP values are less common and might be errors
                        if let intValue = Int(hpValue), intValue > 350 {
                            score -= 2
                        }
                        
                        // Very low HP values are also less common
                        if let intValue = Int(hpValue), intValue < 30 {
                            score -= 1
                        }
                        
                        // Bonus for HP values found in the same text as Pokemon names or terms
                        for pokemonName in commonPokemonNames {
                            if text.contains(pokemonName) {
                                score += 3 // Higher confidence if found with a Pokemon name
                                break
                            }
                        }
                        
                        potentialHPs.append((hpValue, score))
                    }
                }
            }
        }
        
        // Special case: sometimes HP is just a number by itself in the top right
        // But we need to be careful not to confuse with card numbers
        if text.count <= 4 && text.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
            // If it's just digits and reasonable length for HP
            let hpValue = text
            
            if let intValue = Int(hpValue), intValue >= 30 && intValue <= 340 {
                // Likely an HP value if in common range
                var score = 1
                
                // Common HP values get higher scores
                if intValue.isMultiple(of: 10) {
                    score += 1
                }
                
                // Common HP ranges
                if intValue >= 60 && intValue <= 250 {
                    score += 1
                }
                
                potentialHPs.append((hpValue, score))
            }
        }
    }
    
    /// Evaluate if text could be a Pokemon card name and score its likelihood
    private func evaluatePotentialCardName(_ text: String, potentialNames: inout [(name: String, score: Int)]) {
        // Skip texts that are likely not Pokemon names
        if text.contains("/") || 
           text.lowercased() == "pokemon" ||
           text.lowercased() == "trainer" ||
           text.lowercased() == "energy" {
            return
        }
        
        // Special handling for text containing HP - extract the name part
        if text.lowercased().contains("hp") {
            // Try to extract a potential name before the HP
            let parts = text.components(separatedBy: CharacterSet(charactersIn: "HP hHpP0123456789"))
            let potentialNamePart = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if potentialNamePart.count >= 4 {
                // This might be a name followed by HP
                var score = 2 // Base score for name+HP pattern
                
                // Check if it matches known Pokemon names
                for pokemonName in commonPokemonNames {
                    if potentialNamePart.contains(pokemonName) {
                        score += 5 // Very high confidence if it contains a known Pokemon name
                        potentialNames.append((potentialNamePart, score))
                        return
                    }
                }
                
                // If it starts with uppercase, it's more likely a name
                if potentialNamePart.first?.isUppercase == true {
                    score += 1
                    potentialNames.append((potentialNamePart, score))
                }
                
                return
            }
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
            
            // Check if the text contains a known Pokemon name
            for pokemonName in commonPokemonNames {
                if text.contains(pokemonName) {
                    score += 5 // Very high confidence if it contains a known Pokemon name
                    break
                }
            }
            
            // Check if the text looks like a complete Pokemon name (e.g., "Pikachu V")
            for pokemonName in commonPokemonNames {
                if text == pokemonName {
                    score += 8 // Extremely high confidence for exact match
                    break
                }
                
                // Common patterns like "Pikachu V", "Charizard GX"
                let patterns = [" V", " GX", " EX", " VMAX", " VSTAR"]
                for pattern in patterns {
                    if text == pokemonName + pattern {
                        score += 10 // Highest confidence for exact Pokemon name with variant
                        break
                    }
                }
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
    
    /// Extract both name and HP from the same text string for higher accuracy
    /// - Parameters:
    ///   - recognizedText: Array of recognized text strings
    ///   - potentialNameHP: Array to store potential name+HP pairs with confidence scores
    private func extractNameAndHP(from recognizedText: [String], potentialNameHP: inout [(name: String, hp: String, score: Int)]) {
        // Common patterns for name+HP combinations
        let patterns = [
            #"([A-Z][a-zA-Z\s]+)\s+HP\s*(\d+)"#,           // "Pikachu HP 120"
            #"([A-Z][a-zA-Z\s]+)\s+(\d+)\s*HP"#,           // "Pikachu 120 HP"
            #"([A-Z][a-zA-Z\s]+)\s+[HM]P\s*(\d+)"#,        // Common OCR error
            #"([A-Z][a-zA-Z\s]+)\s+(\d+)\s*[HM]P"#         // Common OCR error reversed
        ]
        
        for text in recognizedText {
            // Skip very short texts
            if text.count < 8 { // Name + HP needs some length
                continue
            }
            
            // Try all patterns
            for (_, pattern) in patterns.enumerated() {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let range = NSRange(text.startIndex..<text.endIndex, in: text)
                    if let match = regex.firstMatch(in: text, range: range) {
                        // Need at least 2 capture groups (name and HP)
                        guard match.numberOfRanges >= 3,
                              let nameRange = Range(match.range(at: 1), in: text),
                              let hpRange = Range(match.range(at: 2), in: text) else {
                            continue
                        }
                        
                        let name = String(text[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let hp = String(text[hpRange])
                        
                        // Skip if name is too short or HP is invalid
                        if name.count < 3 || Int(hp) == nil {
                            continue
                        }
                        
                        // Base score - finding both name and HP together is high confidence
                        var score = 5
                        
                        // Check if name matches known Pokemon
                        for pokemonName in commonPokemonNames {
                            if name.contains(pokemonName) {
                                score += 5 // Very high confidence if it contains a known Pokemon name
                                break
                            }
                        }
                        
                        // Check if HP is a common value
                        if let intHP = Int(hp), intHP >= 30 && intHP <= 340 && intHP.isMultiple(of: 10) {
                            score += 2
                        }
                        
                        potentialNameHP.append((name, hp, score))
                    }
                }
            }
        }
    }
    
    /// Identifies a card from an image using multiple strategies
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
        
        let topSectionResults = await withCheckedContinuation { continuation in
            recognizeText(in: croppedImage, strategy: .topSection) { strings in
                continuation.resume(returning: strings)
            }
        }
        
        // Add HP section strategy for better HP recognition
        let hpSectionResults = await withCheckedContinuation { continuation in
            recognizeText(in: croppedImage, strategy: .hpSection) { strings in
                continuation.resume(returning: strings)
            }
        }
        
        // Combine all results with priority to top section and HP section results
        var combinedResults: [String] = []
        
        // First add top section results (likely to contain name)
        combinedResults.append(contentsOf: topSectionResults)
        
        // Then add HP section results
        for string in hpSectionResults {
            if !combinedResults.contains(string) {
                combinedResults.append(string)
            }
        }
        
        // Then add normal and enhanced results
        for string in normalResults {
            if !combinedResults.contains(string) {
                combinedResults.append(string)
            }
        }
        
        for string in enhancedResults {
            if !combinedResults.contains(string) {
                combinedResults.append(string)
            }
        }
        
        // If we successfully cropped the card, also try brightened strategy
        if croppedImage.size != image.size {
            let brightenedResults = await withCheckedContinuation { continuation in
                recognizeText(in: croppedImage, strategy: .brightened) { strings in
                    continuation.resume(returning: strings)
                }
            }
            
            for string in brightenedResults {
                if !combinedResults.contains(string) {
                    combinedResults.append(string)
                }
            }
        }
        
        // Extract card info with emphasis on name+HP combinations
        var cardInfo = extractCardInfo(from: combinedResults)
        
        // Look specifically for name+HP combinations for higher accuracy
        var potentialNameHP: [(name: String, hp: String, score: Int)] = []
        extractNameAndHP(from: combinedResults, potentialNameHP: &potentialNameHP)
        
        // If we found name+HP combinations, prioritize them over individual extractions
        if let bestNameHP = potentialNameHP.max(by: { $0.score < $1.score }) {
            cardInfo["name"] = bestNameHP.name
            cardInfo["hp"] = bestNameHP.hp
            cardInfo["nameHPConfidence"] = String(bestNameHP.score) // Store confidence for debugging
        }
        
        return cardInfo
    }
}
