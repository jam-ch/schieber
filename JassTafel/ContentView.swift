import SwiftUI
import SwiftData

// MARK: - Models

enum Spielart: Int, CaseIterable, Identifiable {
    case normal = 1
    case doppelt = 2
    case obeabe = 3
    case undeufe = 4
    case slalom = 5

    var id: Int { rawValue }

    var titel: String {
        switch self {
        case .normal: return "Einfach"
        case .doppelt: return "Doppelt"
        case .obeabe: return "ObeAbe"
        case .undeufe: return "UndeUfe"
        case .slalom: return "Slalom"
        }
    }
}

private let teamLetters = ["A", "B", "C", "D"]

// MARK: - Focus

enum FocusField: Hashable {
    case stich(Int)
    case weis(Int)
}

enum EditFocusField: Hashable {
    case stich(Int)
    case weis(Int)
}

// MARK: - Views

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Runde.createdAt, order: .reverse)]) private var runden: [Runde]

    @StateObject private var vm = SpielstandViewModel()

    // Persisted team count and names
    @AppStorage("teamCount") private var teamCount: Int = 2
    @AppStorage("teamAName") private var teamAName: String = "Team A"
    @AppStorage("teamBName") private var teamBName: String = "Team B"
    @AppStorage("teamCName") private var teamCName: String = "Team C"
    @AppStorage("teamDName") private var teamDName: String = "Team D"
    @AppStorage("targetScore") private var targetScore: Int = 1000
    @AppStorage("trackTrumpf") private var trackTrumpf: Bool = false
    @State private var customTargetText: String = ""
    @State private var showCustomTarget: Bool = false

    private let targetPresets = [1000, 2000, 2500]

    // New-round input
    @State private var stich: [String] = ["", "", "", ""]
    @State private var weis: [String] = ["", "", "", ""]
    @State private var isMatch = false
    @State private var spielart: Spielart = .normal
    @State private var trumpTeamIndex: Int = 0
    @FocusState private var focusedField: FocusField?

    // Edit sheet state
    @State private var editingRunde: Runde? = nil
    @State private var editStich: [String] = ["", "", "", ""]
    @State private var editWeis: [String] = ["", "", "", ""]
    @State private var editMatch = false
    @State private var editSpielart: Spielart = .normal
    @State private var editTrumpTeamIndex: Int = 0
    @FocusState private var editFocusedField: EditFocusField?

    @State private var autoFilledIndex: Int? = nil
    @State private var editAutoFilledIndex: Int? = nil
    @State private var teamsExpanded: Bool = true
    @State private var showResetAlert = false
    @State private var scoreboardExpanded: Bool = false
    @State private var showChart: Bool = false
    @State private var pendingDelete: Runde? = nil
    @State private var showDeleteAlert = false

    // MARK: - Team name helpers

    private var teamNames: [String] {
        [teamAName, teamBName, teamCName, teamDName]
    }

    private func teamNameBinding(for index: Int) -> Binding<String> {
        switch index {
        case 0: return $teamAName
        case 1: return $teamBName
        case 2: return $teamCName
        case 3: return $teamDName
        default: return .constant("")
        }
    }

    private func stichBinding(at index: Int) -> Binding<String> {
        Binding(get: { stich[index] }, set: { stich[index] = $0 })
    }

    private func weisBinding(at index: Int) -> Binding<String> {
        Binding(get: { weis[index] }, set: { weis[index] = $0 })
    }

    private func editStichBinding(at index: Int) -> Binding<String> {
        Binding(get: { editStich[index] }, set: { editStich[index] = $0 })
    }

    private func editWeisBinding(at index: Int) -> Binding<String> {
        Binding(get: { editWeis[index] }, set: { editWeis[index] = $0 })
    }

    // MARK: - Validation helpers

    private var roundSumError: String? {
        vm.validateRoundSum(stich, teamCount: teamCount)
    }

    private var canAdd: Bool {
        vm.canAdd(stich: stich, weis: weis, teamCount: teamCount)
    }

    private var editRoundSumError: String? {
        guard let r = editingRunde else { return nil }
        return vm.validateRoundSum(editStich, teamCount: r.teamCount)
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                teamsSection
                scoreboardSection
                neueRundeSection
                if let sumErr = roundSumError {
                    Section {
                        Text(sumErr)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                rundenSection
            }
            .navigationTitle("JassTafel")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Zurücksetzen", role: .destructive) {
                            showResetAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") {
                        focusedField = nil
                        editFocusedField = nil
                    }
                }
            }
            .sheet(isPresented: Binding(get: { editingRunde != nil }, set: { if !$0 { editingRunde = nil } })) {
                editSheet
            }
            .alert("Alle Runden löschen?", isPresented: $showResetAlert, actions: {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    vm.resetAll()
                }
            }, message: {
                Text("Diese Aktion entfernt alle gespeicherten Runden.")
            })
            .alert("Runde löschen?", isPresented: $showDeleteAlert, actions: {
                Button("Abbrechen", role: .cancel) {
                    pendingDelete = nil
                }
                Button("Löschen", role: .destructive) {
                    if let p = pendingDelete {
                        vm.delete(runde: p)
                    }
                    pendingDelete = nil
                }
            }, message: {
                Text("Diese Aktion entfernt diese Runde.")
            })
            .onAppear {
                vm.setContext(modelContext)
            }
            .onChange(of: teamCount) { _, newCount in
                for i in newCount..<4 {
                    stich[i] = ""
                    weis[i] = ""
                }
            }
        }
    }

    // MARK: - Teams Section

    private var teamsSection: some View {
        Section(isExpanded: $teamsExpanded) {
            ForEach(0..<teamCount, id: \.self) { i in
                HStack {
                    TextField("Name für Team \(teamLetters[i])", text: teamNameBinding(for: i))
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.words)
                    if teamCount > 2 && i == teamCount - 1 {
                        Button {
                            teamCount -= 1
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if teamCount < 4 {
                Button {
                    teamCount += 1
                } label: {
                    Label("Team hinzufügen", systemImage: "plus.circle")
                }
            }

            // Target score picker
            HStack {
                Text("Zielpunktzahl")
                Spacer()
                Menu {
                    ForEach(targetPresets, id: \.self) { preset in
                        Button {
                            targetScore = preset
                            showCustomTarget = false
                        } label: {
                            HStack {
                                Text("\(preset)")
                                if targetScore == preset && !showCustomTarget {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button {
                        showCustomTarget = true
                        customTargetText = "\(targetScore)"
                    } label: {
                        HStack {
                            Text("Eigene…")
                            if showCustomTarget {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Text("\(targetScore)")
                        .foregroundColor(.accentColor)
                }
            }
            if showCustomTarget {
                HStack {
                    TextField("Zielpunktzahl", text: $customTargetText)
                        .keyboardType(.numberPad)
                    Button("OK") {
                        if let val = Int(customTargetText), val > 0 {
                            targetScore = val
                        }
                        showCustomTarget = false
                    }
                    .disabled(Int(customTargetText) == nil || (Int(customTargetText) ?? 0) <= 0)
                }
            }

            Toggle("Trumpf erfassen", isOn: $trackTrumpf)
        } header: {
            Button {
                withAnimation {
                    teamsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Teams")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(teamsExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Scoreboard Section

    private var scoreboardSection: some View {
        Section {
            if showChart && runden.count >= 2 {
                ScoreChartView(
                    runden: runden,
                    teamNames: teamNames,
                    teamCount: teamCount,
                    targetScore: targetScore
                )
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scoreboardExpanded.toggle()
                    }
                }) {
                    VStack(spacing: 8) {
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: min(teamCount, 2))
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<teamCount, id: \.self) { i in
                                let total = runden.map { $0.total(forTeam: i) }.reduce(0, +)
                                let hasWon = total >= targetScore
                                VStack(spacing: 4) {
                                    Text(teamNames[i])
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 4) {
                                        if hasWon {
                                            Image(systemName: "trophy.fill")
                                                .foregroundColor(.yellow)
                                                .font(.system(size: scoreboardExpanded ? 20 : 14))
                                        }
                                        Text("\(total)")
                                            .font(.system(size: scoreboardExpanded ? 34 : 24, weight: .bold, design: .rounded))
                                            .foregroundColor(hasWon ? .green : .primary)
                                    }
                                    .accessibilityLabel("Spielstand \(teamNames[i])")
                                    .accessibilityValue("\(total)")
                                    ProgressView(value: min(Double(total), Double(targetScore)), total: Double(targetScore))
                                        .tint(hasWon ? .green : .accentColor)
                                        .scaleEffect(y: 0.7)
                                }
                            }
                        }

                        if scoreboardExpanded {
                            VStack(spacing: 4) {
                                HStack {
                                    Text("Runden: \(runden.count)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if let last = runden.first {
                                        Text(Self.dateFormatter.string(from: last.createdAt))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityAddTraits(.isButton)
            }
        } header: {
            HStack {
                Text(showChart ? "Punkteverlauf" : "Spielstand")
                Spacer()
                if runden.count >= 2 {
                    Button {
                        withAnimation {
                            showChart.toggle()
                        }
                    } label: {
                        Image(systemName: showChart ? "number.square" : "chart.xyaxis.line")
                            .font(.footnote)
                    }
                }
            }
        }
    }

    // MARK: - Neue Runde Section

    private var neueRundeSection: some View {
        Section("Neue Runde") {
            if trackTrumpf {
                Picker("Trumpf", selection: $trumpTeamIndex) {
                    ForEach(0..<teamCount, id: \.self) { i in
                        Text(teamNames[i]).tag(i)
                    }
                }
            }

            ForEach(0..<teamCount, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Text(teamNames[i])
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Stich", text: stichBinding(at: i))
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .stich(i))
                            if let err = vm.validateStichField(stich[i]) {
                                Text(err).foregroundColor(.red).font(.caption2)
                            }
                            if !stich[i].isEmpty {
                                clearFieldButton(label: "Stich löschen") {
                                    stich[i] = ""
                                    focusedField = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        focusedField = .stich(i)
                                    }
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Weis", text: weisBinding(at: i))
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .weis(i))
                            if let err = vm.validateWeisField(weis[i]) {
                                Text(err).foregroundColor(.red).font(.caption2)
                            }
                            weisPresets(for: weisBinding(at: i))
                        }
                    }
                }
            }
            .onChange(of: stich) { _, _ in
                guard case .stich(let idx) = focusedField, idx < teamCount else { return }
                handleAutoFill(changedIndex: idx, newValue: stich[idx])
            }

            Picker("Spielart", selection: $spielart) {
                ForEach(Spielart.allCases) { art in
                    Text("\(art.titel) (x\(art.rawValue))").tag(art)
                }
            }

            Toggle("Match (Bonus +\(vm.MATCH_BONUS))", isOn: $isMatch)
                .accessibilityLabel("Match aktivieren")

            Button("Runde hinzufügen") {
                if vm.addRunde(stich: stich, weis: weis, teamCount: teamCount, spielart: spielart, match: isMatch, trumpTeamIndex: trackTrumpf ? trumpTeamIndex : -1) {
                    stich = ["", "", "", ""]
                    weis = ["", "", "", ""]
                    isMatch = false
                    spielart = .normal
                    autoFilledIndex = nil
                    // Auto-suggest next trump team
                    trumpTeamIndex = (trumpTeamIndex + 1) % teamCount
                    focusedField = .stich(0)
                }
            }
            .disabled(!canAdd || roundSumError != nil)
            .accessibilityLabel("Runde hinzufügen")
            .accessibilityHint("Fügt eine neue Runde mit den eingegebenen Punkten hinzu")
        }
    }

    // MARK: - Runden Section

    private var rundenSection: some View {
        Section("Runden") {
            if runden.isEmpty {
                Text("Keine Runden").foregroundStyle(.secondary)
            } else {
                ForEach(Array(runden.enumerated()), id: \.element.id) { index, runde in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(runden.count - index).")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(runde.spielart.titel) x\(runde.faktor)")
                                .font(.headline)
                            if trackTrumpf && runde.trumpTeamIndex >= 0 && runde.trumpTeamIndex < runde.teamCount {
                                Text("T: \(teamNames[runde.trumpTeamIndex])")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                            }
                            Spacer()
                            Text(Self.dateFormatter.string(from: runde.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        let roundTeamCount = runde.teamCount
                        let columns = Array(repeating: GridItem(.flexible()), count: min(roundTeamCount, 2))
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                            ForEach(0..<roundTeamCount, id: \.self) { i in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("\(teamNames[i]): \(runde.total(forTeam: i))")
                                            .font(.subheadline)
                                        if runde.bonus(forTeam: i) > 0 {
                                            Text("+\(runde.bonus(forTeam: i)) Match")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.green.opacity(0.15)))
                                        }
                                    }
                                    if runde.weis(forTeam: i) > 0 {
                                        Text("S:\(runde.stich(forTeam: i)) W:\(runde.weis(forTeam: i))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .padding(.vertical, 6)
                    .swipeActions(edge: .trailing) {
                        Button("Löschen", role: .destructive) {
                            pendingDelete = runde
                            showDeleteAlert = true
                        }
                        Button("Bearbeiten") {
                            editingRunde = runde
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }

    // MARK: - Edit Sheet

    @ViewBuilder
    private var editSheet: some View {
        if let r = editingRunde {
            NavigationStack {
                Form {
                    Section("Bearbeiten") {
                        ForEach(0..<r.teamCount, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(teamNames[i])
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        TextField("Stich", text: editStichBinding(at: i))
                                            .keyboardType(.numberPad)
                                            .focused($editFocusedField, equals: .stich(i))
                                        if let err = vm.validateStichField(editStich[i]) {
                                            Text(err).foregroundColor(.red).font(.caption2)
                                        }
                                        if !editStich[i].isEmpty {
                                            clearFieldButton(label: "Stich löschen") {
                                                editStich[i] = ""
                                                editFocusedField = nil
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                    editFocusedField = .stich(i)
                                                }
                                            }
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        TextField("Weis", text: editWeisBinding(at: i))
                                            .keyboardType(.numberPad)
                                            .focused($editFocusedField, equals: .weis(i))
                                        if let err = vm.validateWeisField(editWeis[i]) {
                                            Text(err).foregroundColor(.red).font(.caption2)
                                        }
                                        weisPresets(for: editWeisBinding(at: i))
                                    }
                                }
                            }
                        }
                        .onChange(of: editStich) { _, _ in
                            guard case .stich(let idx) = editFocusedField, idx < r.teamCount else { return }
                            handleEditAutoFill(changedIndex: idx, newValue: editStich[idx], roundTeamCount: r.teamCount)
                        }
                        Picker("Spielart", selection: $editSpielart) {
                            ForEach(Spielart.allCases) { art in
                                Text("\(art.titel) (x\(art.rawValue))").tag(art)
                            }
                        }
                        if trackTrumpf {
                            Picker("Trumpf", selection: $editTrumpTeamIndex) {
                                ForEach(0..<r.teamCount, id: \.self) { i in
                                    Text(teamNames[i]).tag(i)
                                }
                            }
                        }
                        Toggle("Match (Bonus +\(vm.MATCH_BONUS))", isOn: $editMatch)
                            .accessibilityLabel("Match für diese Runde")
                    }
                    if let sumErr = editRoundSumError {
                        Section {
                            Text(sumErr)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .navigationTitle(runden.firstIndex(where: { $0.id == r.id }).map { "Runde \(runden.count - $0) bearbeiten" } ?? "Runde bearbeiten")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            editingRunde = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            saveEditing()
                        }
                        .disabled(!canSaveEdit(for: r) || editRoundSumError != nil)
                    }
                }
                .onAppear {
                    for i in 0..<r.teamCount {
                        editStich[i] = String(r.stich(forTeam: i))
                        let w = r.weis(forTeam: i)
                        editWeis[i] = w > 0 ? String(w) : ""
                    }
                    editSpielart = r.spielart
                    editTrumpTeamIndex = r.trumpTeamIndex >= 0 ? r.trumpTeamIndex : 0
                    let expected = vm.MATCH_BONUS * r.faktor
                    editMatch = (0..<r.teamCount).contains { r.bonus(forTeam: $0) == expected }
                }
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Clear Button

    private func clearFieldButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weis Presets

    private static let weisPresetValues = [20, 50, 100, 150, 200]

    private func weisPresets(for binding: Binding<String>) -> some View {
        HStack(spacing: 6) {
            ForEach(Self.weisPresetValues, id: \.self) { value in
                Button {
                    let current = Int(binding.wrappedValue) ?? 0
                    binding.wrappedValue = String(current + value)
                } label: {
                    Text("+\(value)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            if !binding.wrappedValue.isEmpty {
                Button {
                    binding.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .padding(4)
                        .background(Circle().fill(Color.red.opacity(0.12)))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Auto-fill Logic (Stich only)

    private func handleAutoFill(changedIndex: Int, newValue: String) {
        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if teamCount == 2 {
                let other = changedIndex == 0 ? 1 : 0
                stich[other] = ""
            }
            isMatch = false
            return
        }

        guard let changedVal = Int(newValue) else { return }

        if teamCount == 2 {
            let other = changedIndex == 0 ? 1 : 0
            let remaining = vm.REQUIRED_SUM - changedVal
            if remaining >= 0 && remaining <= vm.MAX_STICH {
                stich[other] = String(remaining)
            }
        } else {
            var otherSum = 0
            var emptyIndices: [Int] = []
            for j in 0..<teamCount where j != changedIndex {
                if let v = Int(stich[j]) {
                    otherSum += v
                } else {
                    emptyIndices.append(j)
                }
            }
            // Determine which index to auto-fill
            let fillIndex: Int?
            if emptyIndices.count == 1 {
                fillIndex = emptyIndices[0]
            } else if emptyIndices.isEmpty, let prev = autoFilledIndex, prev != changedIndex {
                // All fields filled — recalculate the previously auto-filled field
                otherSum -= (Int(stich[prev]) ?? 0)
                fillIndex = prev
            } else {
                fillIndex = nil
            }
            if let idx = fillIndex {
                let remaining = vm.REQUIRED_SUM - otherSum - changedVal
                if remaining >= 0 && remaining <= vm.MAX_STICH {
                    stich[idx] = String(remaining)
                    autoFilledIndex = idx
                }
            }
        }

        let allValues = (0..<teamCount).compactMap { Int(stich[$0]) }
        isMatch = allValues.contains(vm.REQUIRED_SUM)
    }

    private func handleEditAutoFill(changedIndex: Int, newValue: String, roundTeamCount: Int) {
        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if roundTeamCount == 2 {
                let other = changedIndex == 0 ? 1 : 0
                editStich[other] = ""
            }
            editMatch = false
            return
        }

        guard let changedVal = Int(newValue) else { return }

        if roundTeamCount == 2 {
            let other = changedIndex == 0 ? 1 : 0
            let remaining = vm.REQUIRED_SUM - changedVal
            if remaining >= 0 && remaining <= vm.MAX_STICH {
                editStich[other] = String(remaining)
            }
        } else {
            var otherSum = 0
            var emptyIndices: [Int] = []
            for j in 0..<roundTeamCount where j != changedIndex {
                if let v = Int(editStich[j]) {
                    otherSum += v
                } else {
                    emptyIndices.append(j)
                }
            }
            let fillIndex: Int?
            if emptyIndices.count == 1 {
                fillIndex = emptyIndices[0]
            } else if emptyIndices.isEmpty, let prev = editAutoFilledIndex, prev != changedIndex {
                otherSum -= (Int(editStich[prev]) ?? 0)
                fillIndex = prev
            } else {
                fillIndex = nil
            }
            if let idx = fillIndex {
                let remaining = vm.REQUIRED_SUM - otherSum - changedVal
                if remaining >= 0 && remaining <= vm.MAX_STICH {
                    editStich[idx] = String(remaining)
                    editAutoFilledIndex = idx
                }
            }
        }

        let allValues = (0..<roundTeamCount).compactMap { Int(editStich[$0]) }
        editMatch = allValues.contains(vm.REQUIRED_SUM)
    }

    // MARK: - Edit Helpers

    private func canSaveEdit(for runde: Runde) -> Bool {
        let tc = runde.teamCount
        for i in 0..<tc {
            if vm.validateStichField(editStich[i]) != nil { return false }
            if vm.validateWeisField(editWeis[i]) != nil { return false }
        }
        let stichValues = (0..<tc).compactMap { Int(editStich[$0]) }
        guard stichValues.count == tc else { return false }

        let stichChanged = (0..<tc).contains { stichValues[$0] != runde.stich(forTeam: $0) }
        let weisChanged = (0..<tc).contains { i in
            let newW = Int(editWeis[i].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            return newW != runde.weis(forTeam: i)
        }
        let spielartChanged = editSpielart != runde.spielart
        let expectedBonus = vm.MATCH_BONUS * runde.faktor
        let wasMatch = (0..<tc).contains { runde.bonus(forTeam: $0) == expectedBonus }
        let matchChanged = editMatch != wasMatch
        let trumpChanged = editTrumpTeamIndex != runde.trumpTeamIndex

        return stichChanged || weisChanged || spielartChanged || matchChanged || trumpChanged
    }

    private func saveEditing() {
        guard let r = editingRunde else { return }
        let stichValues = (0..<r.teamCount).compactMap { Int(editStich[$0]) }
        guard stichValues.count == r.teamCount else { return }
        let weisValues = (0..<r.teamCount).map { i -> Int in
            Int(editWeis[i].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }
        vm.updateRunde(r, stich: stichValues, weis: weisValues, spielart: editSpielart, match: editMatch, trumpTeamIndex: trackTrumpf ? editTrumpTeamIndex : -1)
        editingRunde = nil
    }
}
