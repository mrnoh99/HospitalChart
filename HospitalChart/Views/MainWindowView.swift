import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var vm: HospitalViewModel

    var body: some View {
        NavigationSplitView {
            PatientListView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 340)
        } content: {
            if let patient = vm.selectedPatient {
                PatientChartView(patient: patient)
            } else {
                ContentUnavailableView(
                    "환자를 선택하세요",
                    systemImage: "person.text.rectangle",
                    description: Text("좌측 목록에서 환자를 선택하면 차트가 표시됩니다.")
                )
            }
        } detail: {
            EmptyView()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("로그아웃") { Task { await vm.signOut() } }
            }
            if !vm.reviewsDueToday.isEmpty {
                ToolbarItem {
                    Label("심사 \(vm.reviewsDueToday.count)건 오늘 예정", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(vm.currentStaff.map { "아주 정신과 차트 — \($0.name) (\($0.staff_role.label))" } ?? "아주 정신과 차트")
    }
}
