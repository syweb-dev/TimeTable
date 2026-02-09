//
//  ContentView.swift
//  TimeTable
//
//  Created by sanyou on 2/9/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var store = AppStore()
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView()
                .tabItem { Label("tab_schedule", systemImage: "calendar") }
                .tag(AppTab.today)
            ImportView()
                .tabItem { Label("tab_import", systemImage: "square.and.arrow.down") }
                .tag(AppTab.importTab)
            TemplatesView()
                .tabItem { Label("tab_templates", systemImage: "square.grid.2x2") }
                .tag(AppTab.templates)
            SettingsView()
                .tabItem { Label("tab_settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .environmentObject(store)
        .environment(\.locale, appLanguage.locale ?? Locale.current)
        .tint(AppTheme.blue)
        .preferredColorScheme(.light)
    }
}

// MARK: - Store

final class AppStore: ObservableObject {
    @Published var todayBlocks: [Block] = [] {
        didSet { Persistence.save(store: self) }
    }
    @Published var templates: [Template] = Template.seed {
        didSet { Persistence.save(store: self) }
    }
    @Published var lastImportPreview: [Block] = []
    @Published var lastImportErrors: [String] = []
    @Published var selectedTab: AppTab = .today

    init() {
        Persistence.load(into: self)
    }

    func applyTemplate(_ template: Template) {
        todayBlocks = template.blocks
    }

    func importBlocks(_ blocks: [Block]) {
        todayBlocks = blocks
    }

    func addBlock(_ block: Block) {
        todayBlocks.append(Parser.normalize(block))
    }

    func updateBlock(_ block: Block) {
        if let index = todayBlocks.firstIndex(where: { $0.id == block.id }) {
            todayBlocks[index] = Parser.normalize(block)
        }
    }

    func deleteBlock(_ block: Block) {
        todayBlocks.removeAll { $0.id == block.id }
    }

    func addTemplate(title: String, blocks: [Block]) {
        templates.insert(Template(id: UUID(), title: title, blocks: blocks), at: 0)
    }

    func updateTemplate(_ template: Template) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        }
    }

    func deleteTemplate(_ template: Template) {
        templates.removeAll { $0.id == template.id }
    }
}

// MARK: - Models

struct Block: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var start: String
    var end: String?
    var title: String
    var durationText: String?
    var note: String
    var tag: String?
    var icon: String?
    var isOvernight: Bool
    var error: String?
    var startMinutes: Int?

    var timeRange: String {
        if let end {
            let nextDay = L10n.t("next_day")
            return isOvernight ? "\(start) → \(nextDay) \(end)" : "\(start) - \(end)"
        }
        return start
    }
}

struct Template: Identifiable, Codable {
    let id: UUID
    var title: String
    var blocks: [Block]

