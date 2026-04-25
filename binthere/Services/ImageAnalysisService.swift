import UIKit
import Foundation

struct SuggestedItem: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var tags: [String]
    var color: String = ""
    var value: Double?
    var isSelected: Bool = true

    var tagsText: String {
        get { tags.joined(separator: ", ") }
        set {
            tags = newValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
    }
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

enum AIProvider: String, CaseIterable, Identifiable {
    case anthropic
    case openai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Claude (Anthropic)"
        case .openai: return "GPT-4o (OpenAI)"
        }
    }

    /// The provider currently in use for this household. Falls back to
    /// `.anthropic` when no household is loaded or the column is unset.
    static var current: Self {
        let raw = ImageAnalysisService.currentHousehold?.aiProvider ?? "anthropic"
        return Self(rawValue: raw) ?? .anthropic
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

    static var currentUserId: String?
    static var currentHousehold: Household?

    /// Legacy per-user UserDefaults keys (read-only, used only for the
    /// one-time migration to household-scoped storage).
    private static let legacyGlobalApiKey = "claude_api_key"
    private static let legacyGlobalProviderKey = "ai_provider"
    private static func legacyUserApiKey(_ userId: String) -> String { "claude_api_key_\(userId)" }
    private static func legacyUserProviderKey(_ userId: String) -> String { "ai_provider_\(userId)" }

    static func setCurrentUser(_ userId: String?) {
        currentUserId = userId
    }

    static func setCurrentHousehold(_ household: Household?) {
        currentHousehold = household
    }

    /// Reads the shared household API key. Returns nil when no household
    /// is loaded or the owner has not yet set one.
    static var apiKey: String? {
        currentHousehold?.apiKey
    }

    /// Returns a legacy API key from UserDefaults if one exists, for the
    /// one-time migration when a household is loaded for the first time.
    /// Checks the current-user-scoped key first, then the global fallback.
    static func legacyLocalAPIKey() -> (apiKey: String, provider: String)? {
        let defaults = UserDefaults.standard
        let apiKey: String?
        let provider: String?

        if let userId = currentUserId {
            apiKey = defaults.string(forKey: legacyUserApiKey(userId))
                ?? defaults.string(forKey: legacyGlobalApiKey)
            provider = defaults.string(forKey: legacyUserProviderKey(userId))
                ?? defaults.string(forKey: legacyGlobalProviderKey)
        } else {
            apiKey = defaults.string(forKey: legacyGlobalApiKey)
            provider = defaults.string(forKey: legacyGlobalProviderKey)
        }

        guard let apiKey, !apiKey.isEmpty else { return nil }
        return (apiKey, provider ?? "anthropic")
    }

    /// Clears any legacy per-user / global API key entries from UserDefaults
    /// after a successful migration to household-scoped storage.
    static func clearLegacyLocalAPIKey() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: legacyGlobalApiKey)
        defaults.removeObject(forKey: legacyGlobalProviderKey)
        if let userId = currentUserId {
            defaults.removeObject(forKey: legacyUserApiKey(userId))
            defaults.removeObject(forKey: legacyUserProviderKey(userId))
        }
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

        let provider = AIProvider.current
        guard let request = buildRequest(
            apiKey: apiKey, base64Image: imageData.base64EncodedString(),
            provider: provider, prompt: Self.analysisPrompt
        ) else {
            error = .decodingError("Failed to create request")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            try parseResponse(data, provider: provider)
        } catch let analysisError as ImageAnalysisError {
            error = analysisError
        } catch {
            self.error = .networkError(error)
        }
    }

    private func parseResponse(_ data: Data, provider: AIProvider) throws {
        let text = try extractText(from: data, provider: provider)
        let cleaned = Self.extractJSONArray(from: text)

        guard let itemsData = cleaned.data(using: .utf8),
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

    /// Extracts a JSON array from text that may be wrapped in markdown code fences
    /// or have surrounding prose.
    static func extractJSONArray(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ```json ... ``` or ``` ... ``` fences
        if cleaned.hasPrefix("```") {
            // Drop first line (```json or ```)
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            // Drop trailing ```
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // If there's still surrounding prose, find the first [ and last ]
        if let start = cleaned.firstIndex(of: "["),
           let end = cleaned.lastIndex(of: "]") {
            cleaned = String(cleaned[start...end])
        }

        return cleaned
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
        buildRequest(apiKey: apiKey, base64Image: base64Image, provider: AIProvider.current, prompt: prompt, maxTokens: 512)
    }

    private func parseValueResponse(_ data: Data) throws -> ValueEstimate {
        let text = try extractText(from: data, provider: AIProvider.current)
        let cleaned = Self.extractJSONObject(from: text)
        guard let valueData = cleaned.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: valueData) as? [String: Any],
              let estimatedValue = parsed["estimated_value"] as? Double else {
            throw ImageAnalysisError.decodingError("Could not parse value estimate")
        }
        let reasoning = parsed["reasoning"] as? String ?? ""
        return ValueEstimate(value: estimatedValue, reasoning: reasoning)
    }

    private func extractText(from data: Data, provider: AIProvider) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImageAnalysisError.decodingError("Response is not valid JSON")
        }
        if let errorDict = json["error"] as? [String: Any],
           let message = errorDict["message"] as? String {
            throw ImageAnalysisError.decodingError("API error: \(message)")
        }
        switch provider {
        case .anthropic:
            guard let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String else {
                throw ImageAnalysisError.decodingError("Unexpected response format")
            }
            return text
        case .openai:
            guard let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw ImageAnalysisError.decodingError("Unexpected response format")
            }
            return content
        }
    }

    private func buildRequest(apiKey: String, base64Image: String,
                              provider: AIProvider, prompt: String,
                              maxTokens: Int = 1024) -> URLRequest? {
        let requestBody: [String: Any]
        let urlString: String
        switch provider {
        case .anthropic:
            requestBody = [
                "model": "claude-sonnet-4-5", "max_tokens": maxTokens,
                "messages": [[
                    "role": "user",
                    "content": [
                        ["type": "image", "source": [
                            "type": "base64", "media_type": "image/jpeg", "data": base64Image]],
                        ["type": "text", "text": prompt],
                    ],
                ]],
            ]
            urlString = "https://api.anthropic.com/v1/messages"
        case .openai:
            requestBody = [
                "model": "gpt-4o", "max_tokens": maxTokens,
                "messages": [[
                    "role": "user",
                    "content": [
                        ["type": "image_url",
                         "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]],
                        ["type": "text", "text": prompt],
                    ],
                ]],
            ]
            urlString = "https://api.openai.com/v1/chat/completions"
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let apiURL = URL(string: urlString) else { return nil }
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        switch provider {
        case .anthropic:
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        case .openai:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        }
        request.httpBody = jsonData
        return request
    }

    // MARK: - Bulk Value Estimation

    struct BulkValueResult: Identifiable {
        let id: UUID
        let value: Double
        let reasoning: String
    }

    /// Items to estimate values for. The id matches up with the result.
    struct BulkValueInput {
        let id: UUID
        let name: String
        let description: String
    }

    /// Estimate values for a batch of items in a single AI call.
    /// Returns a dictionary keyed by the input id.
    func estimateValuesBulk(items: [BulkValueInput]) async -> [UUID: BulkValueResult] {
        guard !items.isEmpty else { return [:] }

        guard let apiKey = Self.apiKey, !apiKey.isEmpty else {
            error = .noAPIKey
            return [:]
        }

        isAnalyzing = true
        error = nil
        defer { isAnalyzing = false }

        let itemsList = items.enumerated().map { index, item in
            "\(index + 1). \(item.name)" +
                (item.description.isEmpty ? "" : " — \(item.description)")
        }.joined(separator: "\n")

        let prompt = """
        Estimate the current resale value of each of the following items in US dollars.
        Use typical market prices for similar items in average used condition.

        Items:
        \(itemsList)

        Respond with ONLY a JSON array of objects, one per item in the same order, \
        each with: "index" (the item number from the list, 1-based), \
        "estimated_value" (a number in USD, no currency symbol), \
        "reasoning" (a brief 1-2 sentence explanation).
        Example: [{"index": 1, "estimated_value": 25.00, "reasoning": "Used hand tool, \
        retails for $20-30."}]
        Return ONLY the JSON array, no other text.
        """

        let provider = AIProvider.current
        guard let request = buildBulkValueRequest(
            apiKey: apiKey, prompt: prompt, provider: provider
        ) else {
            error = .decodingError("Failed to create request")
            return [:]
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try parseBulkValueResponse(data, inputs: items, provider: provider)
        } catch let analysisError as ImageAnalysisError {
            error = analysisError
            return [:]
        } catch {
            self.error = .networkError(error)
            return [:]
        }
    }

    private func buildBulkValueRequest(
        apiKey: String, prompt: String, provider: AIProvider
    ) -> URLRequest? {
        let requestBody: [String: Any]
        let urlString: String
        switch provider {
        case .anthropic:
            requestBody = [
                "model": "claude-sonnet-4-5", "max_tokens": 4096,
                "messages": [["role": "user", "content": [["type": "text", "text": prompt]]]],
            ]
            urlString = "https://api.anthropic.com/v1/messages"
        case .openai:
            requestBody = [
                "model": "gpt-4o", "max_tokens": 4096,
                "messages": [["role": "user", "content": prompt]],
            ]
            urlString = "https://api.openai.com/v1/chat/completions"
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let apiURL = URL(string: urlString) else { return nil }
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        switch provider {
        case .anthropic:
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        case .openai:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        }
        request.httpBody = jsonData
        return request
    }

    private func parseBulkValueResponse(
        _ data: Data,
        inputs: [BulkValueInput],
        provider: AIProvider
    ) throws -> [UUID: BulkValueResult] {
        let text = try extractText(from: data, provider: provider)
        let cleaned = Self.extractJSONArray(from: text)
        guard let arrayData = cleaned.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: arrayData) as? [[String: Any]] else {
            print("[ImageAnalysisService] Could not parse bulk values from text: \(text)")
            throw ImageAnalysisError.decodingError("Could not parse bulk value estimates")
        }

        var results: [UUID: BulkValueResult] = [:]
        for entry in parsed {
            guard let index = entry["index"] as? Int,
                  index >= 1, index <= inputs.count,
                  let value = entry["estimated_value"] as? Double else {
                continue
            }
            let input = inputs[index - 1]
            let reasoning = entry["reasoning"] as? String ?? ""
            results[input.id] = BulkValueResult(id: input.id, value: value, reasoning: reasoning)
        }
        return results
    }

    /// Extracts a JSON object from text that may be wrapped in markdown code fences.
    static func extractJSONObject(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        return cleaned
    }
}
