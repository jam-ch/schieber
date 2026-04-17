import SwiftUI
import Combine
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
        case .normal: return "Einfach" // renamed from "Normal" to "Einfach"
        case .doppelt: return "Doppelt"
        case .obeabe: return "ObeAbe"
        case .undeufe: return "UndeUfe"
        case .slalom: return "Slalom"
        }
    }
}

// MARK: - Views

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Runde.createdAt, order: .reverse)]) private var runden: [Runde]

    @StateObject private var vm = SpielstandViewModel()

    // Persisted team names
    @AppStorage("teamAName") private var teamAName: String = "Team A"
    @AppStorage("teamBName") private var teamBName: String = "Team B"

    @State private var punkteA = ""
    @State private var punkteB = ""
    // Avoid feedback loops when auto-filling the other field
    @State private var isAutoFilling = false
    // Match checkbox for New Round
    @State private var isMatch = false

    @State private var spielart: Spielart = .normal

    @FocusState private var focusedField: Field?

    // Editing auto-fill flag
    @State private var editIsAutoFilling = false
    // Editing match flag
    @State private var editMatch = false

    @State private var showResetAlert = false
    // Scoreboard expanded/collapsed state
    @State private var scoreboardExpanded: Bool = true

    // Editing state
    @State private var editingRunde: Runde? = nil
    @State private var editPunkteA = ""
    @State private var editPunkteB = ""
    @State private var editSpielart: Spielart = .normal
    @FocusState private var editFocusedField: EditField?

    // Delete confirmation
    @State private var pendingDelete: Runde? = nil
    @State private var showDeleteAlert = false

    private var punkteAInt: Int? { Int(punkteA) }
    private var punkteBInt: Int? { Int(punkteB) }

    private var punkteAError: String? { vm.validatePunkteField(punkteA) }
    private var punkteBError: String? { vm.validatePunkteField(punkteB) }
    private var roundSumError: String? { vm.validateRoundSum(punkteA, punkteB) }

    private var canAdd: Bool { vm.canAdd(punkteA: punkteA, punkteB: punkteB) }

    enum Field: Hashable {
        case a
        case b
    }

    enum EditField: Hashable {
        case a
        case b
    }

    // Date formatter for round display
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Name für Team A", text: $teamAName)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.words)
                        TextField("Name für Team B", text: $teamBName)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.words)
                    }
                }

                // Totals computed directly from persisted rounds to ensure correctness
                let totalA = runden.map { $0.totalA }.reduce(0, +)
                let totalB = runden.map { $0.totalB }.reduce(0, +)

                Section(header: Text("Spielstand")) {
                    // Tappable scoreboard card: toggles expanded/collapsed view
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            scoreboardExpanded.toggle()
                        }
                    }) {
                        VStack(spacing: 8) {
                            HStack(spacing: 16) {
                                // Team A block (left-aligned)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(teamAName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(totalA)")
                                        .font(.system(size: scoreboardExpanded ? 34 : 24, weight: .bold, design: .rounded))
                                        .accessibilityLabel("Spielstand \(teamAName)")
                                        .accessibilityValue("\(totalA)")
                                }

                                Spacer()

                                // Center divider with optional label (keeps visual balance)
                                VStack {
                                    Text("vs")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Team B block (right-aligned)
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(teamBName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(totalB)")
                                        .font(.system(size: scoreboardExpanded ? 34 : 24, weight: .bold, design: .rounded))
                                        .accessibilityLabel("Spielstand \(teamBName)")
                                        .accessibilityValue("\(totalB)")
                                }
                            }

                            // Expanded details
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
                        // tighten row insets for a card-like appearance
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityAddTraits(.isButton)
                }

                Section("Neue Runde") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("\(teamAName) Punkte", text: $punkteA)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .a)
                            .accessibilityLabel("\(teamAName) Punkte")
                            .onChange(of: punkteA) { _, new in
                                guard !isAutoFilling else { return }
                                // Only auto-fill when the user is editing this field
                                guard focusedField == .a else { return }
                                // If empty, clear the other field
                                if new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    isAutoFilling = true
                                    punkteB = ""
                                    isAutoFilling = false
                                    // no team has full points -> clear match
                                    isMatch = false
                                    return
                                }
                                if let a = Int(new) {
                                    let b = vm.REQUIRED_SUM - a
                                    if b >= 0 && b <= vm.MAX_POINTS {
                                        isAutoFilling = true
                                        punkteB = String(b)
                                        isAutoFilling = false
                                    }
                                }
                                // Auto-activate match if a team reached REQUIRED_SUM, otherwise clear
                                if let a = Int(new), a == vm.REQUIRED_SUM || Int(punkteB) == vm.REQUIRED_SUM {
                                    isMatch = true
                                } else {
                                    isMatch = false
                                }
                            }
                        if let err = punkteAError {
                            Text(err).foregroundColor(.red).font(.caption)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("\(teamBName) Punkte", text: $punkteB)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .b)
                            .accessibilityLabel("\(teamBName) Punkte")
                            .onChange(of: punkteB) { _, new in
                                guard !isAutoFilling else { return }
                                guard focusedField == .b else { return }
                                if new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    isAutoFilling = true
                                    punkteA = ""
                                    isAutoFilling = false
                                    // no team has full points -> clear match
                                    isMatch = false
                                    return
                                }
                                if let b = Int(new) {
                                    let a = vm.REQUIRED_SUM - b
                                    if a >= 0 && a <= vm.MAX_POINTS {
                                        isAutoFilling = true
                                        punkteA = String(a)
                                        isAutoFilling = false
                                    }
                                }
                                // Auto-activate match if a team reached REQUIRED_SUM, otherwise clear
                                if let b = Int(new), b == vm.REQUIRED_SUM || Int(punkteA) == vm.REQUIRED_SUM {
                                    isMatch = true
                                } else {
                                    isMatch = false
                                }
                            }
                        if let err = punkteBError {
                            Text(err).foregroundColor(.red).font(.caption)
                        }
                    }

                    Picker("Spielart", selection: $spielart) {
                        ForEach(Spielart.allCases) { art in
                            Text("\(art.titel) (x\(art.rawValue))").tag(art)
                        }
                    }

                    Toggle("Match (Bonus +\(vm.MATCH_BONUS))", isOn: $isMatch)
                        .accessibilityLabel("Match aktivieren")

                     Button("Runde hinzufügen") {
                        if vm.addRunde(punkteA: punkteA, punkteB: punkteB, spielart: spielart, match: isMatch) {
                            punkteA = ""
                            punkteB = ""
                            isMatch = false
                            // Ensure next new round defaults to Normal
                            spielart = .normal
                            // Reset focus to first field so user can start typing the next score
                            focusedField = .a
                        }
                     }
                      .disabled(!canAdd || roundSumError != nil)
                      .accessibilityLabel("Runde hinzufügen")
                      .accessibilityHint("Fügt eine neue Runde mit den eingegebenen Punkten hinzu")
                 }

                if let sumErr = roundSumError {
                    Section {
                        Text(sumErr)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section("Runden") {
                    if runden.isEmpty {
                        Text("Keine Runden").foregroundStyle(.secondary)
                    } else {
                        ForEach(runden, id: \.id) { runde in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(runde.spielart.titel) x\(runde.faktor)")
                                        .font(.headline)
                                    Spacer()
                                    Text(Self.dateFormatter.string(from: runde.createdAt))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                // Show per-team totals and optional Match bonus badge
                                HStack {
                                    VStack(alignment: .leading) {
                                        HStack(spacing: 6) {
                                            Text("\(teamAName): \(runde.totalA)")
                                                .font(.subheadline)
                                            if runde.bonusA > 0 {
                                                Text("+\(runde.bonusA) Match")
                                                    .font(.caption2)
                                                    .foregroundColor(.green)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color.green.opacity(0.15)))
                                            }
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        HStack(spacing: 6) {
                                            if runde.bonusB > 0 {
                                                Text("+\(runde.bonusB) Match")
                                                    .font(.caption2)
                                                    .foregroundColor(.green)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color.green.opacity(0.15)))
                                            }
                                            Text("\(teamBName): \(runde.totalB)")
                                                .font(.subheadline)
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
                                     startEditing(runde)
                                 }
                                 .tint(.blue)
                             }
                         }
                         .onDelete(perform: delete)
                     }
                 }
            }
            .navigationTitle("Schieber Zähler")
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
                if let r = editingRunde {
                    NavigationStack {
                        Form {
                            Section("Bearbeiten") {
                                TextField("Team A Punkte", text: $editPunkteA)
                                    .keyboardType(.numberPad)
                                    .focused($editFocusedField, equals: .a)
                                    .submitLabel(.done)
                                    .disableAutocorrection(true)
                                    .accessibilityLabel("Team A Punkte bearbeiten")
                                    .onChange(of: editPunkteA) { _, new in
                                        guard !editIsAutoFilling else { return }
                                        guard editFocusedField == .a else { return }
                                        if new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            editIsAutoFilling = true
                                            editPunkteB = ""
                                            editIsAutoFilling = false
                                            // no team has full points -> clear editMatch
                                            editMatch = false
                                            return
                                        }
                                        if let a = Int(new) {
                                            let b = vm.REQUIRED_SUM - a
                                            if b >= 0 && b <= vm.MAX_POINTS {
                                                editIsAutoFilling = true
                                                editPunkteB = String(b)
                                                editIsAutoFilling = false
                                            }
                                        }
                                        // Auto-activate editMatch if a team reached REQUIRED_SUM, otherwise clear
                                        if let a = Int(new), a == vm.REQUIRED_SUM || Int(editPunkteB) == vm.REQUIRED_SUM {
                                            editMatch = true
                                        } else {
                                            editMatch = false
                                        }
                                    }
                                TextField("Team B Punkte", text: $editPunkteB)
                                    .keyboardType(.numberPad)
                                    .focused($editFocusedField, equals: .b)
                                    .submitLabel(.done)
                                    .disableAutocorrection(true)
                                    .accessibilityLabel("Team B Punkte bearbeiten")
                                    .onChange(of: editPunkteB) { _, new in
                                        guard !editIsAutoFilling else { return }
                                        guard editFocusedField == .b else { return }
                                        if new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            editIsAutoFilling = true
                                            editPunkteA = ""
                                            editIsAutoFilling = false
                                            // no team has full points -> clear editMatch
                                            editMatch = false
                                            return
                                        }
                                        if let b = Int(new) {
                                            let a = vm.REQUIRED_SUM - b
                                            if a >= 0 && a <= vm.MAX_POINTS {
                                                editIsAutoFilling = true
                                                editPunkteA = String(a)
                                                editIsAutoFilling = false
                                            }
                                        }
                                        // Auto-activate editMatch if a team reached REQUIRED_SUM, otherwise clear
                                        if let b = Int(new), b == vm.REQUIRED_SUM || Int(editPunkteA) == vm.REQUIRED_SUM {
                                            editMatch = true
                                        } else {
                                            editMatch = false
                                        }
                                    }
                                 Picker("Spielart", selection: $editSpielart) {
                                     ForEach(Spielart.allCases) { art in
                                         Text("\(art.titel)").tag(art)
                                     }
                                 }
                                Toggle("Match (Bonus +\(vm.MATCH_BONUS))", isOn: $editMatch)
                                    .accessibilityLabel("Match für diese Runde")
                             }
                        }
                        .navigationTitle("Runde bearbeiten")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Abbrechen") {
                                    editingRunde = nil
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Speichern") {
                                    saveEditing()
                                }
                                .disabled(!canSaveEdit(for: r) || vm.validateRoundSum(editPunkteA, editPunkteB) != nil)
                            }
                        }
                        .onAppear {
                            // initialize edit fields
                            editPunkteA = String(r.punkteTeamA)
                            editPunkteB = String(r.punkteTeamB)
                            editSpielart = r.spielart
                            // initialize match flag from existing bonuses using the multiplier (MATCH_BONUS * factor)
                            let expected = vm.MATCH_BONUS * r.faktor
                            editMatch = (r.bonusA == expected) || (r.bonusB == expected)
                        }
                    }
                } else {
                    // fallback empty view
                    EmptyView()
                }
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
        }
    }

    private func canSaveEdit(for runde: Runde) -> Bool {
        // validate fields and ensure something changed
        if vm.validatePunkteField(editPunkteA) != nil || vm.validatePunkteField(editPunkteB) != nil {
            return false
        }
        guard let a = Int(editPunkteA), let b = Int(editPunkteB) else { return false }
        if a == runde.punkteTeamA && b == runde.punkteTeamB && editSpielart == runde.spielart {
            return false
        }
        return true
    }

    private func startEditing(_ runde: Runde) {
        editingRunde = runde
    }

    private func saveEditing() {
        guard let r = editingRunde, let a = Int(editPunkteA), let b = Int(editPunkteB) else { return }
        vm.updateRunde(r, punkteA: a, punkteB: b, spielart: editSpielart, match: editMatch)
        editingRunde = nil
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let r = runden[index]
            vm.delete(runde: r)
        }
    }
}