    static var seed: [Template] {
        [
            Template(
                id: UUID(),
                title: L10n.t("template_workday"),
                blocks: [
                    Block(start: "08:00", end: "09:00", title: L10n.t("sample_meeting"), durationText: nil, note: "", tag: L10n.t("sample_tag_work"), icon: "🗓️", isOvernight: false, error: nil, startMinutes: 480),
                    Block(start: "10:00", end: "12:00", title: L10n.t("sample_focus_work"), durationText: nil, note: "", tag: L10n.t("sample_tag_work"), icon: "💻", isOvernight: false, error: nil, startMinutes: 600),
                    Block(start: "13:00", end: "14:00", title: L10n.t("sample_lunch"), durationText: nil, note: "", tag: L10n.t("sample_tag_health"), icon: "🥗", isOvernight: false, error: nil, startMinutes: 780)
                ]
            ),
            Template(
                id: UUID(),
                title: L10n.t("template_weekend"),
                blocks: [
                    Block(start: "09:00", end: "10:00", title: L10n.t("sample_exercise"), durationText: nil, note: "", tag: L10n.t("sample_tag_health"), icon: "🏃", isOvernight: false, error: nil, startMinutes: 540),
                    Block(start: "11:00", end: "12:00", title: L10n.t("sample_chores"), durationText: nil, note: "", tag: L10n.t("sample_tag_home"), icon: "🧹", isOvernight: false, error: nil, startMinutes: 660),
                    Block(start: "14:00", end: "15:00", title: L10n.t("sample_relax"), durationText: nil, note: "", tag: L10n.t("sample_tag_life"), icon: "🌿", isOvernight: false, error: nil, startMinutes: 840)
                ]
            ),
            Template(
                id: UUID(),
                title: L10n.t("template_exam"),
                blocks: [
                    Block(start: "09:00", end: "10:00", title: L10n.t("sample_study"), durationText: nil, note: "", tag: L10n.t("sample_tag_study"), icon: "📚", isOvernight: false, error: nil, startMinutes: 540),
                    Block(start: "12:00", end: "13:00", title: L10n.t("sample_practice"), durationText: nil, note: "", tag: L10n.t("sample_tag_study"), icon: "📝", isOvernight: false, error: nil, startMinutes: 720),
                    Block(start: "15:00", end: "16:00", title: L10n.t("sample_review"), durationText: nil, note: "", tag: L10n.t("sample_tag_study"), icon: "✅", isOvernight: false, error: nil, startMinutes: 900)
                ]
            )
        ]
    }
}

struct PersistedStore: Codable {
    var todayBlocks: [Block]
    var templates: [Template]
}

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    @State private var selectedBlock: Block?

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    dateRow
                    sectionTitle
            if store.todayBlocks.isEmpty {
                EmptyStateView()
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedBlocks) { block in
                        ScheduleCard(block: block)
                            .onTapGesture {
                                selectedBlock = block
                            }
                    }
                }
            }
                    Spacer(minLength: 140)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            bottomBar
        }
        .sheet(isPresented: $showAdd) {
            EditBlockView(
                block: Block(start: "09:00", end: nil, title: "", durationText: nil, note: "", tag: nil, icon: nil, isOvernight: false, error: nil, startMinutes: 540),
                onSave: { newBlock in
                    store.addBlock(newBlock)
                },
                onDelete: nil
            )
            .presentationDetents([.large])
        }
        .sheet(item: $selectedBlock) { block in
            EditBlockView(
                block: block,
                onSave: { updated in
                    store.updateBlock(updated)
                },
                onDelete: { toDelete in
                    store.deleteBlock(toDelete)
                }
            )
            .presentationDetents([.large])
        }
    }

    private var sortedBlocks: [Block] {
        store.todayBlocks.sorted { ($0.startMinutes ?? 0) < ($1.startMinutes ?? 0) }
    }

    private var header: some View {
        HStack {
            Text("app_title")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
            Spacer()
            Button(action: { store.selectedTab = .templates }) {
                Text("button_templates")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.softCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.softBorder, lineWidth: 1))
            }
        }
    }

    private var dateRow: some View {
        Text("date_sample")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.navy.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(AppTheme.softBorder), alignment: .bottom)
    }

    private var sectionTitle: some View {
        Text("section_today")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(AppTheme.navy)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottomBar: some View {
        HStack(spacing: 18) {
            Button(action: { store.selectedTab = .importTab }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("button_import")
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.softCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.softBorder, lineWidth: 1))
            }

            Button(action: { showAdd = true }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [AppTheme.blue, AppTheme.blueDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 70, height: 70)
                        .shadow(color: AppTheme.blue.opacity(0.35), radius: 10, x: 0, y: 8)
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .offset(y: -12)

            Button(action: { store.selectedTab = .importTab }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("button_import")
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.softCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.softBorder, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [AppTheme.backgroundColor.opacity(0.01), AppTheme.backgroundColor], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("empty_title")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
            Text("empty_subtitle")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.navy.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 4)
    }
}

struct ScheduleCard: View {
    let block: Block

