//
//  QwenService.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import Foundation

struct WordAnalysis: Codable {
    let lemma: String?
    let partOfSpeech: String?
    let isVerb: Bool?
    let meaning: String
    let language: String
    let conjugation: Conjugation?
    let nounPlural: String?
    let adjectiveForms: AdjectiveForms?
}

struct WordTips: Codable {
    let tips: String
}

enum QwenServiceError: LocalizedError {
    case missingApiKey
    case httpError(code: Int, message: String)
    case invalidResponse
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "未配置 QWEN_API_KEY。"
        case .httpError(let code, let message):
            return "请求失败（\(code)）：\(message)"
        case .invalidResponse:
            return "返回内容无法解析。"
        case .parseFailed:
            return "解析结果失败，请重试。"
        }
    }
}

final class QwenService {
    static let shared = QwenService()

    private let baseURL = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!

    private init() {}

    func analyze(word: String, targetLanguage: MeaningLanguage) async throws -> WordAnalysis {
        let apiKey = AppConfig.qwenApiKey
        guard !apiKey.isEmpty else { throw QwenServiceError.missingApiKey }

        let prompt = buildPrompt(word: word, targetLanguage: targetLanguage)
        let requestBody = QwenChatRequest(
            model: AppConfig.qwenModel,
            messages: [
                QwenMessage(role: "system", content: prompt.system),
                QwenMessage(role: "user", content: prompt.user)
            ],
            temperature: 0.2
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QwenServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw QwenServiceError.httpError(code: httpResponse.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(QwenChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw QwenServiceError.invalidResponse
        }

        guard let jsonString = extractJSONObject(from: content) else {
            throw QwenServiceError.invalidResponse
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let analysis = try? JSONDecoder().decode(WordAnalysis.self, from: jsonData) else {
            throw QwenServiceError.parseFailed
        }
        return analysis
    }

    func generateTips(for word: WordEntry) async throws -> WordTips {
        let apiKey = AppConfig.qwenApiKey
        guard !apiKey.isEmpty else { throw QwenServiceError.missingApiKey }

        let prompt = buildTipsPrompt(for: word)
        let requestBody = QwenChatRequest(
            model: AppConfig.qwenModel,
            messages: [
                QwenMessage(role: "system", content: prompt.system),
                QwenMessage(role: "user", content: prompt.user)
            ],
            temperature: 0.7
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QwenServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw QwenServiceError.httpError(code: httpResponse.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(QwenChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw QwenServiceError.invalidResponse
        }

        guard let jsonString = extractJSONObject(from: content) else {
            throw QwenServiceError.invalidResponse
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let tips = try? JSONDecoder().decode(WordTips.self, from: jsonData) else {
            throw QwenServiceError.parseFailed
        }
        return tips
    }

    private func buildPrompt(word: String, targetLanguage: MeaningLanguage) -> (system: String, user: String) {
        let languageCode = targetLanguage == .chinese ? "zh" : "en"
        let system = """
        你是西班牙语词汇分析器。只能输出 JSON，禁止任何解释或额外文本。
        输出必须严格符合此 schema：
        {
          "lemma": string,
          "partOfSpeech": "verb" | "noun" | "adjective" | "other",
          "isVerb": boolean,
          "meaning": string,
          "language": "zh" | "en",
          "conjugation": {
            "yo": string,
            "tu": string,
            "elElla": string,
            "nosotros": string,
            "vosotros": string,
            "ellosEllas": string
          } | null,
          "nounPlural": string | null,
          "adjectiveForms": {
            "masculineSingular": string,
            "feminineSingular": string,
            "masculinePlural": string,
            "femininePlural": string
          } | null
        }
        如果没有动词用法，conjugation 必须为 null。
        如果没有名词用法，nounPlural 必须为 null。
        如果没有形容词用法，adjectiveForms 必须为 null。
        如果输入是动词变位、命令式、分词或动名词，请先还原为动词原形（lemma），释义也用原形释义。
        如果输入是名词复数或派生形式，请还原名词单数原形（lemma），并在 nounPlural 填入复数形式。
        如果输入是形容词的阴阳性/复数形式，请还原为阳性单数原形（lemma），并填充 adjectiveForms。
        如果词同时具有多种词性（例如 vivo 可作形容词，也可作动词变位），请同时填充对应字段；partOfSpeech 选择主要词性。
        """
        let user = """
        输入词：\(word)
        释义语言：\(languageCode)
        """
        return (system, user)
    }

    private func buildTipsPrompt(for word: WordEntry) -> (system: String, user: String) {
        let languageCode = "zh"
        let conjugation: String
        if let conjugationValue = word.conjugation {
            conjugation = """
            yo=\(conjugationValue.yo), tu=\(conjugationValue.tu), el/ella=\(conjugationValue.elElla), \
            nosotros=\(conjugationValue.nosotros), vosotros=\(conjugationValue.vosotros), ellos/ellas=\(conjugationValue.ellosEllas)
            """
        } else {
            conjugation = "无"
        }
        let nounPlural = word.nounPlural?.trimmed.isEmpty == false ? word.nounPlural ?? "" : "无"
        let adjectiveForms: String
        if let forms = word.adjectiveForms {
            adjectiveForms = """
            masculino sg=\(forms.masculineSingular), femenino sg=\(forms.feminineSingular), \
            masculino pl=\(forms.masculinePlural), femenino pl=\(forms.femininePlural)
            """
        } else {
            adjectiveForms = "无"
        }

        let system = """
        你是西班牙语记忆教练。只能输出 JSON，禁止任何解释或额外文本。
        输出必须严格符合此 schema：
        {
          "tips": string
        }
        tips 必须以 "Tips:" 开头，使用中文，控制在 1-3 句。
        可包含词根联想、谐音、场景联想或词形/变位记忆提示；如果没有相关信息就给出通用记忆技巧。
        """
        let user = """
        词条：\(word.spanish)
        释义：\(word.meaningText)
        词性：\(word.partOfSpeech.rawValue)
        是否动词：\(word.isVerb ? "是" : "否")
        动词变位：\(conjugation)
        名词复数：\(nounPlural)
        形容词形式：\(adjectiveForms)
        输出语言：\(languageCode)
        """
        return (system, user)
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        return String(text[start...end])
    }
}

private struct QwenChatRequest: Codable {
    let model: String
    let messages: [QwenMessage]
    let temperature: Double
}

private struct QwenMessage: Codable {
    let role: String
    let content: String
}

private struct QwenChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}
