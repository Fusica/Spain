//
//  SettingsView.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = AppConfig.qwenApiKey
    @State private var statusMessage: String?
    @AppStorage("qwen_model") private var selectedModel = QwenModel.qwenPlus.rawValue
    @AppStorage("english_font_option") private var englishFontOption = EnglishFontOption.system.rawValue
    @FocusState private var apiKeyFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("千问设置") {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .focused($apiKeyFocused)

                    Picker("模型", selection: $selectedModel) {
                        ForEach(QwenModel.allCases) { model in
                            Text(model.displayName).tag(model.rawValue)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            saveApiKey()
                        } label: {
                            Text("保存")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                        Button {
                            apiKey = ""
                            AppConfig.setQwenApiKey("")
                            statusMessage = "已清空 API Key"
                        } label: {
                            Text("清除")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("显示") {
                    Picker("英语字体", selection: $englishFontOption) {
                        ForEach(EnglishFontOption.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("说明") {
                    Text("模型选择与 API Key 保存后立即生效。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .onChange(of: selectedModel) { _, newValue in
                AppConfig.setQwenModel(newValue)
            }
        }
    }

    private func saveApiKey() {
        apiKeyFocused = false
        DispatchQueue.main.async {
            let trimmedKey = apiKey.trimmed
            guard !trimmedKey.isEmpty else {
                statusMessage = "请输入 API Key"
                return
            }
            AppConfig.setQwenApiKey(trimmedKey)
            statusMessage = "已保存 API Key"
        }
    }
}

#Preview {
    SettingsView()
}