    var body: some View {
        let displayTitle = block.title.isEmpty ? L10n.t("untitled") : block.title
        HStack(spacing: 14) {
            Text(block.timeRange)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
                .frame(width: 140, alignment: .leading)
            Text(displayTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
            Spacer()
            if let icon = block.icon {
                Text(icon).font(.system(size: 20))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 4)
    }
}

// MARK: - Import

struct ImportView: View {
    @EnvironmentObject private var store: AppStore
    @State private var mode: ImportMode = .markdown
    @State private var inputText: String = ""
    @State private var autoSaveTemplate = true
    @FocusState private var isEditing: Bool

    var body: some View {
        AppTheme.background.ignoresSafeArea().overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Text("app_title")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppTheme.navy)

                    Picker("import_mode_title", selection: $mode) {
                        Text("import_mode_markdown").tag(ImportMode.markdown)
                        Text("import_mode_line").tag(ImportMode.lineText)
                    }
                    .pickerStyle(.segmented)

                    textArea
                    Button(action: parseInput) {
                        Text("button_parse_preview")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.blueDark)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text("hint_parse_then_import")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.navy.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    previewSection

                    Toggle("toggle_save_template", isOn: $autoSaveTemplate)
                        .font(.system(size: 14, weight: .semibold))
                        .toggleStyle(SwitchToggleStyle(tint: AppTheme.blue))

                    Button(action: confirmImport) {
                        Text("button_confirm_import")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 6)

                    guideSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("button_done") {
                    isEditing = false
                }
            }
        }
    }

    private var textArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $inputText)
                .frame(height: 180)
                .padding(12)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.softBorder, lineWidth: 1))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppTheme.navy)
                .tint(AppTheme.blue)
                .scrollContentBackground(.hidden)
                .focused($isEditing)

            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(mode == .markdown ? "sample_markdown" : "sample_lines")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(AppTheme.navy.opacity(0.35))
                    .padding(16)
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("section_preview")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.navy)

            if store.lastImportPreview.isEmpty {
                Text("preview_placeholder")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.navy.opacity(0.6))
            } else {
                VStack(spacing: 10) {
                    ForEach(store.lastImportPreview) { block in
                        PreviewRow(block: block)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("guide_title")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
            Text(mode == .markdown ? "guide_markdown" : "guide_lines")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.navy.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.softBorder, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func parseInput() {
        let blocks = Parser.parse(text: inputText, mode: mode)
        store.lastImportPreview = blocks
        store.lastImportErrors = blocks.compactMap { $0.error }
    }

    private func confirmImport() {
        let valid = store.lastImportPreview.filter { $0.error == nil }
        if !valid.isEmpty {
            store.importBlocks(valid)
            if autoSaveTemplate {
                let title = String(format: L10n.t("template_imported_format"), Self.templateStamp())
                store.addTemplate(title: title, blocks: valid)
            }
        }
        isEditing = false
    }

    private static func templateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}

struct PreviewRow: View {
    let block: Block

    var body: some View {
        HStack {
            Text("\(block.timeRange)  \(block.title)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
            Spacer()
            if block.error != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.danger)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(block.error == nil ? AppTheme.card : AppTheme.danger.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.softBorder, lineWidth: 1))
    }
}

enum ImportMode: Hashable {
    case markdown
    case lineText
}

// MARK: - Templates

struct TemplatesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTemplateId: UUID?
    @State private var editingTemplate: Template?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.top, 6)
                    applyButtonTop
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.bottom, 6)
                }

                Section {
                    ForEach(store.templates) { template in
                        templateCard(template: template, isSelected: template.id == selectedTemplateId)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                selectedTemplateId = template.id
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    editingTemplate = template
                                } label: {
                                    Label("action_edit", systemImage: "pencil")
                                }
                                .tint(AppTheme.blue)

                                Button(role: .destructive) {
                                    store.deleteTemplate(template)
                                } label: {
                                    Label("button_delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .sheet(item: $editingTemplate) { template in
            EditTemplateView(template: template) { updated in
                store.updateTemplate(updated)
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Text("tab_templates")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
            Spacer()
            Color.clear.frame(width: 24)
        }
    }

    private var applyButtonTop: some View {
        Button(action: {
            let selected = store.templates.first { $0.id == selectedTemplateId }
            if let chosen = selected ?? store.templates.first {
                store.applyTemplate(chosen)
            }
        }) {
            Text("button_apply_today")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.blueDark)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    private func templateCard(template: Template, isSelected: Bool) -> some View {
        let visibleBlocks = Array(template.blocks.prefix(2))
        let hasMore = template.blocks.count > 2

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(template.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(String(format: L10n.t("template_time_blocks"), template.blocks.count))
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.navy.opacity(0.6))
            }

            ForEach(visibleBlocks) { block in
                Text("\(block.start) - \(block.title)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.navy.opacity(0.8))
            }
            if hasMore {
                Text("…")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.navy.opacity(0.4))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? AppTheme.blue.opacity(0.6) : AppTheme.softBorder, lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: AppTheme.shadow.opacity(0.7), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("settings_language", selection: $appLanguage) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.titleKey).tag(language)
                        }
                    }
                }

                Section(header: Text("settings_about")) {
                    HStack {
                        Text("settings_version")
                        Spacer()
                        Text(versionText)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("settings_privacy")
                        Spacer()
                        Text("settings_privacy_desc")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("settings_title")
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Edit Template

struct EditTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var template: Template
    var onSave: (Template) -> Void
    @FocusState private var isEditing: Bool

    init(template: Template, onSave: @escaping (Template) -> Void) {
        _template = State(initialValue: template)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("template_edit_title")) {
                    TextField("template_edit_name", text: $template.title)
                        .foregroundStyle(AppTheme.navy)
                        .tint(AppTheme.blue)
                        .focused($isEditing)
                }
                Section(header: Text("template_edit_blocks")) {
                    ForEach($template.blocks) { $block in
                        HStack(spacing: 8) {
                            TextField("09:00", text: $block.start)
                                .frame(width: 70)
                                .foregroundStyle(AppTheme.navy)
                                .tint(AppTheme.blue)
                                .focused($isEditing)
                            Text("-")
                            TextField("10:00", text: Binding(
                                get: { block.end ?? "" },
                                set: { block.end = $0.isEmpty ? nil : $0 }
                            ))
                            .frame(width: 70)
                            .foregroundStyle(AppTheme.navy)
                            .tint(AppTheme.blue)
                            .focused($isEditing)
                            TextField("Title", text: $block.title)
                                .foregroundStyle(AppTheme.navy)
                                .tint(AppTheme.blue)
                                .focused($isEditing)
                            Button(role: .destructive) {
                                template.blocks.removeAll { $0.id == block.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(AppTheme.danger)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button("template_edit_add_block") {
                        template.blocks.append(
                            Block(start: "09:00", end: "10:00", title: L10n.t("new_block"), durationText: nil, note: "", tag: nil, icon: nil, isOvernight: false, error: nil, startMinutes: nil)
                        )
                    }
                }
            }
            .navigationTitle("template_edit_title")
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("template_create_cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("template_create_save") {
                        let normalizedBlocks = template.blocks.map { Parser.normalize($0) }
                        let updated = Template(id: template.id, title: template.title, blocks: normalizedBlocks)
                        onSave(updated)
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("button_done") { isEditing = false }
                }
            }
        }
    }
}

// MARK: - Create Template

struct CreateTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var useToday = true
    var onCreate: (String, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("template_create_title")) {
                    TextField("template_create_placeholder", text: $title)
                }
                Section {
                    Toggle("template_create_use_today", isOn: $useToday)
                }
            }
            .navigationTitle("button_create_template_secondary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("template_create_cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("template_create_save") {
                        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? L10n.t("template_new_default")
                            : title
                        onCreate(finalTitle, useToday)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Block

struct EditBlockView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var block: Block
    var onSave: (Block) -> Void
    var onDelete: ((Block) -> Void)?
    @FocusState private var isEditing: Bool

    init(block: Block, onSave: @escaping (Block) -> Void, onDelete: ((Block) -> Void)?) {
        _block = State(initialValue: block)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Text("edit_title")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
                Spacer()
                Button("button_save") {
                    var trimmed = block
                    if trimmed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        trimmed.title = L10n.t("new_block")
                    }
                    onSave(trimmed)
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.blue)
            }
            .padding(.bottom, 4)

            labeledField("label_title", text: $block.title, placeholder: "placeholder_title")
            timeRow
            labeledField("label_tag", text: Binding(
                get: { block.tag ?? "" },
                set: { block.tag = $0.isEmpty ? nil : $0 }
            ), placeholder: "placeholder_tag")
            labeledField("label_note", text: $block.note, placeholder: "placeholder_note")

            if let onDelete {
                Button(role: .destructive) {
                    onDelete(block)
                    dismiss()
                } label: {
                    Text("button_delete")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.danger.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 12)
            }

            Spacer()
        }
        .padding(20)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("button_done") { isEditing = false }
            }
        }
    }

    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("label_time")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.navy.opacity(0.7))
            HStack(spacing: 12) {
                timePill($block.start)
                Text("-")
                timePill(Binding(
                    get: { block.end ?? "" },
                    set: { block.end = $0.isEmpty ? nil : $0 }
                ))
            }
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.navy.opacity(0.7))
            TextField(LocalizedStringKey(placeholder), text: text)
                .textFieldStyle(.plain)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.softBorder, lineWidth: 1))
                .foregroundStyle(AppTheme.navy)
                .tint(AppTheme.blue)
                .focused($isEditing)
        }
    }

    private func timePill(_ text: Binding<String>) -> some View {
        TextField("09:00", text: text)
            .multilineTextAlignment(.center)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 90, height: 40)
            .background(AppTheme.softCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.softBorder, lineWidth: 1))
            .foregroundStyle(AppTheme.navy)
            .tint(AppTheme.blue)
    }
}

