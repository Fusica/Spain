//
//  Models.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import Foundation

enum MeaningLanguage: String, Codable, CaseIterable, Identifiable {
    case chinese = "中文"
    case english = "英文"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum PartOfSpeech: String, Codable, CaseIterable, Identifiable {
    case verb
    case noun
    case adjective
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .verb:
            return "动词"
        case .noun:
            return "名词"
        case .adjective:
            return "形容词"
        case .other:
            return "其他"
        }
    }
}

struct Conjugation: Codable, Hashable {
    var yo: String
    var tu: String
    var elElla: String
    var nosotros: String
    var vosotros: String
    var ellosEllas: String
}

struct AdjectiveForms: Codable, Hashable {
    var masculineSingular: String
    var feminineSingular: String
    var masculinePlural: String
    var femininePlural: String

    enum CodingKeys: String, CodingKey {
        case masculineSingular
        case feminineSingular
        case masculinePlural
        case femininePlural
    }

    init(
        masculineSingular: String,
        feminineSingular: String,
        masculinePlural: String,
        femininePlural: String
    ) {
        self.masculineSingular = masculineSingular
        self.feminineSingular = feminineSingular
        self.masculinePlural = masculinePlural
        self.femininePlural = femininePlural
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        masculineSingular = try container.decodeIfPresent(String.self, forKey: .masculineSingular) ?? ""
        feminineSingular = try container.decodeIfPresent(String.self, forKey: .feminineSingular) ?? ""
        masculinePlural = try container.decodeIfPresent(String.self, forKey: .masculinePlural) ?? ""
        femininePlural = try container.decodeIfPresent(String.self, forKey: .femininePlural) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(masculineSingular, forKey: .masculineSingular)
        try container.encode(feminineSingular, forKey: .feminineSingular)
        try container.encode(masculinePlural, forKey: .masculinePlural)
        try container.encode(femininePlural, forKey: .femininePlural)
    }
}

struct WordEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var spanish: String
    var chinese: String
    var isVerb: Bool
    var conjugation: Conjugation?
    var partOfSpeech: PartOfSpeech
    var nounPlural: String?
    var adjectiveForms: AdjectiveForms?
    var createdAt: Date
    var reviewStage: Int
    var nextReviewDate: Date
    var lastReviewedAt: Date?
    var meaningLanguage: MeaningLanguage

    enum CodingKeys: String, CodingKey {
        case id
        case spanish
        case chinese
        case isVerb
        case conjugation
        case partOfSpeech
        case nounPlural
        case adjectiveForms
        case createdAt
        case reviewStage
        case nextReviewDate
        case lastReviewedAt
        case meaningLanguage
    }

    init(
        id: UUID,
        spanish: String,
        chinese: String,
        partOfSpeech: PartOfSpeech,
        conjugation: Conjugation?,
        nounPlural: String?,
        adjectiveForms: AdjectiveForms?,
        createdAt: Date,
        reviewStage: Int,
        nextReviewDate: Date,
        lastReviewedAt: Date? = nil,
        meaningLanguage: MeaningLanguage = .chinese
    ) {
        self.id = id
        self.spanish = spanish
        self.chinese = chinese
        self.partOfSpeech = partOfSpeech
        self.isVerb = partOfSpeech == .verb || conjugation != nil
        self.conjugation = conjugation
        self.nounPlural = nounPlural
        self.adjectiveForms = adjectiveForms
        self.createdAt = createdAt
        self.reviewStage = reviewStage
        self.nextReviewDate = nextReviewDate
        self.lastReviewedAt = lastReviewedAt
        self.meaningLanguage = meaningLanguage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        spanish = try container.decode(String.self, forKey: .spanish)
        chinese = try container.decode(String.self, forKey: .chinese)
        let storedIsVerb = try container.decodeIfPresent(Bool.self, forKey: .isVerb) ?? false
        partOfSpeech = try container.decodeIfPresent(PartOfSpeech.self, forKey: .partOfSpeech)
            ?? (storedIsVerb ? .verb : .other)
        conjugation = try container.decodeIfPresent(Conjugation.self, forKey: .conjugation)
        isVerb = partOfSpeech == .verb || conjugation != nil
        nounPlural = try container.decodeIfPresent(String.self, forKey: .nounPlural)
        adjectiveForms = try container.decodeIfPresent(AdjectiveForms.self, forKey: .adjectiveForms)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        reviewStage = try container.decode(Int.self, forKey: .reviewStage)
        nextReviewDate = try container.decode(Date.self, forKey: .nextReviewDate)
        lastReviewedAt = try container.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        if lastReviewedAt == nil, reviewStage > 0 {
            lastReviewedAt = createdAt
        }
        meaningLanguage = try container.decodeIfPresent(MeaningLanguage.self, forKey: .meaningLanguage) ?? .chinese
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(spanish, forKey: .spanish)
        try container.encode(chinese, forKey: .chinese)
        try container.encode(isVerb, forKey: .isVerb)
        try container.encodeIfPresent(conjugation, forKey: .conjugation)
        try container.encode(partOfSpeech, forKey: .partOfSpeech)
        try container.encodeIfPresent(nounPlural, forKey: .nounPlural)
        try container.encodeIfPresent(adjectiveForms, forKey: .adjectiveForms)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(reviewStage, forKey: .reviewStage)
        try container.encode(nextReviewDate, forKey: .nextReviewDate)
        try container.encodeIfPresent(lastReviewedAt, forKey: .lastReviewedAt)
        try container.encode(meaningLanguage, forKey: .meaningLanguage)
    }
}

