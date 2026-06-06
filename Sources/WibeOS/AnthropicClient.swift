import Foundation

struct ChatMessage {
    let role: String
    let content: String
}

final class AnthropicClient {
    let apiKey: String
    var model = "claude-haiku-4-5-20251001"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func stream(system: String,
                messages: [ChatMessage],
                maxTokens: Int = 3500,
                onChunk: @escaping (String) -> Void,
                onDone: @escaping (String) -> Void,
                onError: @escaping (String) -> Void) {
        Task {
            var attempt = 0
            while true {
                attempt += 1
                do {
                    var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                    req.httpMethod = "POST"
                    req.timeoutInterval = 180
                    req.setValue("application/json", forHTTPHeaderField: "content-type")
                    req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": max(200, min(8192, maxTokens)),
                        "stream": true,
                        // cache the system prompt across calls: lower latency + cost
                        "system": [["type": "text", "text": system,
                                    "cache_control": ["type": "ephemeral"]]],
                        "messages": messages.map { ["role": $0.role, "content": $0.content] }
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        onError("No response from API")
                        return
                    }

                    // rate limited: wait and retry instead of failing the vibe
                    if (http.statusCode == 429 || http.statusCode == 529) && attempt < 4 {
                        let header = http.value(forHTTPHeaderField: "retry-after")
                        let wait = Double(header ?? "") ?? Double(8 * attempt)
                        try? await Task.sleep(nanoseconds: UInt64((wait + 1) * 1_000_000_000))
                        continue
                    }

                    guard http.statusCode == 200 else {
                        var errBody = ""
                        for try await line in bytes.lines {
                            errBody += line
                            if errBody.count > 1000 { break }
                        }
                        onError("API error \(http.statusCode): \(errBody.prefix(500))")
                        return
                    }

                    var full = ""
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard let data = payload.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }
                        if let type = obj["type"] as? String,
                           type == "content_block_delta",
                           let delta = obj["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            full += text
                            onChunk(text)
                        }
                    }
                    onDone(full)
                    return
                } catch {
                    if attempt < 3 {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        continue
                    }
                    onError(error.localizedDescription)
                    return
                }
            }
        }
    }
}