// MARK: - Parser

enum Parser {
    static func parse(text: String, mode: ImportMode) -> [Block] {
        let lines = text.split(whereSeparator: { $0.isNewline }).map { String($0) }
        var rows: [Block] = []

        switch mode {
        case .markdown:
            rows = parseMarkdown(lines: lines)
        case .lineText:
            rows = parseLineText(lines: lines)
        }

        return autoFillEndTimes(rows)
    }

    static func normalize(_ block: Block) -> Block {
        let timeText = block.end == nil ? block.start : "\(block.start)-\(block.end ?? "")"
        let parsed = parseTimeRange(timeText)
        var normalized = block
        normalized.start = parsed.start
        normalized.end = parsed.end
        normalized.isOvernight = parsed.isOvernight
        normalized.error = parsed.error
        normalized.startMinutes = parsed.startMinutes
        return normalized
    }

    private static func parseMarkdown(lines: [String]) -> [Block] {
        var dataLines = lines
        if let headerIndex = lines.firstIndex(where: { $0.contains("|") && ($0.lowercased().contains("time") || $0.contains("时间")) }) {
            dataLines = Array(lines.suffix(from: headerIndex + 1))
        }

        var rows: [Block] = []

        for line in dataLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if isMarkdownSeparatorRow(trimmed) { continue }

            let parts = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if parts.isEmpty { continue }

            let timeText = parts.count > 0 ? parts[0] : ""
            let titleText = parts.count > 1 ? parts[1] : ""
            let durationText = parts.count > 2 ? parts[2] : nil

            if timeText.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil {
                rows.append(buildBlock(timeText: timeText, titleText: titleText, durationText: durationText))
            }
        }

