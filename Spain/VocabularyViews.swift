//
//  VocabularyViews.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import SwiftUI

private enum MasteryFilter: String, CaseIterable, Identifiable {
    case all
    case notStarted
    case learning
    case fuzzy
    case familiar
    case mastered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .notStarted:
            return "未开始"
        case .learning:
            return "初记"
        case .fuzzy:
            return "模糊"
        case .familiar:
            return "熟悉"
        case .mastered:
            return "掌握"
        }
    }

    func matches(_ word: WordEntry) -> Bool {
        switch self {
        case .all:
            return true
        case .notStarted:
            return word.masteryStatus == .notStarted
        case .learning:
            return word.masteryStatus == .learning
        case .fuzzy:
            return word.masteryStatus == .fuzzy
        case .familiar:
            return word.masteryStatus == .familiar
        case .mastered:
            return word.masteryStatus == .mastered
        }
    }
}

private enum BulkUpdateMode {
    case analysis
    case tips
    case both

    var label: String {
        switch self {
        case .analysis:
            return "全部智能解析"
        case .tips:
            return "全部记忆技巧"
        case .both:
            return "智能解析 + 记忆技巧"
        }
    }

    var progressLabel: String {
        switch self {
        case .analysis:
            return "正在更新释义..."
        case .tips:
            return "正在更新记忆技巧..."
        case .both:
            return "正在更新全部内容..."
        }
    }

    var includesAnalysis: Bool {
        self == .analysis || self == .both
    }

    var includesTips: Bool {
        self == .tips || self == .both
    }
}

private func normalizeTipsText(_ text: String) -> String {
    let trimmed = text.trimmed
    guard !trimmed.isEmpty else { return "" }
    let lowercased = trimmed.lowercased()
    if lowercased.hasPrefix("tips") {
        let remainder = trimmed.dropFirst(4)
        let content = remainder.drop(while: { $0 == ":" || $0 == "：" || $0 == " " })
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "Tips:" : "Tips: \(normalized)"
    }
    return "Tips: \(trimmed)"
}

