import SwiftUI

struct PatientChartView: View {
    @EnvironmentObject private var vm: HospitalViewModel
    let patient: Patient
    @State private var records: [ChartRecord] = []
    @State private var admissions: [Admission] = []
    @State private var prescriptions: [Prescription] = []
    @State private var showNewRecord = false

    var body: some View {
        VStack(spacing: 0) {
            // 환자 헤더
            PatientHeaderView(patient: patient)

            Divider()

            // 탭
            Picker("탭", selection: $vm.selectedTab) {
                ForEach(HospitalViewModel.ChartTab.allCases, id: \.self) { tab in
                    Label(tab.label, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            // 탭 내용
            switch vm.selectedTab {
            case .chart:
                ChartRecordListView(records: records, patient: patient)
            case .admission:
                AdmissionView(patient: patient, admissions: admissions)
            case .prescription:
                PrescriptionListView(patient: patient, prescriptions: prescriptions)
            case .psychology:
                PsychologyView(patient: patient, records: records.filter { $0.record_type == .psychology })
            }
        }
        .toolbar {
            if vm.selectedTab == .chart && vm.canViewCharts {
                ToolbarItem {
                    Button("진료기록 추가") { showNewRecord = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            await loadAll()
        }
        .onChange(of: patient.id) { _, _ in Task { await loadAll() } }
    }

    private func loadAll() async {
        async let r = HospitalRepository.shared.fetchChartRecords(patientId: patient.id)
        async let a = HospitalRepository.shared.fetchAdmissions(patientId: patient.id)
        async let p = HospitalRepository.shared.fetchPrescriptions(patientId: patient.id)
        (records, admissions, prescriptions) = (try! await r, try! await a, try! await p)
    }
}

struct PatientHeaderView: View {
    let patient: Patient
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: patient.gender == .male ? "person.fill" : "person.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
                .frame(width: 52, height: 52)
                .background(.blue.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(patient.name_display)
                        .font(.title2.bold())
                    Text(patient.gender.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Label(patient.chart_number, systemImage: "number")
                    Label(patient.birth_date, systemImage: "calendar")
                    Text(patient.admission_status.label)
                        .foregroundStyle(patient.admission_status == .inpatient ? .orange : .secondary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}

struct ChartRecordListView: View {
    let records: [ChartRecord]
    let patient: Patient
    var body: some View {
        if records.isEmpty {
            ContentUnavailableView("진료기록 없음", systemImage: "doc.text")
        } else {
            List(records) { record in
                ChartRecordRow(record: record)
            }
        }
    }
}

struct ChartRecordRow: View {
    let record: ChartRecord
    @State private var expanded = false
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                if !record.subjective.isEmpty {
                    SOAPSection(label: "S", title: "주관적 호소", content: record.subjective)
                }
                if !record.objective.isEmpty {
                    SOAPSection(label: "O", title: "객관적 소견", content: record.objective)
                }
                if !record.assessment.isEmpty {
                    SOAPSection(label: "A", title: "평가·진단", content: record.assessment)
                }
                if !record.plan.isEmpty {
                    SOAPSection(label: "P", title: "치료 계획", content: record.plan)
                }
                if !record.icd10_codes.isEmpty {
                    Text("ICD-10: " + record.icd10_codes.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 8)
        } label: {
            HStack {
                Text(record.visit_date, style: .date)
                    .font(.headline)
                Text(record.record_type.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SOAPSection: View {
    let label: String
    let title: String
    let content: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.blue)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.bold())
                Text(content).font(.caption)
            }
        }
    }
}

struct PrescriptionListView: View {
    let patient: Patient
    let prescriptions: [Prescription]
    var body: some View {
        if prescriptions.isEmpty {
            ContentUnavailableView("처방 내역 없음", systemImage: "pills")
        } else {
            List(prescriptions) { rx in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(rx.prescribed_at, style: .date).font(.headline)
                        Spacer()
                        Text(rx.status.label)
                            .font(.caption)
                            .foregroundStyle(rx.status == .signed ? .green : .orange)
                    }
                    ForEach(rx.medications) { med in
                        Text("• \(med.drug_name) \(med.dose) \(med.route.label) \(med.frequency) \(med.days)일")
                            .font(.caption)
                    }
                }
            }
        }
    }
}

struct PsychologyView: View {
    let patient: Patient
    let records: [ChartRecord]
    var body: some View {
        ContentUnavailableView("심리 평가", systemImage: "brain.head.profile",
                              description: Text("심리사가 작성한 평가 기록이 여기에 표시됩니다."))
    }
}
