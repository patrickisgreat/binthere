import UIKit
import Foundation

struct SuggestedItem: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var tags: [String]
    var isSelected: Bool = true
}

enum ImageAnalysisError: LocalizedError {
    case noAPIKey
    case imageConversionFailed
    case networkError(Error)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Add your Claude API key in Settings."
        case .imageConversionFailed:
            return "Failed to process the image."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let message):
            return "Failed to parse AI response: \(message)"
        }
    }
}

@Observable
final class ImageAnalysisService {
    var isAnalyzing = false
    var suggestedItems: [SuggestedItem] = []
    var error: ImageAnalysisError?

    private static let analysisPrompt = """
    Analyze this image of items in a storage bin or drawer. Identify each distinct item you can see. \
    Respond with ONLY a JSON array of objects, each with: "name" (short item name), \
    "description" (brief description including color, size, condition if visible), \
    "tags" (array of relevant category tags). \
    Example: [{"name": "Phillips Screwdriver", \
    "description": "Red-handled Phillips head screwdriver, medium size", \
    "tags": ["tools", "screwdriver"]}] \
    If you cannot identify items clearly, make your best guess. Return ONLY the JSON array, no other text.
    """

    private static let apiKeyKey = "claude_api_key"

    static var apiKey: String? {
        get { UserDefaults.standard.string(forKey: Self.apiKeyKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.apiKeyKey) }
    }

    func analyzeImage(_ image: UIImage) async {
        guard let apiKey = Self.apiKey, !apiKey.isEmpty else {
            error = .noAPIKey
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            error = .imageConversionFailed
            return
        }

        isAnalyzing = true
        error = nil
        suggestedItems = []
        defer { isAnalyzing = false }

        guard let request = buildRequest(apiKey: apiKey, base64Image: imageData.base64EncodedString()) else {
            error = .decodingError("Failed to create request")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            try parseResponse(data)
        } catch let analysisError as ImageAnalysisError {
            error = analysisError
        } catch {
            self.error = .networkError(error)
        }
    }

    private func buildRequest(apiKey: String, base64Image: String) -> URLRequest? {
        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image,
                            ],
                        ],
                        [
                            "type": "text",
                            "text": Self.analysisPrompt,
                        ],
                    ],
                ]
            ],
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let apiURL = URL(string: "https://api.anthropic.com/v1/messages") else {
            return nil
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = jsonData
        return request
    }

    private func parseResponse(_ data: Data) throws {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ImageAnalysisError.decodingError("Unexpected response format")
        }

        // Extract JSON array from the response text
        let jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let itemsData = jsonText.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: itemsData) as? [[String: Any]] else {
            throw ImageAnalysisError.decodingError("Could not parse items from response")
        }

        suggestedItems = items.compactMap { item in
            guard let name = item["name"] as? String else { return nil }
            let description = item["description"] as? String ?? ""
            let tags = item["tags"] as? [String] ?? []
            return SuggestedItem(name: name, description: description, tags: tags)
        }
    }

    // MARK: - Value Estimation

    struct ValueEstimate {
        let value: Double
        let reasoning: String
    }

    func estimateValue(
        for image: UIImage,
        itemName: String,
        itemDescription: String
    ) async -> ValueEstimate? {
        guard let apiKey = Self.apiKey, !apiKey.isEmpty else {
            error = .noAPIKey
            return nil
        }

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            error = .imageConversionFailed
            return nil
        }

        isAnalyzing = true
        error = nil
        defer { isAnalyzing = false }

        let prompt = """
        Estimate the current resale value of this item in US dollars.
        Item name: \(itemName)
        Description: \(itemDescription.isEmpty ? "(none)" : itemDescription)

        Consider the visible condition in the photo and typical market prices \
        for similar items. Respond with ONLY a JSON object with two keys: \
        "estimated_value" (a number in USD, no currency symbol) and \
        "reasoning" (a brief 1-2 sentence explanation of how you arrived at \
        the estimate). Example: {"estimated_value": 25.00, "reasoning": \
        "Used hand tool in good condition, similar items retail for $20-30."}
        """

        guard let request = buildValueRequest(
            apiKey: apiKey,
            base64Image: imageData.base64EncodedString(),
            prompt: prompt
        ) else {
            error = .decodingError("Failed to create request")
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try parseValueResponse(data)
        } catch let analysisError as ImageAnalysisError {
            error = analysisError
            return nil
        } catch {
            self.error = .networkError(error)
            return nil
        }
    }

    private func buildValueRequest(apiKey: String, base64Image: String, prompt: String) -> URLRequest? {
        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 512,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image,
                            ],
                        ],
                        [
                            "type": "text",
                            "text": prompt,
                        ],
                    ],
                ]
            ],
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let apiURL = URL(string: "https://api.anthropic.com/v1/messages") else {
            return nil
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = jsonData
        return request
    }

    private func parseValueResponse(_ data: Data) throws -> ValueEstimate {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ImageAnalysisError.decodingError("Unexpected response format")
        }

        let jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let valueData = jsonText.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: valueData) as? [String: Any],
              let estimatedValue = parsed["estimated_value"] as? Double else {
            throw ImageAnalysisError.decodingError("Could not parse value estimate")
        }

        let reasoning = parsed["reasoning"] as? String ?? ""
        return ValueEstimate(value: estimatedValue, reasoning: reasoning)
    }
}