struct VocabularyListView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var isPresentingAdd = false
    @State private var searchText = ""
    @State private var statusFilter: MasteryFilter = .all
    @State private var isBulkUpdating = false
    @State private var bulkProgress = 0
    @State private var bulkTotal = 0
    @State private var showBulkError = false
    @State private var bulkErrorMessage = ""
    @State private var showSelectionUpdate = false

    private var sortedWords: [WordEntry] {
        store.words
    }

    private var filteredWords: [WordEntry] {
        let key = searchText.normalizedAnswer
        let candidates = sortedWords.filter { statusFilter.matches($0) }
        guard !key.isEmpty else { return candidates }
        return candidates.filter { $0.matchesSearchKey(key) }
    }

    private func count(for filter: MasteryFilter) -> Int {
        sortedWords.filter { filter.matches($0) }.count
    }

    private func filterLabel(for filter: MasteryFilter) -> String {
        let base = filter.title
        if statusFilter == filter {
            return "\(base) \(count(for: filter))"
        }
        return base
    }

    private var bulkProgressFraction: Double {
        guard bulkTotal > 0 else { return 0 }
        return min(max(Double(bulkProgress) / Double(bulkTotal), 0), 1)
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.words.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("还没有生词，先添加几个吧。")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(MasteryFilter.allCases) { filter in
                                        let isSelected = statusFilter == filter
                                        Button {
                                            statusFilter = filter
                                        } label: {
                                            Text(filterLabel(for: filter))
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(isSelected ? Color.blue.opacity(0.15) : Color(.secondarySystemFill))
                                                .foregroundStyle(isSelected ? .blue : .secondary)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 2)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }

                        if filteredWords.isEmpty {
                            Text("没有匹配结果。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredWords) { word in
                                NavigationLink {
                                    WordDetailView(wordID: word.id)
                                } label: {
                                    WordRowView(word: word)
                                }
                            }
                            .onDelete { offsets in
                                let ids = offsets.map { filteredWords[$0].id }
                                store.removeWords(ids: ids)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("词汇 \(store.words.count)")
            .searchable(text: $searchText, prompt: "搜索西班牙语、变形或释义")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("选择单词更新") {
                            showSelectionUpdate = true
                        }
                        Divider()
                        Button(BulkUpdateMode.analysis.label) {
                            startBulkUpdate(.analysis)
                        }
                        Button(BulkUpdateMode.tips.label) {
                            startBulkUpdate(.tips)
                        }
                        Button(BulkUpdateMode.both.label) {
                            startBulkUpdate(.both)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                                    .opacity(isBulkUpdating ? 1 : 0)
                                Circle()
                            .trim(from: 0, to: bulkProgressFraction)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .opacity(isBulkUpdating ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: bulkProgress)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .rotationEffect(.degrees(isBulkUpdating ? 360 : 0))
                            .animation(
                                isBulkUpdating
                                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                                    : .default,
                                value: isBulkUpdating
                            )
                    }
                    .frame(width: 24, height: 24)
                    Text("一键更新")
                }
            }
                    .disabled(isBulkUpdating || store.words.isEmpty)
                }
            }
            .alert("批量更新失败", isPresented: $showBulkError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(bulkErrorMessage)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    isPresentingAdd = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 60, height: 60)
                        Image(systemName: "plus")
                            .font(.system(size: 45, weight: .regular))
                            .foregroundStyle(.yellow)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
                .accessibilityLabel("新增生词")
            }
            .sheet(isPresented: $isPresentingAdd) {
                AddWordView()
            }
            .navigationDestination(isPresented: $showSelectionUpdate) {
                SelectedUpdateView()
            }
        }
    }

    private func startBulkUpdate(_ mode: BulkUpdateMode) {
        guard !isBulkUpdating else { return }
        Task {
            let words = await MainActor.run { store.words }
            guard !words.isEmpty else { return }
            _ = await MainActor.run {
                isBulkUpdating = true
                bulkProgress = 0
                bulkTotal = words.count
                bulkErrorMessage = ""
                showBulkError = false
            }

            for word in words {
                do {
                    var resolvedWord = word
                    if mode.includesAnalysis {
                        let analysis = try await QwenService.shared.analyze(
                            word: resolvedWord.spanish,
                            targetLanguage: resolvedWord.meaningLanguage
                        )
                        _ = await MainActor.run {
                            store.applyAnalysis(for: resolvedWord.id, analysis: analysis)
                        }
                        resolvedWord = await MainActor.run {
                            store.words.first { $0.id == resolvedWord.id } ?? resolvedWord
                        }
                    }
                    if mode.includesTips {
                        let tips = try await QwenService.shared.generateTips(for: resolvedWord)
                        let normalized = normalizeTipsText(tips.tips)
                        _ = await MainActor.run {
                            store.updateTips(for: resolvedWord.id, tips: normalized)
                        }
                    }
                } catch {
                    _ = await MainActor.run {
                        bulkErrorMessage = error.localizedDescription
                        showBulkError = true
                        isBulkUpdating = false
                    }
                    return
                }
                _ = await MainActor.run {
                    bulkProgress += 1
                }
            }

            _ = await MainActor.run {
                isBulkUpdating = false
            }
        }
    }

}