        return rows
    }

    private static func parseLineText(lines: [String]) -> [Block] {
        var rows: [Block] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let parsed = parseLine(trimmed)
            rows.append(parsed)
        }
        return rows
    }

    private static func parseLine(_ line: String) -> Block {
        let timePattern = "(\\d{1,2}:\\d{2}(?:\\s*[AP]M)?)"
        let rangePattern = "\\s*[-–~]\\s*"
        let pattern = "^\\s*(\(timePattern))\(rangePattern)(\(timePattern))\\s*(.*)$"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)

        if let regex,
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) {
            let start = rangeString(line, match.range(at: 1))
            let end = rangeString(line, match.range(at: 2))
            let rest = rangeString(line, match.range(at: 3))
            return buildBlock(timeText: "\(start)-\(end)", titleText: rest, durationText: extractDuration(from: rest))
        }

        if let single = matchSingleTime(line) {
            let remainder = line.replacingOccurrences(of: single, with: "").trimmingCharacters(in: .whitespaces)
            return buildBlock(timeText: single, titleText: remainder, durationText: extractDuration(from: remainder))
        }

        return Block(start: "", end: nil, title: line, durationText: nil, note: "", tag: nil, icon: nil, isOvernight: false, error: L10n.t("error_time_parse"), startMinutes: nil)
    }

    private static func matchSingleTime(_ line: String) -> String? {
        let regex = try? NSRegularExpression(pattern: "\\b\\d{1,2}:\\d{2}(?:\\s*[AP]M)?\\b", options: .caseInsensitive)
        guard let regex, let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) else { return nil }
        return rangeString(line, match.range)
    }

    private static func buildBlock(timeText: String, titleText: String, durationText: String?) -> Block {
        let parsed = parseTimeRange(timeText)
        let title = titleText.trimmingCharacters(in: .whitespaces)
        let (icon, cleanTitle) = splitEmoji(title)

        if let error = parsed.error {
            return Block(start: parsed.start, end: parsed.end, title: cleanTitle.isEmpty ? title : cleanTitle, durationText: durationText, note: "", tag: nil, icon: icon, isOvernight: parsed.isOvernight, error: error, startMinutes: parsed.startMinutes)
        }

        return Block(start: parsed.start, end: parsed.end, title: cleanTitle.isEmpty ? title : cleanTitle, durationText: durationText, note: "", tag: nil, icon: icon, isOvernight: parsed.isOvernight, error: nil, startMinutes: parsed.startMinutes)
    }

    private static func parseTimeRange(_ text: String) -> (start: String, end: String?, isOvernight: Bool, error: String?, startMinutes: Int?) {
        let pieces = text.replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "~", with: "-")
            .split(separator: "-")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        if pieces.isEmpty {
            return ("", nil, false, L10n.t("error_time_parse"), nil)
        }

        let startParse = parseTime(String(pieces[0]))
        if startParse.minutes == nil {
            return (startParse.text, nil, false, L10n.t("error_start_invalid"), nil)
        }

        if pieces.count == 1 || (pieces.count >= 2 && pieces[1].isEmpty) {
            return (startParse.text, nil, false, nil, startParse.minutes)
        }

        let endParse = parseTime(String(pieces[1]))
        if endParse.minutes == nil {
            return (startParse.text, endParse.text, false, L10n.t("error_end_invalid"), startParse.minutes)
        }

        let overnight = (endParse.minutes ?? 0) < (startParse.minutes ?? 0)
        return (startParse.text, endParse.text, overnight, nil, startParse.minutes)
    }

    private static func parseTime(_ raw: String) -> (text: String, minutes: Int?) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ")
        let timePart = String(parts.first ?? "")
        let ampm = parts.count > 1 ? parts[1].uppercased() : nil

        let comps = timePart.split(separator: ":")
        guard comps.count == 2,
              let hourRaw = Int(comps[0]),
              let minute = Int(comps[1]) else {
            return (trimmed, nil)
        }

        var hour = hourRaw
        if let ampm {
            if ampm == "PM" && hour < 12 { hour += 12 }
            if ampm == "AM" && hour == 12 { hour = 0 }
        }

        let normalized = String(format: "%02d:%02d", hour, minute)
        return (normalized, hour * 60 + minute)
    }

    private static func extractDuration(from text: String) -> String? {
        let regex = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?h|\\d+m)", options: .caseInsensitive)
        guard let regex, let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.count)) else { return nil }
        return rangeString(text, match.range)
    }

    private static func splitEmoji(_ text: String) -> (String?, String) {
        guard let first = text.first, first.isEmoji else {
            return (nil, text.trimmingCharacters(in: .whitespaces))
        }
        let icon = String(first)
        let rest = text.dropFirst().trimmingCharacters(in: .whitespaces)
        return (icon, rest)
    }

    private static func isMarkdownSeparatorRow(_ line: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "|-: ")
        return line.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func autoFillEndTimes(_ blocks: [Block]) -> [Block] {
        var result = blocks
        for idx in 0..<result.count {
            if result[idx].end == nil, idx + 1 < result.count {
                let next = result[idx + 1]
                if let nextStart = next.startMinutes {
                    result[idx].end = next.start
                    result[idx].isOvernight = (nextStart < (result[idx].startMinutes ?? 0))
                }
            }
        }
        return result
    }

    private static func rangeString(_ source: String, _ range: NSRange) -> String {
        guard let r = Range(range, in: source) else { return "" }
        return String(source[r])
    }
}

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.first?.properties.isEmojiPresentation ?? false
    }
}

