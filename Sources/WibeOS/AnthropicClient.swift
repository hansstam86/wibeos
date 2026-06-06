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
                onChunk: @escaping (String) -> Void,
                onDone: @escaping (String) -> Void,
                onError: @escaping (String) -> Void) {
        Task {
            do {
                var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                req.httpMethod = "POST"
                req.timeoutInterval = 180
                req.setValue("application/json", forHTTPHeaderField: "content-type")
                req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                let body: [String: Any] = [
                    "model": model,
                    "max_tokens": 8192,
                    "stream": true,
                    // cache the system prompt across calls: lower latency + cost
                    "system": [["type": "text", "text": system,
                                "cache_control": ["type": "ephemeral"]]],
                    "messages": messages.map { ["role": $0.role, "content": $0.content] }
                ]
                req.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (bytes, response) = try await URLSession.shared.bytes(for: req)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    var errBody = ""
                    for try await line in bytes.lines {
                        errBody += line
                        if errBody.count > 1000 { break }
                    }
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    onError("API error \(code): \(errBody.prefix(500))")
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
            } catch {
                onError(error.localizedDescription)
            }
        }
    }
}
