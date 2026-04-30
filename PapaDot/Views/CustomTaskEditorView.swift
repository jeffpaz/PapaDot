// Views/CustomTaskEditorView.swift
import SwiftUI

struct CustomTaskEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(SavedTasksManager.self) var savedTasks

    @Binding var tasks: [CustomTask]

    @State private var showingAddTask = false
    @State private var editingTask: CustomTask?
    @State private var showingSavePreset = false
    @State private var showingSaveAsNew = false
    @State private var showingLoadPreset = false
    @State private var presetName = ""
    @State private var loadedPreset: TaskPreset?

    private let defaultTaskNames = ["Fairway", "Birdie", "Poley", "Greenie", "Low Hole", "Sandy", "Sand", "OB", "3-Putt", "4-Putt", "Lady's Tee"]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.4, blue: 0.2), Color(red: 0.05, green: 0.25, blue: 0.15)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                            .padding(.top, 20)

                        Text("Scoring Tasks")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Configure, save, and load task presets")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Preset Buttons
                    HStack(spacing: 12) {
                        Button {
                            showingLoadPreset = true
                        } label: {
                            Label("Load Preset", systemImage: "tray.and.arrow.down.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.7))
                                .cornerRadius(10)
                        }
                        .disabled(savedTasks.presets.isEmpty)
                        .opacity(savedTasks.presets.isEmpty ? 0.4 : 1)

                        Button {
                            if loadedPreset != nil {
                                showingSavePreset = true
                            } else {
                                presetName = ""
                                showingSaveAsNew = true
                            }
                        } label: {
                            Label("Save Preset", systemImage: "tray.and.arrow.up.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.purple.opacity(0.7))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Tasks List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(tasks) { task in
                                TaskRow(task: task, isDefault: defaultTaskNames.contains(task.name)) {
                                    editingTask = task
                                } onDelete: {
                                    tasks.removeAll { $0.id == task.id }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Add Task Button
                    Button {
                        showingAddTask = true
                    } label: {
                        Label("Add Custom Task", systemImage: "plus.circle.fill")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        tasks = CustomTask.defaultTasks
                        loadedPreset = nil
                    }
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                }
            }
            // Add Task Sheet
            .sheet(isPresented: $showingAddTask) {
                TaskFormView(existingTask: nil) { newTask in
                    tasks.append(newTask)
                }
            }
            // Edit Task Sheet
            .sheet(item: $editingTask) { task in
                TaskFormView(existingTask: task) { updated in
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[idx] = updated
                    }
                }
            }
            // Save Preset Choice (when a preset is loaded)
            .confirmationDialog("Save Preset", isPresented: $showingSavePreset) {
                Button("Update \"\(loadedPreset?.name ?? "")\"") {
                    if let preset = loadedPreset {
                        savedTasks.save(name: preset.name, tasks: tasks)
                        loadedPreset = savedTasks.presets.first(where: { $0.name == preset.name })
                    }
                }
                Button("Save as New Preset") {
                    presetName = ""
                    showingSaveAsNew = true
                }
                Button("Cancel", role: .cancel) {}
            }
            // Save As New Alert
            .alert("Save as New Preset", isPresented: $showingSaveAsNew) {
                TextField("Preset name", text: $presetName)
                Button("Save") {
                    let name = presetName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        savedTasks.save(name: name, tasks: tasks)
                        loadedPreset = savedTasks.presets.first(where: { $0.name == name })
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for this task configuration so you can reload it in future games.")
            }
            // Load Preset Sheet
            .sheet(isPresented: $showingLoadPreset) {
                LoadPresetView(savedTasks: savedTasks) { preset in
                    tasks = preset.tasks
                    loadedPreset = preset
                }
            }
        }
    }
}

// MARK: - Load Preset View

struct LoadPresetView: View {
    @Environment(\.dismiss) var dismiss
    let savedTasks: SavedTasksManager
    let onLoad: (TaskPreset) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(savedTasks.presets) { preset in
                    Button {
                        onLoad(preset)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(preset.tasks.count) tasks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indices in
                    indices.forEach { savedTasks.delete(savedTasks.presets[$0]) }
                }
            }
            .navigationTitle("Load Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: CustomTask
    let isDefault: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Points badge
            VStack(spacing: 2) {
                Text(task.isNegative ? "-\(abs(task.points))" : "+\(task.points)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(task.isNegative ? .red : .green)
                Text("pts")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 44)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(task.isNegative ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    if task.isExclusive {
                        Label("Exclusive", systemImage: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    if task.hasCarryOver {
                        Label("Carry Over", systemImage: "arrow.up.circle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if task.isNegative {
                        Label("Penalty", systemImage: "minus.circle")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    if isDefault {
                        Text("Default")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }

                if !isDefault {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.1))
        .cornerRadius(14)
    }
}

// MARK: - Task Form (Add / Edit)

struct TaskFormView: View {
    @Environment(\.dismiss) var dismiss

    let existingTask: CustomTask?
    let onSave: (CustomTask) -> Void

    @State private var name: String
    @State private var points: Int
    @State private var isExclusive: Bool
    @State private var isNegative: Bool
    @State private var hasCarryOver: Bool

    init(existingTask: CustomTask?, onSave: @escaping (CustomTask) -> Void) {
        self.existingTask = existingTask
        self.onSave = onSave
        _name = State(initialValue: existingTask?.name ?? "")
        _points = State(initialValue: abs(existingTask?.points ?? 1))
        _isExclusive = State(initialValue: existingTask?.isExclusive ?? false)
        _isNegative = State(initialValue: existingTask?.isNegative ?? false)
        _hasCarryOver = State(initialValue: existingTask?.hasCarryOver ?? false)
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Name") {
                    TextField("e.g. Eagle, Longest Drive", text: $name)
                }

                Section("Points") {
                    Stepper("\(points) point\(points == 1 ? "" : "s")", value: $points, in: 1...10)
                    Toggle("This is a penalty (negative)", isOn: $isNegative)
                }

                Section {
                    Toggle("Exclusive (only one player per hole)", isOn: $isExclusive)
                    Toggle("Carry Over (increments if not scored)", isOn: $hasCarryOver)
                } header: {
                    Text("Options")
                } footer: {
                    if hasCarryOver {
                        Text("When carry over is enabled, the value starts at \(points) pts. Each hole it's not won, it increases by \(points) pts. When won, it resets to \(points) pts. Example: \(points) → \(points*2) → \(points*3) → won = \(points*3) pts, then reset.")
                    }
                }

                Section {
                    // Preview
                    HStack {
                        Text("Preview:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(isNegative ? "-\(points) pts" : "+\(points) pts")
                            .font(.headline)
                            .foregroundStyle(isNegative ? .red : .green)
                    }
                }
            }
            .navigationTitle(existingTask == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let task = CustomTask(
                            id: existingTask?.id ?? UUID().uuidString,
                            name: name.trimmingCharacters(in: .whitespaces),
                            points: isNegative ? -points : points,
                            isExclusive: isExclusive,
                            isNegative: isNegative,
                            hasCarryOver: hasCarryOver
                        )
                        onSave(task)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