// MARK: - Theme

enum AppTheme {
    static let blue = Color(red: 0.26, green: 0.45, blue: 0.80)
    static let blueDark = Color(red: 0.24, green: 0.33, blue: 0.68)
    static let navy = Color(red: 0.18, green: 0.22, blue: 0.36)
    static let card = Color.white
    static let softCard = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let softBorder = Color(red: 0.88, green: 0.89, blue: 0.92)
    static let danger = Color(red: 0.92, green: 0.35, blue: 0.34)
    static let backgroundColor = Color(red: 0.95, green: 0.96, blue: 0.99)
    static let background = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.97, blue: 1.0),
            Color(red: 0.94, green: 0.95, blue: 0.99)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let shadow = Color.black.opacity(0.08)
}

enum AppTab: Hashable {
    case today
    case importTab
    case templates
    case settings
}

enum AppLanguage: String, CaseIterable, Hashable {
    case system
    case zhHans
    case zhHant
    case en
    case es
    case fr
    case ko

    var locale: Locale? {
        switch self {
        case .system: return nil
        case .zhHans: return Locale(identifier: "zh-Hans")
        case .zhHant: return Locale(identifier: "zh-Hant")
        case .en: return Locale(identifier: "en")
        case .es: return Locale(identifier: "es")
        case .fr: return Locale(identifier: "fr")
        case .ko: return Locale(identifier: "ko")
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: return "language_system"
        case .zhHans: return "language_simplified"
        case .zhHant: return "language_traditional"
        case .en: return "language_english"
        case .es: return "language_spanish"
        case .fr: return "language_french"
        case .ko: return "language_korean"
        }
    }
}

// MARK: - Localization

enum L10n {
    static func t(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

enum Persistence {
    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("timetable-store.json")
    }

    static func save(store: AppStore) {
        let payload = PersistedStore(todayBlocks: store.todayBlocks, templates: store.templates)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Intentionally ignore errors for MVP
        }
    }

    static func load(into store: AppStore) {
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(PersistedStore.self, from: data)
            store.todayBlocks = payload.todayBlocks
            store.templates = payload.templates
        } catch {
            // First launch or invalid data, use defaults
        }
    }
}

#Preview {
    ContentView()
}
