import Foundation

enum AIProvider: String, CaseIterable {
    case deepseek = "deepseek"
    case siliconflow = "siliconflow"
    case gemini = "gemini"

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek (官方)"
        case .siliconflow: return "SiliconFlow (DeepSeek-V3)"
        case .gemini: return "Gemini 2.0 Flash"
        }
    }
}

/// Service that calls AI APIs to polish journal text
actor AIService {
    static let shared = AIService()

    private let polishPrompt = """
    你是一位文艺写作助手。请对以下日记内容进行润色，保持原意和情感不变，优化语法、用词和逻辑流畅度。风格要求：文艺清新，有文学气息，但不过分华丽。直接返回润色后的文本，不要添加任何解释，不要加前缀或后缀标记。

    原文：
    %@
    """

    func polish(text: String, provider: AIProvider, apiKey: String) async throws -> String {
        let prompt = String(format: polishPrompt, text)
        switch provider {
        case .deepseek:
            return try await callDeepSeek(prompt: prompt, apiKey: apiKey)
        case .siliconflow:
            return try await callSiliconFlow(prompt: prompt, apiKey: apiKey)
        case .gemini:
            return try await callGemini(prompt: prompt, apiKey: apiKey)
        }
    }

    // MARK: - DeepSeek official API
    private func callDeepSeek(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.deepseek.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 4096,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.serverError(statusCode: 0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage: String
            if let errorBody = try? JSONDecoder().decode(SiliconFlowErrorResponse.self, from: data) {
                errorMessage = errorBody.error.message
            } else {
                errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoded = try JSONDecoder().decode(SiliconFlowResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AIError.noResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - SiliconFlow (OpenAI-compatible)
    private func callSiliconFlow(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.siliconflow.cn/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "deepseek-ai/DeepSeek-V3",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 4096,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.serverError(statusCode: 0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error detail from response body
            let errorMessage: String
            if let errorBody = try? JSONDecoder().decode(SiliconFlowErrorResponse.self, from: data) {
                errorMessage = errorBody.error.message
            } else {
                errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoded = try JSONDecoder().decode(SiliconFlowResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AIError.noResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Gemini Flash
    private func callGemini(prompt: String, apiKey: String) async throws -> String {
        // Use header-based auth (more reliable than query parameter)
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.serverError(statusCode: 0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error detail from response body
            let errorMessage: String
            if let errorBody = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                errorMessage = "\(errorBody.error.message) (status: \(errorBody.error.status))"
            } else {
                errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text else {
            throw AIError.noResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AIError: LocalizedError {
    case serverError(statusCode: Int)
    case apiError(statusCode: Int, message: String)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .serverError(let code):
            return "Server error (\(code))"
        case .apiError(let code, let message):
            return "API error \(code): \(message)"
        case .noResponse:
            return "No response from AI"
        }
    }
}

// MARK: - API Response Models
private struct SiliconFlowErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
    }
    let error: ErrorDetail
}

private struct SiliconFlowResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

private struct GeminiErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let code: Int
        let message: String
        let status: String
    }
    let error: ErrorDetail
}

private struct GeminiResponse: Codable {
    let candidates: [Candidate]?

    struct Candidate: Codable {
        let content: Content?
    }

    struct Content: Codable {
        let parts: [Part]?
    }

    struct Part: Codable {
        let text: String?
    }
}
