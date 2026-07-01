import SwiftUI

struct PatientListView: View {
    @EnvironmentObject private var vm: HospitalViewModel
    @State private var showNewPatient = false

    var body: some View {
        VStack(spacing: 0) {
            // 검색
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("이름·차트번호 검색", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: vm.searchText) { _, _ in
                        Task { await vm.loadPatients() }
                    }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // 필터
            Picker("상태", selection: $vm.statusFilter) {
                Text("전체").tag(Optional<Patient.AdmissionStatus>.none)
                ForEach(Patient.AdmissionStatus.allCases, id: \.self) { s in
                    Text(s.label).tag(Optional(s))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .onChange(of: vm.statusFilter) { _, _ in
                Task { await vm.loadPatients() }
            }

            Divider()

            // 환자 목록
            List(vm.patients, selection: Binding(
                get: { vm.selectedPatient?.id },
                set: { id in
                    if let p = vm.patients.first(where: { $0.id == id }) {
                        vm.selectPatient(p)
                    }
                }
            )) { patient in
                PatientRow(patient: patient)
                    .tag(patient.id)
            }
            .listStyle(.sidebar)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: { showNewPatient = true }) {
                    Label("신규 환자", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("\(vm.patients.count)명")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.bar)
        }
        .navigationTitle("환자 목록")
    }
}

struct PatientRow: View {
    let patient: Patient
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(patient.name_display)
                    .font(.headline)
                Spacer()
                Text(patient.admission_status.label)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }
            Text(patient.chart_number)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
    private var statusColor: Color {
        switch patient.admission_status {
        case .inpatient:  return .orange
        case .outpatient: return .blue
        case .discharged: return .secondary
        }
    }
}
