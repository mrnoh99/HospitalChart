import SwiftUI

struct AdmissionView: View {
    let patient: Patient
    let admissions: [Admission]
    @State private var showNewAdmission = false
    @EnvironmentObject private var vm: HospitalViewModel

    var body: some View {
        VStack {
            if let current = admissions.first(where: { $0.discharged_at == nil }) {
                // 현재 입원 중
                CurrentAdmissionCard(admission: current)
            }

            if admissions.isEmpty {
                ContentUnavailableView("입원 이력 없음", systemImage: "bed.double")
            } else {
                List(admissions) { admission in
                    AdmissionRow(admission: admission)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if vm.canViewCharts && vm.currentStaff?.staff_role.canAdmit == true {
                HStack {
                    Spacer()
                    Button("입원 처리") { showNewAdmission = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding(12)
                .background(.bar)
            }
        }
        .sheet(isPresented: $showNewAdmission) {
            NewAdmissionSheet(patient: patient)
        }
    }
}

struct CurrentAdmissionCard: View {
    let admission: Admission
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("현재 입원 중", systemImage: "bed.double.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text(admission.admission_type.label)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 16) {
                Label(admission.admitted_at.formatted(date: .abbreviated, time: .omitted),
                      systemImage: "calendar")
                if let ward = admission.ward {
                    Label(ward, systemImage: "building.2")
                }
                if let bed = admission.bed_number {
                    Label(bed, systemImage: "bed.double")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // 정기 심사 알림 (정신건강복지법 §55)
            if admission.is_involuntary, let reviewDate = admission.next_review_date {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("정기 심사: \(reviewDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption.bold())
                }
                .padding(8)
                .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}

struct AdmissionRow: View {
    let admission: Admission
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(admission.admission_type.label).font(.headline)
                Text(admission.admitted_at.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let d = admission.discharged_at {
                Text(d.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("입원 중").font(.caption).foregroundStyle(.orange)
            }
        }
    }
}

struct NewAdmissionSheet: View {
    let patient: Patient
    @Environment(\.dismiss) private var dismiss
    @State private var type: Admission.AdmissionType = .voluntary
    @State private var ward = ""
    @State private var bed = ""
    @State private var guardianName = ""
    @State private var consentPatient = false
    @State private var consentGuardian = false

    var body: some View {
        NavigationStack {
            Form {
                Section("입원 유형 (정신건강복지법)") {
                    Picker("유형", selection: $type) {
                        ForEach(Admission.AdmissionType.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    if type == .emergency {
                        Text("⚠️ 응급입원: 72시간 이내 서류 구비 필수 (§43)")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                Section("병동·병상") {
                    TextField("병동", text: $ward)
                    TextField("병상 번호", text: $bed)
                }

                if type.requiresGuardianConsent {
                    Section("보호의무자") {
                        TextField("보호의무자 이름", text: $guardianName)
                        Toggle("보호의무자 동의서 서명", isOn: $consentGuardian)
                    }
                }

                Section("동의서") {
                    Toggle("환자 본인 동의 (자의입원 §31)", isOn: $consentPatient)
                }

                if type == .voluntary {
                    Text("자의입원: 환자가 언제든지 퇴원을 청구할 수 있습니다 (정신건강복지법 §31④).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("입원 처리")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("입원 처리") {
                        // TODO: create admission via repo
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 480, height: 500)
    }
}