private struct SelectedUpdateView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var selectedIds: Set<UUID> = []
    @State private var isUpdating = false
    @State private var progress = 0
    @State private var total = 0
    @State private var showError = false
    @State private var errorMessage = ""

    private var sortedWords: [WordEntry] {
        store.words.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if isUpdating {
                Section {
                    ProgressView(value: Double(progress), total: Double(max(total, 1)))
                    Text("已更新 \(progress)/\(total)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(sortedWords) { word in
                Button {
                    toggleSelection(word.id)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        WordRowView(word: word)
                        Image(systemName: selectedIds.contains(word.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedIds.contains(word.id) ? .blue : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(isUpdating)
        .navigationTitle("选择单词 \(selectedIds.count)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(BulkUpdateMode.analysis.label) {
                        startSelectedUpdate(.analysis)
                    }
                    Button(BulkUpdateMode.tips.label) {
                        startSelectedUpdate(.tips)
                    }
                    Button(BulkUpdateMode.both.label) {
                        startSelectedUpdate(.both)
                    }
                } label: {
                    Label("更新所选", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isUpdating || selectedIds.isEmpty)
            }
        }
        .alert("批量更新失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func startSelectedUpdate(_ mode: BulkUpdateMode) {
        guard !isUpdating else { return }
        let words = store.words.filter { selectedIds.contains($0.id) }
        guard !words.isEmpty else { return }
        Task {
            _ = await MainActor.run {
                isUpdating = true
                progress = 0
                total = words.count
                errorMessage = ""
                showError = false
            }

            for word in words {
                do {
                    var resolvedWord = word
                    if mode.includesAnalysis {
                        let analysis = try await QwenService.shared.analyze(
                            word: resolvedWord.spanish,
                            targetLanguage: resolvedWord.meaningLanguage
                        )
                        _ = await MainActor.run {
                            store.applyAnalysis(for: resolvedWord.id, analysis: analysis)
                        }
                        resolvedWord = await MainActor.run {
                            store.words.first { $0.id == resolvedWord.id } ?? resolvedWord
                        }
                    }
                    if mode.includesTips {
                        let tips = try await QwenService.shared.generateTips(for: resolvedWord)
                        let normalized = normalizeTipsText(tips.tips)
                        _ = await MainActor.run {
                            store.updateTips(for: resolvedWord.id, tips: normalized)
                        }
                    }
                } catch {
                    _ = await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                        isUpdating = false
                    }
                    return
                }
                _ = await MainActor.run {
                    progress += 1
                }
            }

            _ = await MainActor.run {
                isUpdating = false
            }
        }
    }
}

private struct WordRowView: View {
    let word: WordEntry

    private var dueLabel: String {
        if word.lastReviewedAt == nil {
            return "未开始"
        }
        if word.nextReviewDate <= Date() {
            return "待复习"
        }
        return DateFormatters.shortDateTime.string(from: word.nextReviewDate)
    }

    private var isDueForReview: Bool {
        word.lastReviewedAt != nil && word.nextReviewDate <= Date()
    }

    var body: some View {
        let status = word.masteryStatus

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(word.spanish)
                    .font(.headline)
                if word.partOfSpeech != .other {
                    Text(word.partOfSpeechLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(status.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor(status).opacity(0.15))
                    .foregroundStyle(statusColor(status))
                    .clipShape(Capsule())
            }
            MeaningText(text: word.meaningText, language: word.meaningLanguage, style: .body)
                .foregroundStyle(.secondary)
            Text("下次复习：\(dueLabel)")
                .font(.caption)
                .foregroundStyle(isDueForReview ? .orange : .secondary)
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: MasteryStatus) -> Color {
        switch status {
        case .notStarted:
            return .gray
        case .learning:
            return .red
        case .familiar:
            return .blue
        case .mastered:
            return .green
        case .fuzzy:
            return .orange
        }
    }
}

struct WordDetailView: View {
    @EnvironmentObject private var store: StudyStore
    let wordID: UUID
    @State private var isPresentingEdit = false

    private var word: WordEntry? {
        store.words.first { $0.id == wordID } 
    }

    var body: some View {
        List {
            if let word {
                Section("单词") {
                    LabeledContent("西班牙语", value: word.spanish)
                    LabeledContent {
                        MeaningText(text: word.meaningText, language: word.meaningLanguage, style: .body)
                    } label: {
                        Text(word.meaningLabel)
                    }
                    LabeledContent("词性", value: word.partOfSpeechLabel)
                    LabeledContent("掌握度", value: word.masteryStatus.rawValue)
                    LabeledContent("下一次复习", value: DateFormatters.shortDateTime.string(from: word.nextReviewDate))
                }

                if word.conjugation != nil {
                    Section("动词变位") {
                        if let conjugation = word.conjugation {
                            ConjugationRow(subject: "yo", value: conjugation.yo)
                            ConjugationRow(subject: "tu", value: conjugation.tu)
                            ConjugationRow(subject: "el/ella", value: conjugation.elElla)
                            ConjugationRow(subject: "nosotros", value: conjugation.nosotros)
                            ConjugationRow(subject: "vosotros", value: conjugation.vosotros)
                            ConjugationRow(subject: "ellos/ellas", value: conjugation.ellosEllas)
                        } else {
                            Text("尚未录入变位。")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if word.nounPlural?.trimmed.isEmpty == false {
                    Section("名词形式") {
                        DetailValueRow(label: "复数", value: word.nounPlural ?? "")
                    }
                }

                if word.adjectiveForms != nil {
                    Section("形容词形式") {
                        let forms = word.adjectiveForms
                        DetailValueRow(label: "阳性单数", value: forms?.masculineSingular ?? "")
                        DetailValueRow(label: "阴性单数", value: forms?.feminineSingular ?? "")
                        DetailValueRow(label: "阳性复数", value: forms?.masculinePlural ?? "")
                        DetailValueRow(label: "阴性复数", value: forms?.femininePlural ?? "")
                    }
                }

                Section("记忆技巧") {
                    if let tips = word.memoryTips?.trimmed, !tips.isEmpty {
                        Text(tips)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("暂无记忆技巧。")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("单词已删除或不存在。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("详情")
        .listStyle(.insetGrouped)
        .toolbar {
            if word != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("编辑") {
                        isPresentingEdit = true
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            if let word {
                EditWordView(word: word)
            }
        }
    }
}

private struct ConjugationRow: View {
    let subject: String
    let value: String

    var body: some View {
        HStack {
            Text(subject)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .foregroundStyle(.primary)
        }
    }
}

private struct DetailValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.trimmed.isEmpty ? "-" : value)
                .foregroundStyle(.primary)
        }
    }
}

private struct TipsEditor: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.trimmed.isEmpty {
                Text("暂无记忆技巧。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            TextEditor(text: $text)
                .frame(minHeight: 80)
                .textInputAutocapitalization(.never)
        }
    }
}

struct AddWordView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var spanish = ""
    @State private var chinese = ""
    @State private var meaningLanguage: MeaningLanguage = .english
    @State private var partOfSpeech: PartOfSpeech = .other
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    @State private var yo = ""
    @State private var tu = ""
    @State private var elElla = ""
    @State private var nosotros = ""
    @State private var vosotros = ""
    @State private var ellosEllas = ""
    @State private var nounPlural = ""
    @State private var adjectiveMasculineSingular = ""
    @State private var adjectiveFeminineSingular = ""
    @State private var adjectiveMasculinePlural = ""
    @State private var adjectiveFemininePlural = ""
    @State private var memoryTips = ""
    @State private var isGeneratingTips = false
    @State private var tipsError: String?

    private var trimmedSpanish: String {
        spanish.trimmed
    }

    private var trimmedMeaning: String {
        chinese.trimmed
    }

    private var trimmedMemoryTips: String {
        memoryTips.trimmed
    }

    private var isDuplicateSpanish: Bool {
        let key = trimmedSpanish.normalizedAnswer
        guard !key.isEmpty else { return false }
        return store.words.contains { $0.matchesSpanishVariant(trimmedSpanish) }
    }

    private var canSave: Bool {
        !trimmedSpanish.isEmpty && !isDuplicateSpanish
    }

    private var showVerbForms: Bool {
        partOfSpeech == .verb || hasConjugation
    }

    private var showNounForms: Bool {
        partOfSpeech == .noun || !nounPlural.trimmed.isEmpty
    }

    private var showAdjectiveForms: Bool {
        partOfSpeech == .adjective || hasAdjectiveForms
    }

    private var hasConjugation: Bool {
        [yo, tu, elElla, nosotros, vosotros, ellosEllas].contains { !$0.trimmed.isEmpty }
    }

    private var hasAdjectiveForms: Bool {
        [adjectiveMasculineSingular, adjectiveFeminineSingular, adjectiveMasculinePlural, adjectiveFemininePlural]
            .contains { !$0.trimmed.isEmpty }
    }

    private var meaningPlaceholder: String {
        meaningLanguage == .chinese ? "中文释义" : "英文释义"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("西班牙语单词", text: $spanish)
                        .textInputAutocapitalization(.never)
                    Button {
                        runAnalysis()
                    } label: {
                        Label("智能解析", systemImage: "sparkles")
                    }
                    .disabled(trimmedSpanish.isEmpty || isAnalyzing)
                    if isAnalyzing {
                        ProgressView("正在解析...")
                    }
                    if let analysisError {
                        Text(analysisError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if isDuplicateSpanish {
                        Text("该西班牙语或其变形已添加，不能重复录入。")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Picker("释义语言", selection: $meaningLanguage) {
                        ForEach(MeaningLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField(meaningPlaceholder, text: $chinese)
                        .textInputAutocapitalization(.never)
                }

                Section("词性") {
                    Picker("词性", selection: $partOfSpeech) {
                        ForEach(PartOfSpeech.allCases) { part in
                            Text(part.displayName).tag(part)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if showVerbForms {
                    Section("动词变位") {
                        ConjugationInputRow(subject: "yo", text: $yo)
                        ConjugationInputRow(subject: "tu", text: $tu)
                        ConjugationInputRow(subject: "el/ella", text: $elElla)
                        ConjugationInputRow(subject: "nosotros", text: $nosotros)
                        ConjugationInputRow(subject: "vosotros", text: $vosotros)
                        ConjugationInputRow(subject: "ellos/ellas", text: $ellosEllas)
                    }
                }

                if showNounForms {
                    Section("名词形式") {
                        TextField("复数形式", text: $nounPlural)
                            .textInputAutocapitalization(.never)
                    }
                }

                if showAdjectiveForms {
                    Section("形容词形式") {
                        TextField("阳性单数", text: $adjectiveMasculineSingular)
                            .textInputAutocapitalization(.never)
                        TextField("阴性单数", text: $adjectiveFeminineSingular)
                            .textInputAutocapitalization(.never)
                        TextField("阳性复数", text: $adjectiveMasculinePlural)
                            .textInputAutocapitalization(.never)
                        TextField("阴性复数", text: $adjectiveFemininePlural)
                            .textInputAutocapitalization(.never)
                    }
                }

                Section("记忆技巧") {
                    Button {
                        generateTips()
                    } label: {
                        Label("生成记忆技巧", systemImage: "sparkles")
                    }
                    .disabled(trimmedSpanish.isEmpty || isGeneratingTips)
                    if isGeneratingTips {
                        ProgressView("正在生成...")
                    }
                    if let tipsError {
                        Text(tipsError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    TipsEditor(text: $memoryTips)
                }
            }
            .navigationTitle("新增生词")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let conjugation = hasConjugation ? Conjugation(
                            yo: yo.trimmed,
                            tu: tu.trimmed,
                            elElla: elElla.trimmed,
                            nosotros: nosotros.trimmed,
                            vosotros: vosotros.trimmed,
                            ellosEllas: ellosEllas.trimmed
                        ) : nil
                        let nounPluralValue = nounPlural.trimmed.isEmpty ? nil : nounPlural.trimmed
                        let adjectiveValue = hasAdjectiveForms ? AdjectiveForms(
                            masculineSingular: adjectiveMasculineSingular.trimmed,
                            feminineSingular: adjectiveFeminineSingular.trimmed,
                            masculinePlural: adjectiveMasculinePlural.trimmed,
                            femininePlural: adjectiveFemininePlural.trimmed
                        ) : nil
                        store.addWord(
                            spanish: trimmedSpanish,
                            chinese: trimmedMeaning,
                            meaningLanguage: meaningLanguage,
                            partOfSpeech: partOfSpeech,
                            conjugation: conjugation,
                            nounPlural: nounPluralValue,
                            adjectiveForms: adjectiveValue,
                            memoryTips: trimmedMemoryTips.isEmpty ? nil : trimmedMemoryTips
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func runAnalysis() {
        guard !trimmedSpanish.isEmpty else { return }
        isAnalyzing = true
        analysisError = nil
        tipsError = nil
        Task {
            do {
                let analysis = try await QwenService.shared.analyze(
                    word: trimmedSpanish,
                    targetLanguage: meaningLanguage
                )
                _ = await MainActor.run {
                    apply(analysis: analysis)
                    isAnalyzing = false
                }
                await generateTipsFromCurrentWord()
            } catch {
                _ = await MainActor.run {
                    analysisError = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    @MainActor
    private func generateTipsFromCurrentWord() async {
        guard !trimmedSpanish.isEmpty else { return }
        tipsError = nil
        isGeneratingTips = true
        let word = buildTipsWord()
        do {
            let tips = try await QwenService.shared.generateTips(for: word)
            memoryTips = normalizeTips(tips.tips)
            isGeneratingTips = false
        } catch {
            tipsError = error.localizedDescription
            isGeneratingTips = false
        }
    }

    private func generateTips() {
        Task { @MainActor in
            await generateTipsFromCurrentWord()
        }
    }

    private func buildTipsWord() -> WordEntry {
        let conjugation = hasConjugation ? Conjugation(
            yo: yo.trimmed,
            tu: tu.trimmed,
            elElla: elElla.trimmed,
            nosotros: nosotros.trimmed,
            vosotros: vosotros.trimmed,
            ellosEllas: ellosEllas.trimmed
        ) : nil
        let nounPluralValue = nounPlural.trimmed.isEmpty ? nil : nounPlural.trimmed
        let adjectiveValue = hasAdjectiveForms ? AdjectiveForms(
            masculineSingular: adjectiveMasculineSingular.trimmed,
            feminineSingular: adjectiveFeminineSingular.trimmed,
            masculinePlural: adjectiveMasculinePlural.trimmed,
            femininePlural: adjectiveFemininePlural.trimmed
        ) : nil
        let now = Date()
        return WordEntry(
            id: UUID(),
            spanish: trimmedSpanish,
            chinese: trimmedMeaning,
            partOfSpeech: partOfSpeech,
            conjugation: conjugation,
            nounPlural: nounPluralValue,
            adjectiveForms: adjectiveValue,
            createdAt: now,
            reviewStage: 0,
            nextReviewDate: ReviewSchedule.nextDate(from: now, stage: 0),
            meaningLanguage: meaningLanguage
        )
    }

    private func normalizeTips(_ text: String) -> String {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return "" }
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("tips") {
            let remainder = trimmed.dropFirst(4)
            let content = remainder.drop(while: { $0 == ":" || $0 == "：" || $0 == " " })
            let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "Tips:" : "Tips: \(normalized)"
        }
        return "Tips: \(trimmed)"
    }

    private func apply(analysis: WordAnalysis) {
        let normalizedLanguage = analysis.language.lowercased()
        if normalizedLanguage == "en" {
            meaningLanguage = .english
        } else if normalizedLanguage == "zh" {
            meaningLanguage = .chinese
        }
        if let lemma = analysis.lemma?.trimmed, !lemma.isEmpty {
            spanish = lemma
        }
        chinese = analysis.meaning

        let resolvedPart = resolvePartOfSpeech(analysis)
        partOfSpeech = resolvedPart

        if let conjugation = analysis.conjugation {
            yo = conjugation.yo
            tu = conjugation.tu
            elElla = conjugation.elElla
            nosotros = conjugation.nosotros
            vosotros = conjugation.vosotros
            ellosEllas = conjugation.ellosEllas
        } else {
            yo = ""
            tu = ""
            elElla = ""
            nosotros = ""
            vosotros = ""
            ellosEllas = ""
        }

        if let plural = analysis.nounPlural?.trimmed, !plural.isEmpty {
            nounPlural = plural
        } else {
            nounPlural = ""
        }

        if let forms = analysis.adjectiveForms {
            adjectiveMasculineSingular = forms.masculineSingular
            adjectiveFeminineSingular = forms.feminineSingular
            adjectiveMasculinePlural = forms.masculinePlural
            adjectiveFemininePlural = forms.femininePlural
        } else {
            adjectiveMasculineSingular = ""
            adjectiveFeminineSingular = ""
            adjectiveMasculinePlural = ""
            adjectiveFemininePlural = ""
        }
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
}

struct EditWordView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    let wordID: UUID
    @State private var spanish: String
    @State private var meaning: String
    @State private var meaningLanguage: MeaningLanguage
    @State private var partOfSpeech: PartOfSpeech
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    @State private var yo: String
    @State private var tu: String
    @State private var elElla: String
    @State private var nosotros: String
    @State private var vosotros: String
    @State private var ellosEllas: String
    @State private var nounPlural: String
    @State private var adjectiveMasculineSingular: String
    @State private var adjectiveFeminineSingular: String
    @State private var adjectiveMasculinePlural: String
    @State private var adjectiveFemininePlural: String
    @State private var memoryTips: String
    @State private var isGeneratingTips = false
    @State private var tipsError: String?

    init(word: WordEntry) {
        wordID = word.id
        _spanish = State(initialValue: word.spanish)
        _meaning = State(initialValue: word.meaningText)
        _meaningLanguage = State(initialValue: word.meaningLanguage)
        _partOfSpeech = State(initialValue: word.partOfSpeech)

        let conjugation = word.conjugation
        _yo = State(initialValue: conjugation?.yo ?? "")
        _tu = State(initialValue: conjugation?.tu ?? "")
        _elElla = State(initialValue: conjugation?.elElla ?? "")
        _nosotros = State(initialValue: conjugation?.nosotros ?? "")
        _vosotros = State(initialValue: conjugation?.vosotros ?? "")
        _ellosEllas = State(initialValue: conjugation?.ellosEllas ?? "")
        _nounPlural = State(initialValue: word.nounPlural ?? "")
        _adjectiveMasculineSingular = State(initialValue: word.adjectiveForms?.masculineSingular ?? "")
        _adjectiveFeminineSingular = State(initialValue: word.adjectiveForms?.feminineSingular ?? "")
        _adjectiveMasculinePlural = State(initialValue: word.adjectiveForms?.masculinePlural ?? "")
        _adjectiveFemininePlural = State(initialValue: word.adjectiveForms?.femininePlural ?? "")
        _memoryTips = State(initialValue: word.memoryTips ?? "")
    }

    private var trimmedSpanish: String {
        spanish.trimmed
    }

    private var trimmedMeaning: String {
        meaning.trimmed
    }

    private var trimmedMemoryTips: String {
        memoryTips.trimmed
    }

    private var isDuplicateSpanish: Bool {
        let key = trimmedSpanish.normalizedAnswer
        guard !key.isEmpty else { return false }
        return store.words.contains { $0.id != wordID && $0.matchesSpanishVariant(trimmedSpanish) }
    }

    private var canSave: Bool {
        !trimmedSpanish.isEmpty && !trimmedMeaning.isEmpty && !isDuplicateSpanish
    }

    private var showVerbForms: Bool {
        partOfSpeech == .verb || hasConjugation
    }

    private var showNounForms: Bool {
        partOfSpeech == .noun || !nounPlural.trimmed.isEmpty
    }

    private var showAdjectiveForms: Bool {
        partOfSpeech == .adjective || hasAdjectiveForms
    }

    private var hasConjugation: Bool {
        [yo, tu, elElla, nosotros, vosotros, ellosEllas].contains { !$0.trimmed.isEmpty }
    }

    private var hasAdjectiveForms: Bool {
        [adjectiveMasculineSingular, adjectiveFeminineSingular, adjectiveMasculinePlural, adjectiveFemininePlural]
            .contains { !$0.trimmed.isEmpty }
    }

    private var meaningPlaceholder: String {
        meaningLanguage == .chinese ? "中文释义" : "英文释义"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("西班牙语单词", text: $spanish)
                        .textInputAutocapitalization(.never)
                    Button {
                        runAnalysis()
                    } label: {
                        Label("智能解析", systemImage: "sparkles")
                    }
                    .disabled(trimmedSpanish.isEmpty || isAnalyzing)
                    if isAnalyzing {
                        ProgressView("正在解析...")
                    }
                    if let analysisError {
                        Text(analysisError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if isDuplicateSpanish {
                        Text("该西班牙语或其变形已存在，不能重复。")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Picker("释义语言", selection: $meaningLanguage) {
                        ForEach(MeaningLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField(meaningPlaceholder, text: $meaning)
                        .textInputAutocapitalization(.never)
                }

                Section("词性") {
                    Picker("词性", selection: $partOfSpeech) {
                        ForEach(PartOfSpeech.allCases) { part in
                            Text(part.displayName).tag(part)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if showVerbForms {
                    Section("动词变位") {
                        ConjugationInputRow(subject: "yo", text: $yo)
                        ConjugationInputRow(subject: "tu", text: $tu)
                        ConjugationInputRow(subject: "el/ella", text: $elElla)
                        ConjugationInputRow(subject: "nosotros", text: $nosotros)
                        ConjugationInputRow(subject: "vosotros", text: $vosotros)
                        ConjugationInputRow(subject: "ellos/ellas", text: $ellosEllas)
                    }
                }

                if showNounForms {
                    Section("名词形式") {
                        TextField("复数形式", text: $nounPlural)
                            .textInputAutocapitalization(.never)
                    }
                }

                if showAdjectiveForms {
                    Section("形容词形式") {
                        TextField("阳性单数", text: $adjectiveMasculineSingular)
                            .textInputAutocapitalization(.never)
                        TextField("阴性单数", text: $adjectiveFeminineSingular)
                            .textInputAutocapitalization(.never)
                        TextField("阳性复数", text: $adjectiveMasculinePlural)
                            .textInputAutocapitalization(.never)
                        TextField("阴性复数", text: $adjectiveFemininePlural)
                            .textInputAutocapitalization(.never)
                    }
                }

                Section("记忆技巧") {
                    Button {
                        generateTips()
                    } label: {
                        Label("生成记忆技巧", systemImage: "sparkles")
                    }
                    .disabled(trimmedSpanish.isEmpty || isGeneratingTips)
                    if isGeneratingTips {
                        ProgressView("正在生成...")
                    }
                    if let tipsError {
                        Text(tipsError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    TipsEditor(text: $memoryTips)
                }
            }
            .navigationTitle("编辑生词")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let conjugation = hasConjugation ? Conjugation(
                            yo: yo.trimmed,
                            tu: tu.trimmed,
                            elElla: elElla.trimmed,
                            nosotros: nosotros.trimmed,
                            vosotros: vosotros.trimmed,
                            ellosEllas: ellosEllas.trimmed
                        ) : nil
                        let nounPluralValue = nounPlural.trimmed.isEmpty ? nil : nounPlural.trimmed
                        let adjectiveValue = hasAdjectiveForms ? AdjectiveForms(
                            masculineSingular: adjectiveMasculineSingular.trimmed,
                            feminineSingular: adjectiveFeminineSingular.trimmed,
                            masculinePlural: adjectiveMasculinePlural.trimmed,
                            femininePlural: adjectiveFemininePlural.trimmed
                        ) : nil
                        store.updateWord(
                            id: wordID,
                            spanish: trimmedSpanish,
                            meaning: trimmedMeaning,
                            meaningLanguage: meaningLanguage,
                            partOfSpeech: partOfSpeech,
                            conjugation: conjugation,
                            nounPlural: nounPluralValue,
                            adjectiveForms: adjectiveValue
                        )
                        store.updateTips(for: wordID, tips: trimmedMemoryTips)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func runAnalysis() {
        guard !trimmedSpanish.isEmpty else { return }
        isAnalyzing = true
        analysisError = nil
        tipsError = nil
        Task {
            do {
                let analysis = try await QwenService.shared.analyze(
                    word: trimmedSpanish,
                    targetLanguage: meaningLanguage
                )
                _ = await MainActor.run {
                    apply(analysis: analysis)
                    isAnalyzing = false
                }
                await generateTipsFromCurrentWord()
            } catch {
                _ = await MainActor.run {
                    analysisError = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    @MainActor
    private func generateTipsFromCurrentWord() async {
        guard !trimmedSpanish.isEmpty else { return }
        tipsError = nil
        isGeneratingTips = true
        let word = buildTipsWord()
        do {
            let tips = try await QwenService.shared.generateTips(for: word)
            memoryTips = normalizeTips(tips.tips)
            isGeneratingTips = false
        } catch {
            tipsError = error.localizedDescription
            isGeneratingTips = false
        }
    }

    private func generateTips() {
        Task { @MainActor in
            await generateTipsFromCurrentWord()
        }
    }

    private func buildTipsWord() -> WordEntry {
        let conjugation = hasConjugation ? Conjugation(
            yo: yo.trimmed,
            tu: tu.trimmed,
            elElla: elElla.trimmed,
            nosotros: nosotros.trimmed,
            vosotros: vosotros.trimmed,
            ellosEllas: ellosEllas.trimmed
        ) : nil
        let nounPluralValue = nounPlural.trimmed.isEmpty ? nil : nounPlural.trimmed
        let adjectiveValue = hasAdjectiveForms ? AdjectiveForms(
            masculineSingular: adjectiveMasculineSingular.trimmed,
            feminineSingular: adjectiveFeminineSingular.trimmed,
            masculinePlural: adjectiveMasculinePlural.trimmed,
            femininePlural: adjectiveFemininePlural.trimmed
        ) : nil
        let now = Date()
        return WordEntry(
            id: wordID,
            spanish: trimmedSpanish,
            chinese: trimmedMeaning,
            partOfSpeech: partOfSpeech,
            conjugation: conjugation,
            nounPlural: nounPluralValue,
            adjectiveForms: adjectiveValue,
            createdAt: now,
            reviewStage: 0,
            nextReviewDate: ReviewSchedule.nextDate(from: now, stage: 0),
            meaningLanguage: meaningLanguage
        )
    }

    private func normalizeTips(_ text: String) -> String {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return "" }
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("tips") {
            let remainder = trimmed.dropFirst(4)
            let content = remainder.drop(while: { $0 == ":" || $0 == "：" || $0 == " " })
            let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "Tips:" : "Tips: \(normalized)"
        }
        return "Tips: \(trimmed)"
    }

    private func apply(analysis: WordAnalysis) {
        let normalizedLanguage = analysis.language.lowercased()
        if normalizedLanguage == "en" {
            meaningLanguage = .english
        } else if normalizedLanguage == "zh" {
            meaningLanguage = .chinese
        }
        if let lemma = analysis.lemma?.trimmed, !lemma.isEmpty {
            spanish = lemma
        }
        meaning = analysis.meaning

        let resolvedPart = resolvePartOfSpeech(analysis)
        partOfSpeech = resolvedPart

        if let conjugation = analysis.conjugation {
            yo = conjugation.yo
            tu = conjugation.tu
            elElla = conjugation.elElla
            nosotros = conjugation.nosotros
            vosotros = conjugation.vosotros
            ellosEllas = conjugation.ellosEllas
        } else {
            yo = ""
            tu = ""
            elElla = ""
            nosotros = ""
            vosotros = ""
            ellosEllas = ""
        }

        if let plural = analysis.nounPlural?.trimmed, !plural.isEmpty {
            nounPlural = plural
        } else {
            nounPlural = ""
        }

        if let forms = analysis.adjectiveForms {
            adjectiveMasculineSingular = forms.masculineSingular
            adjectiveFeminineSingular = forms.feminineSingular
            adjectiveMasculinePlural = forms.masculinePlural
            adjectiveFemininePlural = forms.femininePlural
        } else {
            adjectiveMasculineSingular = ""
            adjectiveFeminineSingular = ""
            adjectiveMasculinePlural = ""
            adjectiveFemininePlural = ""
        }
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
}

private struct ConjugationInputRow: View {
    let subject: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(subject)
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            TextField("变位", text: $text)
                .textInputAutocapitalization(.never)
        }
    }
}

#Preview {
    VocabularyListView()
        .environmentObject(StudyStore())
}
