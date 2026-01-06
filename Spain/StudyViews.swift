//
//  StudyViews.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import SwiftUI

struct StudyView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var sessionCount = 10
    @State private var sessionPlan: StudySessionPlan?

    private var maxSessionCount: Int {
        max(store.words.count, 1)
    }

    private var dueWords: [WordEntry] {
        store.dueWords()
    }

    var body: some View {
        NavigationStack {
            List {
                Section("每日提醒") {
                    Toggle(
                        "开启提醒",
                        isOn: Binding(
                            get: { store.remindersEnabled },
                            set: { store.setRemindersEnabled($0) }
                        )
                    )
                    DatePicker(
                        "提醒时间",
                        selection: Binding(
                            get: { store.reminderTime },
                            set: { store.updateReminderTime($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!store.remindersEnabled)
                }

                Section("背诵设置") {
                    Stepper(value: $sessionCount, in: 1...maxSessionCount) {
                        Text("每组单词：\(sessionCount) 个")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    Button {
                        var words = store.sessionWords(count: sessionCount)
                        if words.count > 1 {
                            words.shuffle()
                        }
                        guard !words.isEmpty else { return }
                        sessionPlan = StudySessionPlan(words: words)
                    } label: {
                        Text("开始背诵")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(store.words.isEmpty)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("待复习") {
                    if dueWords.isEmpty {
                        Text("暂无待复习单词。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dueWords.prefix(5)) { word in
                            HStack {
                                Text(word.spanish)
                                Spacer()
                                MeaningText(text: word.meaningText, language: word.meaningLanguage, style: .body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if dueWords.count > 5 {
                            Text("还有 \(dueWords.count - 5) 个待复习。")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("遗忘曲线") {
                    Text("复习间隔：初记 1 天、模糊 3 天、熟悉 7 天、掌握 30 天。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("状态说明：本轮无错升一档；错 1-2 次不变；错 3 次及以上降一档（不低于初记）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("背诵")
            .listStyle(.insetGrouped)
            .sheet(item: $sessionPlan) { plan in
                StudySessionView(sessionWords: plan.words)
            }
            .onChange(of: store.words.count) { _, newValue in
                sessionCount = min(sessionCount, max(newValue, 1))
            }
        }
    }
}

struct StudySessionView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let sessionWords: [WordEntry]
    @State private var currentIndex = 0
    @State private var progress: [UUID: Int] = [:]
    @State private var errorCounts: [UUID: Int] = [:]
    @State private var question: StudyQuestion?
    @State private var selectedChoice: String?
    @State private var pendingChoice: String?
    @State private var dictationInput = ""
    @State private var showFeedback = false
    @State private var wasCorrect = false

    private var currentWordIndex: Int? {
        guard !sessionWords.isEmpty else { return nil }
        for offset in 0..<sessionWords.count {
            let index = (currentIndex + offset) % sessionWords.count
            let word = sessionWords[index]
            if progress[word.id, default: 0] < StudyRound.totalRounds {
                return index
            }
        }
        return nil
    }

    private var currentWord: WordEntry? {
        guard let index = currentWordIndex else { return nil }
        return sessionWords[index]
    }

    private var completedCount: Int {
        sessionWords.filter { progress[$0.id, default: 0] >= StudyRound.totalRounds }.count
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let _ = currentWord {
                    if let question {
                        VStack(spacing: 18) {
                            Text("已完成 \(completedCount) / \(sessionWords.count) · 第 \(question.round.rawValue + 1) 轮")
                                .font(.body)
                                .foregroundStyle(secondaryTextColor)

                            if question.round == .spanishToChinese {
                                Text(question.prompt)
                                    .font(.system(size: 40, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(primaryTextColor)
                            } else if let word = currentWord {
                                MeaningText(
                                    text: question.prompt,
                                    language: word.meaningLanguage,
                                    size: 40,
                                    weight: .semibold
                                )
                                .multilineTextAlignment(.center)
                                .foregroundStyle(primaryTextColor)
                            } else {
                                Text(question.prompt)
                                    .font(.system(size: 40, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(primaryTextColor)
                            }

                            if let subject = question.subject {
                                Text("主语：\(subject)")
                                    .font(.title.weight(.semibold))
                                    .foregroundStyle(secondaryTextColor)
                            }

                            if question.round.isMultipleChoice {
                                VStack(spacing: 12) {
                                    ForEach(question.choices, id: \.self) { choice in
                                        let isPending = pendingChoice == choice && !showFeedback
                                        Button {
                                            pendingChoice = choice
                                        } label: {
                                            ZStack {
                                                if question.round == .spanishToChinese, let word = currentWord {
                                                    MeaningText(text: choice, language: word.meaningLanguage, style: .title2)
                                                        .foregroundStyle(primaryTextColor)
                                                } else {
                                                    Text(choice)
                                                        .font(.title2)
                                                        .foregroundStyle(primaryTextColor)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .overlay(alignment: .trailing) {
                                                if showFeedback, let selectedChoice, selectedChoice == choice {
                                                    Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                        .foregroundStyle(wasCorrect ? .green : .red)
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(isPending ? Color.blue.opacity(0.28) : Color(.secondarySystemFill))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(isPending ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(showFeedback)
                                    }
                                    if showFeedback {
                                        feedbackView(question: question)
                                    }
                                    Spacer(minLength: 12)
                                    Button(showFeedback ? "继续" : "确定") {
                                        confirmOrContinue()
                                    }
                                    .font(.title2)
                                    .buttonStyle(.borderedProminent)
                                    .disabled(showFeedback ? false : pendingChoice == nil)
                                }
                            } else {
                                VStack(spacing: 12) {
                                    TextField(question.subject == nil ? "输入完整答案" : "输入动词变位", text: $dictationInput)
                                        .textInputAutocapitalization(.never)
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(showFeedback)
                                        .font(.title2)
                                        .foregroundStyle(primaryTextColor)
                                    Button("提交") {
                                        handleDictation()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(showFeedback || dictationInput.trimmed.isEmpty)
                                }
                            }

                            if showFeedback {
                                if !question.round.isMultipleChoice {
                                    VStack(spacing: 8) {
                                        feedbackView(question: question)
                                        Button("继续") {
                                            advanceAfterFeedback()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .padding(.top, 4)
                                    }
                                    .padding(.top, 8)
                                }
                            }

                            Spacer()
                        }
                        .padding()
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("正在准备题目...")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("本组背诵完成！")
                            .font(.title3)
                        Button("返回") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle(currentWord == nil ? "完成" : "背诵中")
            .toolbar {
                if currentWord != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("结束") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            prepareQuestion()
        }
    }

    private func prepareQuestion() {
        guard let word = currentWord else {
            question = nil
            return
        }
        let completedRounds = progress[word.id, default: 0]
        let round = StudyRound(rawValue: completedRounds) ?? .spanishToChinese
        question = makeQuestion(for: word, round: round)
        selectedChoice = nil
        pendingChoice = nil
        dictationInput = ""
        showFeedback = false
        wasCorrect = false
    }

    private func confirmChoice() {
        guard let question, let pendingChoice else { return }
        selectedChoice = pendingChoice
        wasCorrect = (pendingChoice == question.correctAnswer)
        showFeedback = true
    }

    private func confirmOrContinue() {
        if showFeedback {
            advanceAfterFeedback()
        } else {
            confirmChoice()
        }
    }

    @ViewBuilder
    private func feedbackView(question: StudyQuestion) -> some View {
        VStack(spacing: 8) {
            Text(wasCorrect ? "回答正确" : "回答错误")
                .font(.title2.weight(.semibold))
                .foregroundStyle(wasCorrect ? .green : .red)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("正确答案：")
                    .font(.title2)
                    .foregroundStyle(secondaryTextColor)
                if question.round == .spanishToChinese, let word = currentWord {
                    MeaningText(text: question.correctAnswer, language: word.meaningLanguage, style: .title2)
                        .foregroundStyle(secondaryTextColor)
                } else {
                    Text(question.correctAnswer)
                        .font(.title2)
                        .foregroundStyle(secondaryTextColor)
                }
            }
            if !wasCorrect {
                Text("错误已记录，完成三轮后会调整记忆程度。")
                    .font(.title3)
                    .foregroundStyle(secondaryTextColor)
            }
        }
    }

    private func handleDictation() {
        guard let question else { return }
        let normalizedInput = dictationInput.normalizedAnswer
        let normalizedAnswer = question.correctAnswer.normalizedAnswer
        wasCorrect = (normalizedInput == normalizedAnswer)
        showFeedback = true
    }

    private func advanceAfterFeedback() {
        guard let word = currentWord, let wordIndex = currentWordIndex else { return }
        if !wasCorrect {
            errorCounts[word.id, default: 0] += 1
        }
        let nextCount = min((progress[word.id, default: 0] + 1), StudyRound.totalRounds)
        progress[word.id] = nextCount
        if nextCount >= StudyRound.totalRounds {
            let errors = errorCounts[word.id, default: 0]
            store.applySessionResult(for: word.id, errors: errors)
            errorCounts[word.id] = 0
        }

        currentIndex = (wordIndex + 1) % sessionWords.count
        prepareQuestion()
    }

    private func makeQuestion(for word: WordEntry, round: StudyRound) -> StudyQuestion {
        switch round {
        case .spanishToChinese:
            let correct = word.meaningText
            let choices = buildChoices(
                correct: correct,
                pool: store.words.map { $0.meaningText }
            )
            return StudyQuestion(
                round: round,
                title: "选择正确的\(word.meaningLanguage.displayName)释义",
                prompt: word.spanish,
                choices: choices,
                correctAnswer: correct,
                subject: nil
            )
        case .chineseToSpanish:
            let correct = word.spanish
            let choices = buildChoices(
                correct: correct,
                pool: store.words.map { $0.spanish }
            )
            return StudyQuestion(
                round: round,
                title: "选择正确的西班牙语",
                prompt: word.meaningText,
                choices: choices,
                correctAnswer: correct,
                subject: nil
            )
        case .dictation:
            let dictation = makeDictation(for: word)
            return StudyQuestion(
                round: round,
                title: "默写西班牙语",
                prompt: word.meaningText,
                choices: [],
                correctAnswer: dictation.answer,
                subject: dictation.subject
            )
        }
    }

    private func makeDictation(for word: WordEntry) -> (subject: String?, answer: String) {
        guard word.isVerb, let conjugation = word.conjugation else {
            return (nil, word.spanish)
        }

        let options = verbOptions(from: conjugation)
        if let option = options.randomElement() {
            return (option.subject, option.form)
        }

        return (nil, word.spanish)
    }

    private func verbOptions(from conjugation: Conjugation) -> [(subject: String, form: String)] {
        let options = [
            ("yo", conjugation.yo),
            ("tu", conjugation.tu),
            ("el/ella", conjugation.elElla),
            ("nosotros", conjugation.nosotros),
            ("vosotros", conjugation.vosotros),
            ("ellos/ellas", conjugation.ellosEllas)
        ]
        return options
            .map { (subject: $0.0, form: $0.1.trimmed) }
            .filter { !$0.form.isEmpty }
    }

    private func buildChoices(correct: String, pool: [String]) -> [String] {
        let trimmedPool = pool
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
        var uniquePool = Array(Set(trimmedPool))
        uniquePool.removeAll { $0 == correct }
        uniquePool.shuffle()

        let needed = max(StudyRound.choiceCount - 1, 0)
        let choices = Array(uniquePool.prefix(needed)) + [correct]
        return choices.shuffled()
    }
}

private enum StudyRound: Int {
    case spanishToChinese = 0
    case chineseToSpanish
    case dictation

    static let totalRounds = 3
    static let choiceCount = 4

    var isMultipleChoice: Bool {
        self != .dictation
    }
}

private struct StudyQuestion {
    let round: StudyRound
    let title: String
    let prompt: String
    let choices: [String]
    let correctAnswer: String
    let subject: String?
}

#Preview {
    StudyView()
        .environmentObject(StudyStore())
}

private struct StudySessionPlan: Identifiable {
    let id = UUID()
    let words: [WordEntry]
}
