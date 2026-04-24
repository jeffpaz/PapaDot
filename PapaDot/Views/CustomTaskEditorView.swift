//  Views/GameSetup/CustomTaskEditorView.swift
import SwiftUI

struct CustomTaskEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [CustomTask]
    
    @State private var showingAddTask = false
    @State private var editingTask: CustomTask?
    
    // Default tasks that should always be available
    private let defaultTaskNames = ["Fairway", "Birdie", "Poley", "Greenie", "Low Hole", "Sandy", "Sand", "OB", "3-Putt"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.2),
                        Color(red: 0.05, green: 0.25, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                            .padding(.top, 20)
                        
                        Text("Custom Tasks")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Add, edit, or remove scoring tasks")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    // Tasks List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(tasks) { task in
                                TaskRow(task: task, isDefault: defaultTaskNames.contains(task.name)) {
                                    editingTask = task
                                } onDelete: {
                                    deleteTask(task)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Add Task Button
                    Button {
                        showingAddTask = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Custom Task")
                                .font(.headline.bold())
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetToDefaults()
                    }
                    .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showingAddTask) {
                TaskEditorSheet(task: nil) { newTask in
                    tasks.append(newTask)
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(task: task) { updatedTask in
                    if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[index] = updatedTask
                    }
                }
            }
        }
    }
    
    private func deleteTask(_ task: CustomTask) {
        tasks.removeAll { $0.id == task.id }
    }
    
    private func resetToDefaults() {
        tasks = CustomTask.defaultTasks
    }
}

// MARK: - Task Row
struct TaskRow: View {
    let task: CustomTask
    let isDefault: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(task.isNegative ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: task.isNegative ? "minus.circle.fill" : "plus.circle.fill")
                        .foregroundStyle(task.isNegative ? .red : .green)
                        .font(.title3)
                }
            
            // Task Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(task.name)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    
                    if task.isExclusive {
                        Text("EXCLUSIVE")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                
                Text("\(task.points > 0 ? "+" : "")\(task.points) point\(abs(task.points) == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                
                if !isDefault {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Task Editor Sheet
struct TaskEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let task: CustomTask?
    let onSave: (CustomTask) -> Void
    
    @State private var name: String
    @State private var points: String
    @State private var isNegative: Bool
    @State private var isExclusive: Bool
    
    init(task: CustomTask?, onSave: @escaping (CustomTask) -> Void) {
        self.task = task
        self.onSave = onSave
        
        _name = State(initialValue: task?.name ?? "")
        _points = State(initialValue: task != nil ? "\(abs(task!.points))" : "1")
        _isNegative = State(initialValue: task?.isNegative ?? false)
        _isExclusive = State(initialValue: task?.isExclusive ?? false)
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(points) != nil &&
        Int(points)! > 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.2),
                        Color(red: 0.05, green: 0.25, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: task == nil ? "plus.circle.fill" : "pencil.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.green)
                                .padding(.top, 20)
                            
                            Text(task == nil ? "New Task" : "Edit Task")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        // Form
                        VStack(spacing: 20) {
                            // Task Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Task Name")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                TextField("e.g., Eagle", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color.white.opacity(0.15))
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                                    .autocorrectionDisabled()
                            }
                            
                            // Points
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Point Value")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                TextField("e.g., 3", text: $points)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color.white.opacity(0.15))
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                            }
                            
                            // Negative Toggle
                            Toggle(isOn: $isNegative) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Penalty")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Deducts points instead of adding")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .tint(.red)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Exclusive Toggle
                            Toggle(isOn: $isExclusive) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Exclusive")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Only one player can achieve this per hole")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .tint(.orange)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Save Button
                        Button {
                            saveTask()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Task")
                                    .font(.headline.bold())
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                isValid ?
                                LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                        }
                        .disabled(!isValid)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
    
    private func saveTask() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pointValue = Int(points) ?? 1
        let finalPoints = isNegative ? -pointValue : pointValue
        
        let savedTask = CustomTask(
            id: task?.id ?? UUID().uuidString,
            name: trimmedName,
            points: finalPoints,
            isExclusive: isExclusive,
            isNegative: isNegative
        )
        
        onSave(savedTask)
        dismiss()
    }
}

#Preview {
    @Previewable @State var tasks = CustomTask.defaultTasks
    CustomTaskEditorView(tasks: $tasks)
}
