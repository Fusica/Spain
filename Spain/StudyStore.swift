//
//  StudyStore.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import Combine
import Foundation
import SwiftUI
import UserNotifications

private struct AppData: Codable {
    var words: [WordEntry]
    var reminderTime: Date
    var remindersEnabled: Bool
}

final class StudyStore: ObservableObject {
    @Published private(set) var words: [WordEntry] = []
    @Published private(set) var reminderTime: Date
    @Published private(set) var remindersEnabled: Bool = false

    private let storageURL: URL
    private var hasLoaded = false

    init() {
        let defaultTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        reminderTime = defaultTime
        storageURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("study_store.json")
        load()
    }

    func addWord(
        spanish: String,
        chinese: String,
        meaningLanguage: MeaningLanguage = .chinese,
        partOfSpeech: PartOfSpeech,
        conjugation: Conjugation?,
        nounPlural: String?,
        adjectiveForms: AdjectiveForms?,
        memoryTips: String? = nil
    ) {
        let now = Date()
        let entry = WordEntry(
            id: UUID(),
            spanish: spanish,
            chinese: chinese,
            partOfSpeech: partOfSpeech,
            conjugation: conjugation,
            nounPlural: nounPlural,
            adjectiveForms: adjectiveForms,
            createdAt: now,
            reviewStage: 0,
            nextReviewDate: ReviewSchedule.nextDate(from: now, stage: 0),
            meaningLanguage: meaningLanguage,
            memoryTips: memoryTips
        )
        words.insert(entry, at: 0)
        persist()
    }

    func removeWords(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
        persist()
    }

    func removeWords(ids: [UUID]) {
        let idSet = Set(ids)
        words.removeAll { idSet.contains($0.id) }
        persist()
    }

    func updateWord(
        id: UUID,
        spanish: String,
        meaning: String,
        meaningLanguage: MeaningLanguage,
        partOfSpeech: PartOfSpeech,
        conjugation: Conjugation?,
        nounPlural: String?,
        adjectiveForms: AdjectiveForms?
    ) {
        updateWord(id: id) { word in
            word.spanish = spanish
            word.chinese = meaning
            word.meaningLanguage = meaningLanguage
            word.partOfSpeech = partOfSpeech
            word.isVerb = partOfSpeech == .verb || conjugation != nil
            word.conjugation = conjugation
            word.nounPlural = nounPlural
            word.adjectiveForms = adjectiveForms
        }
    }

    func applyAnalysis(for id: UUID, analysis: WordAnalysis) {
        updateWord(id: id) { word in
            let normalizedLanguage = analysis.language.lowercased()
            if normalizedLanguage == "en" {
                word.meaningLanguage = .english
            } else if normalizedLanguage == "zh" {
                word.meaningLanguage = .chinese
            }
            if let lemma = analysis.lemma?.trimmed, !lemma.isEmpty {
                word.spanish = lemma
            }
            word.chinese = analysis.meaning

            let resolvedPart = resolvePartOfSpeech(analysis)
            word.partOfSpeech = resolvedPart
            word.isVerb = resolvedPart == .verb || analysis.conjugation != nil
            word.conjugation = analysis.conjugation

            let plural = analysis.nounPlural?.trimmed ?? ""
            word.nounPlural = plural.isEmpty ? nil : plural
            word.adjectiveForms = analysis.adjectiveForms
        }
    }

    func updateTips(for id: UUID, tips: String?) {
        updateWord(id: id) { word in
            let trimmed = tips?.trimmed ?? ""
            word.memoryTips = trimmed.isEmpty ? nil : trimmed
        }
    }

