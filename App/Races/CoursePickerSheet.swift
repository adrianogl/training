import GarminAPI
import SwiftUI

struct CoursePickerSheet: View {
    let client: GarminAccountClient?
    let onPick: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var courses: [GarminCourseSummary]?
    @State private var failed = false
    @State private var loadingId: Int64?

    var body: some View {
        NavigationStack {
            Group {
                if let courses {
                    if courses.isEmpty {
                        Text(RacesConstants.courseEmpty).foregroundStyle(BrandColors.dim).padding()
                    } else {
                        List(courses) { course in
                            Button { Task { await pick(course) } } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(course.name).foregroundStyle(BrandColors.text)
                                        Text(detail(course)).font(.caption).foregroundStyle(BrandColors.dim)
                                    }
                                    Spacer()
                                    if loadingId == course.id { ProgressView() }
                                }
                            }
                            .disabled(loadingId != nil)
                        }
                        .scrollContentBackground(.hidden)
                    }
                } else if failed {
                    Text(RacesConstants.courseFailed).foregroundStyle(BrandColors.danger).padding()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandBackground())
            .navigationTitle(RacesConstants.courseTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(RacesConstants.cancel) { dismiss() }
                }
            }
        }
        .task {
            guard let client else { failed = true; return }
            do { courses = try await GarminCourses.list(client: client) } catch { failed = true }
        }
    }

    private func pick(_ course: GarminCourseSummary) async {
        guard let client else { return }
        loadingId = course.id
        defer { loadingId = nil }
        guard let data = try? await GarminCourses.gpx(client: client, id: course.id) else {
            failed = true
            courses = nil
            return
        }
        onPick(data)
        dismiss()
    }

    private func detail(_ course: GarminCourseSummary) -> String {
        String(format: RacesConstants.courseDetailFormat, RacesText.km((course.meters ?? 0) / RacesConstants.metersPerKm), Int((course.elevationGain ?? 0).rounded()))
    }
}
