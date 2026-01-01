//  Views/GameSetup/CourseDataEntryView.swift
import SwiftUI

struct CourseDataEntryView: View {
    @Environment(\.dismiss) var dismiss
    let course: GolfCourse
    let onSave: (GolfCourseData) -> Void
    
    @AppStorage("userName") private var userName: String = "Me"
    @State private var holePars: [Int] = Array(repeating: 4, count: 18) // Default to par 4
    
    private var totalPar: Int {
        holePars.reduce(0, +)
    }
    
    private var par3Count: Int {
        holePars.filter { $0 == 3 }.count
    }
    
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.green)
                                .padding(.top, 20)
                            
                            Text("Enter Course Data")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text(course.name)
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            // Info box
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Help build our community database! Enter the par for each hole.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding()
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        
                        // Summary card
                        HStack(spacing: 30) {
                            VStack(spacing: 4) {
                                Text("TOTAL PAR")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.6))
                                Text("\(totalPar)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.3))
                                .frame(height: 50)
                            
                            VStack(spacing: 4) {
                                Text("PAR 3 HOLES")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.6))
                                Text("\(par3Count)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        // 18 Holes Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(1...18, id: \.self) { hole in
                                HoleParSelector(
                                    holeNumber: hole,
                                    par: $holePars[hole - 1]
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Save Button
                        Button {
                            saveCourseData()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Course Data")
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
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Course Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveCourseData() {
        let courseData = GolfCourseData(
            courseID: course.id,
            courseName: course.name,
            holePars: holePars,
            contributedBy: userName != "Me" ? userName : nil
        )
        
        onSave(courseData)
        dismiss()
    }
}

// MARK: - Hole Par Selector
struct HoleParSelector: View {
    let holeNumber: Int
    @Binding var par: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // Hole number
            Text("HOLE \(holeNumber)")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.6))
            
            // Par selector
            HStack(spacing: 8) {
                ForEach([3, 4, 5], id: \.self) { parValue in
                    Button {
                        par = parValue
                    } label: {
                        Text("\(parValue)")
                            .font(.title2.bold())
                            .foregroundStyle(par == parValue ? .black : .white)
                            .frame(width: 50, height: 50)
                            .background(
                                par == parValue ?
                                Color.green :
                                Color.white.opacity(0.1)
                            )
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}

#Preview {
    CourseDataEntryView(
        course: GolfCourse(
            id: "test",
            name: "Desert Hills Golf Club",
            address: "1234 Golf Lane",
            coordinate: GolfCourse.Coordinate(latitude: 33.4484, longitude: -112.0740),
            phoneNumber: nil,
            rating: nil,
            userRatingsTotal: nil
        )
    ) { _ in }
}
