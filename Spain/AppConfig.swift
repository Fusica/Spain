//
//  AppConfig.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import Foundation
import Security

enum QwenModel: String, CaseIterable, Identifiable {
    case qwenPlus = "qwen-plus"
    case qwenTurbo = "qwen-turbo"
    case qwenMax = "qwen-max"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .qwenPlus:
            return "qwen-plus"
        case .qwenTurbo:
            return "qwen-turbo"
        case .qwenMax:
            return "qwen-max"
        }
    }
}

enum AppConfig {
    private static let apiKeyService = "Spain.QwenApiKey"
    private static let apiKeyAccount = "default"
    private static let modelKey = "qwen_model"

    static var qwenApiKey: String {
        if let stored = KeychainHelper.shared.read(service: apiKeyService, account: apiKeyAccount) {
            return stored
        }
        return Bundle.main.object(forInfoDictionaryKey: "QWEN_API_KEY") as? String ?? ""
    }

    static func setQwenApiKey(_ key: String) {
        if key.isEmpty {
            KeychainHelper.shared.delete(service: apiKeyService, account: apiKeyAccount)
        } else {
            KeychainHelper.shared.save(key, service: apiKeyService, account: apiKeyAccount)
        }
    }

    static var qwenModel: String {
        if let stored = UserDefaults.standard.string(forKey: modelKey) {
            return stored
        }
        return QwenModel.qwenPlus.rawValue
    }

    static func setQwenModel(_ model: String) {
        UserDefaults.standard.setValue(model, forKey: modelKey)
    }
}

final class KeychainHelper {
    static let shared = KeychainHelper()

    private init() {}

    func save(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