    func dueWords(reference: Date = Date()) -> [WordEntry] {
        words
            .filter { $0.lastReviewedAt != nil && $0.nextReviewDate <= reference }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    func sessionWords(count: Int, reference: Date = Date()) -> [WordEntry] {
        let due = dueWords(reference: reference)
        if due.count >= count {
            return Array(due.prefix(count))
        }

        let newWords = words
            .filter { $0.lastReviewedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
        let neededNew = max(count - due.count, 0)
        let pickedNew = Array(newWords.prefix(neededNew))
        return due + pickedNew
    }

    func advanceReview(for id: UUID, now: Date = Date()) {
        updateWord(id: id) { word in
            let nextStage = min(word.reviewStage + 1, ReviewSchedule.dayIntervals.count - 1)
            word.reviewStage = nextStage
            word.nextReviewDate = ReviewSchedule.nextDate(from: now, stage: nextStage)
            word.lastReviewedAt = now
        }
    }

    func resetReview(for id: UUID, now: Date = Date()) {
        updateWord(id: id) { word in
            word.reviewStage = 0
            word.nextReviewDate = ReviewSchedule.nextDate(from: now, stage: 0)
            word.lastReviewedAt = now
        }
    }

    func applySessionResult(for id: UUID, errors: Int, now: Date = Date()) {
        updateWord(id: id) { word in
            let maxStage = ReviewSchedule.dayIntervals.count - 1
            var stage = min(max(word.reviewStage, 0), maxStage)
            if errors == 0 {
                stage = min(stage + 1, maxStage)
            } else if errors >= 3 {
                stage = max(stage - 1, 0)
            }
            word.reviewStage = stage
            word.nextReviewDate = ReviewSchedule.nextDate(from: now, stage: stage)
            word.lastReviewedAt = now
        }
    }

    func updateReminderTime(_ date: Date) {
        reminderTime = date
        persist()
        if remindersEnabled {
            scheduleReminder()
        }
    }

    func setRemindersEnabled(_ enabled: Bool) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.remindersEnabled = true
                        self.persist()
                        self.scheduleReminder()
                    } else {
                        self.remindersEnabled = false
                        self.persist()
                    }
                }
            }
        } else {
            remindersEnabled = false
            persist()
            cancelReminder()
        }
    }

    private func updateWord(id: UUID, transform: (inout WordEntry) -> Void) {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return }
        var word = words[index]
        transform(&word)
        words[index] = word
        persist()
    }

    private func resolvePartOfSpeech(_ analysis: WordAnalysis) -> PartOfSpeech {
        if analysis.conjugation != nil {
            return .verb
        }
        if analysis.nounPlural?.trimmed.isEmpty == false {
            return .noun
        }
        if analysis.adjectiveForms != nil {
            return .adjective
        }
        if let raw = analysis.partOfSpeech?.lowercased(),
           let part = PartOfSpeech(rawValue: raw) {
            return part
        }
        if analysis.isVerb == true {
            return .verb
        }
        return .other
    }

    private func load() {
        var shouldPersist = false
        defer {
            hasLoaded = true
            if shouldPersist {
                persist()
            }
            if remindersEnabled {
                scheduleReminder()
            }
        }

        guard let data = try? Data(contentsOf: storageURL) else { return }
        guard let decoded = try? JSONDecoder().decode(AppData.self, from: data) else { return }
        words = decoded.words
        reminderTime = decoded.reminderTime
        remindersEnabled = decoded.remindersEnabled
        shouldPersist = normalizeReviewDatesIfNeeded()
    }

    private func persist() {
        guard hasLoaded else { return }
        let data = AppData(words: words, reminderTime: reminderTime, remindersEnabled: remindersEnabled)
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: storageURL, options: [.atomic])
    }

    private func normalizeReviewDatesIfNeeded() -> Bool {
        var didChange = false
        for index in words.indices {
            let anchor = words[index].lastReviewedAt ?? words[index].createdAt
            let normalizedDate = ReviewSchedule.nextDate(from: anchor, stage: words[index].reviewStage)
            if words[index].nextReviewDate != normalizedDate {
                words[index].nextReviewDate = normalizedDate
                didChange = true
            }
        }
        return didChange
    }

    func exportBackup() throws -> Data {
        let data = AppData(words: words, reminderTime: reminderTime, remindersEnabled: remindersEnabled)
        return try JSONEncoder().encode(data)
    }

    func importBackup(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(AppData.self, from: data)
        words = decoded.words
        reminderTime = decoded.reminderTime
        remindersEnabled = decoded.remindersEnabled
        hasLoaded = true
        persist()
        if remindersEnabled {
            scheduleReminder()
        } else {
            cancelReminder()
        }
    }

    private func scheduleReminder() {
        cancelReminder()

        let content = UNMutableNotificationContent()
        content.title = "背单词时间"
        content.body = "开始今天的西班牙语复习吧。"
        content.sound = .default

        var components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_word_reminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_word_reminder"])
    }
}