enum MasteryStatus: String {
    case notStarted = "未开始"
    case learning = "初记"
    case fuzzy = "模糊"
    case familiar = "熟悉"
    case mastered = "掌握"
}

extension WordEntry {
    var spanishVariants: [String] {
        var variants: [String] = [spanish]
        if let conjugation {
            variants.append(contentsOf: [
                conjugation.yo,
                conjugation.tu,
                conjugation.elElla,
                conjugation.nosotros,
                conjugation.vosotros,
                conjugation.ellosEllas
            ])
        }
        if let nounPlural {
            variants.append(nounPlural)
        }
        if let forms = adjectiveForms {
            variants.append(contentsOf: [
                forms.masculineSingular,
                forms.feminineSingular,
                forms.masculinePlural,
                forms.femininePlural
            ])
        }
        let trimmed = variants.map { $0.trimmed }.filter { !$0.isEmpty }
        var unique: [String] = []
        for value in trimmed {
            if !unique.contains(where: { $0.normalizedAnswer == value.normalizedAnswer }) {
                unique.append(value)
            }
        }
        return unique
    }

    func matchesSpanishVariant(_ key: String) -> Bool {
        let normalized = key.normalizedAnswer
        guard !normalized.isEmpty else { return false }
        return spanishVariants.contains { $0.normalizedAnswer == normalized }
    }

    func matchesSearchKey(_ key: String) -> Bool {
        let normalized = key.normalizedAnswer
        guard !normalized.isEmpty else { return true }
        if meaningText.normalizedAnswer.contains(normalized) {
            return true
        }
        return spanishVariants.contains { $0.normalizedAnswer.contains(normalized) }
    }

    var meaningText: String {
        chinese
    }

    var meaningLabel: String {
        "\(meaningLanguage.displayName)释义"
    }

    var partOfSpeechLabel: String {
        var labels: [String] = []
        let primary = partOfSpeech.displayName
        if !primary.isEmpty {
            labels.append(primary)
        }
        if partOfSpeech != .verb, conjugation != nil {
            labels.append(PartOfSpeech.verb.displayName)
        }
        if partOfSpeech != .noun, nounPlural?.trimmed.isEmpty == false {
            labels.append(PartOfSpeech.noun.displayName)
        }
        if partOfSpeech != .adjective, adjectiveForms != nil {
            labels.append(PartOfSpeech.adjective.displayName)
        }
        var unique: [String] = []
        for label in labels where !unique.contains(label) {
            unique.append(label)
        }
        return unique.joined(separator: "/")
    }

    var masteryStatus: MasteryStatus {
        if lastReviewedAt == nil {
            return .notStarted
        }
        switch reviewStage {
        case ...0:
            return .learning
        case 1:
            return .fuzzy
        case 2:
            return .familiar
        default:
            return .mastered
        }
    }
}

enum ReviewSchedule {
    static let intervals: [TimeInterval] = [
        24 * 60 * 60,
        3 * 24 * 60 * 60,
        7 * 24 * 60 * 60,
        30 * 24 * 60 * 60
    ]

    static func nextDate(from now: Date, stage: Int) -> Date {
        let safeStage = min(max(stage, 0), intervals.count - 1)
        return now.addingTimeInterval(intervals[safeStage])
    }
}
