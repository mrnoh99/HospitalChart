import Foundation
import Supabase

class HospitalRepository {
    static let shared = HospitalRepository()
    private init() {}

    // MARK: - 인증

    func signIn(email: String, password: String) async throws -> Session {
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func currentSession() async -> Session? {
        try? await supabase.auth.session
    }

    func myProfile() async throws -> StaffProfile {
        let uid = try await supabase.auth.session.user.id
        return try await supabase.from("staff_profiles")
            .select()
            .eq("id", value: uid)
            .single()
            .execute()
            .value
    }

    // MARK: - 환자 목록

    func fetchPatients(status: Patient.AdmissionStatus? = nil, search: String = "") async throws -> [Patient] {
        var query = supabase.from("patients")
            .select()
            .eq("is_deleted", value: false)
            .order("chart_number")

        if let status { query = query.eq("admission_status", value: status.rawValue) }
        if !search.isEmpty { query = query.ilike("name_display", pattern: "%\(search)%") }

        return try await query.execute().value
    }

    func fetchPatient(id: UUID) async throws -> Patient {
        try await supabase.from("patients")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createPatient(_ patient: Patient) async throws -> Patient {
        try await supabase.from("patients")
            .insert(patient)
            .select()
            .single()
            .execute()
            .value
    }

    func updatePatient(_ patient: Patient) async throws {
        try await supabase.from("patients")
            .update(patient)
            .eq("id", value: patient.id)
            .execute()
    }

    // 소프트 삭제 (의료법 §22: 물리 삭제 금지)
    func softDeletePatient(id: UUID) async throws {
        try await supabase.from("patients")
            .update(["is_deleted": true])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - 진료기록

    func fetchChartRecords(patientId: UUID) async throws -> [ChartRecord] {
        try await supabase.from("chart_records")
            .select()
            .eq("patient_id", value: patientId)
            .eq("is_deleted", value: false)
            .order("visit_date", ascending: false)
            .execute()
            .value
    }

    func createChartRecord(_ record: ChartRecord) async throws -> ChartRecord {
        try await supabase.from("chart_records")
            .insert(record)
            .select()
            .single()
            .execute()
            .value
    }

    func updateChartRecord(_ record: ChartRecord) async throws {
        try await supabase.from("chart_records")
            .update(record)
            .eq("id", value: record.id)
            .execute()
    }

    // MARK: - 입원

    func fetchAdmissions(patientId: UUID) async throws -> [Admission] {
        try await supabase.from("admissions")
            .select()
            .eq("patient_id", value: patientId)
            .order("admitted_at", ascending: false)
            .execute()
            .value
    }

    func currentAdmission(patientId: UUID) async throws -> Admission? {
        let results: [Admission] = try await supabase.from("admissions")
            .select()
            .eq("patient_id", value: patientId)
            .is("discharged_at", value: "null")
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func createAdmission(_ admission: Admission) async throws -> Admission {
        try await supabase.from("admissions")
            .insert(admission)
            .select()
            .single()
            .execute()
            .value
    }

    func dischargePatient(admissionId: UUID, dischargedAt: Date) async throws {
        try await supabase.from("admissions")
            .update(["discharged_at": dischargedAt.ISO8601Format()])
            .eq("id", value: admissionId)
            .execute()
    }

    // MARK: - 처방

    func fetchPrescriptions(patientId: UUID) async throws -> [Prescription] {
        try await supabase.from("prescriptions")
            .select()
            .eq("patient_id", value: patientId)
            .order("prescribed_at", ascending: false)
            .execute()
            .value
    }

    func createPrescription(_ rx: Prescription) async throws -> Prescription {
        try await supabase.from("prescriptions")
            .insert(rx)
            .select()
            .single()
            .execute()
            .value
    }

    // 처방 전자서명 (의료법 §23)
    func signPrescription(id: UUID, prescriberId: UUID) async throws {
        try await supabase.from("prescriptions")
            .update(["status": "signed",
                     "signed_at": Date().ISO8601Format(),
                     "prescriber_id": prescriberId.uuidString])
            .eq("id", value: id)
            .execute()
    }

    // 과거 처방 반복 (TrueDoc Mental: 반복 진료·처방 드래그앤드롭 입력 참조)
    // 가장 최근 서명 처방을 복제해 새 draft 처방으로 생성 → 만성질환 재방문 시 시간 절약.
    func repeatLastPrescription(patientId: UUID, prescriberId: UUID) async throws -> Prescription? {
        let past = try await fetchPrescriptions(patientId: patientId)
        guard let last = past.first(where: { $0.status != .cancelled }) else { return nil }
        let copy = Prescription(
            id: UUID(),
            patient_id: patientId,
            chart_record_id: nil,
            prescriber_id: prescriberId,
            prescribed_at: Date(),
            status: .draft,               // 반드시 재서명 필요 (의료법 §23)
            signed_at: nil,
            medications: last.medications.map {
                MedicationItem(id: UUID(), drug_name: $0.drug_name,
                               generic_name: $0.generic_name, dose: $0.dose,
                               route: $0.route, frequency: $0.frequency,
                               days: $0.days, total_quantity: $0.total_quantity,
                               notes: $0.notes)
            },
            special_instructions: last.special_instructions,
            dispensed_at: nil, dispensed_by: nil,
            created_at: Date()
        )
        return try await createPrescription(copy)
    }

    // MARK: - 척도검사 (TrueDoc Mental 참조 핵심 기능)

    func fetchAssessments(patientId: UUID) async throws -> [AssessmentScale] {
        try await supabase.from("assessment_scales")
            .select()
            .eq("patient_id", value: patientId)
            .order("administered_at", ascending: false)
            .execute()
            .value
    }

    func createAssessment(_ scale: AssessmentScale) async throws -> AssessmentScale {
        try await supabase.from("assessment_scales")
            .insert(scale)
            .select()
            .single()
            .execute()
            .value
    }

    // 환자에게 척도검사 웹링크 발송 (진료실 밖 자가응답 — 미응답 상태로 생성)
    func sendScaleLink(patientId: UUID, type: ScaleType) async throws -> AssessmentScale {
        let scale = AssessmentScale(
            id: UUID(), patient_id: patientId, chart_record_id: nil,
            scale_type: type, administered_at: Date(),
            raw_score: 0, subscores: [:],
            method: .web_link, status: .sent,
            ai_summary: nil, administered_by: nil, created_at: Date()
        )
        return try await createAssessment(scale)
    }

    // MARK: - 환자앱(PTCommunication) 척도 요청·수신

    // 대기 중 환자에게 척도 응답 요청 (환자앱 '설문' 탭에 표시됨)
    func requestPatientScale(chartNumber: String, type: NationalScale, staffId: UUID) async throws {
        struct NewRequest: Encodable {
            let chart_number: String
            let scale_type: String
            let status: String
            let requested_by: String
        }
        try await supabase.from("scale_requests")
            .insert(NewRequest(chart_number: chartNumber,
                               scale_type: type.rawValue,
                               status: "requested",
                               requested_by: staffId.uuidString))
            .execute()
    }

    // 환자가 제출한 척도 응답 조회 (차트에 반영 대기)
    func fetchSubmittedScaleRequests(chartNumber: String) async throws -> [ScaleRequest] {
        try await supabase.from("scale_requests")
            .select()
            .eq("chart_number", value: chartNumber)
            .eq("status", value: "submitted")
            .order("submitted_at", ascending: false)
            .execute()
            .value
    }

    // 제출본을 차트(assessment_scales)에 반영 후 imported 처리
    func importScaleRequest(_ req: ScaleRequest, patientId: UUID, staffId: UUID) async throws {
        guard let type = ScaleType(rawValue: req.scale_type) else { return }
        let responses = req.item_responses ?? []
        var subscores: [String: Int] = [:]
        for (i, v) in responses.enumerated() { subscores["q\(i + 1)"] = v }

        let scale = AssessmentScale(
            id: UUID(), patient_id: patientId, chart_record_id: nil,
            scale_type: type,
            administered_at: req.submitted_at ?? Date(),
            raw_score: req.raw_score ?? responses.reduce(0, +),
            subscores: subscores,
            method: .patient_app, status: .reviewed,
            ai_summary: nil, administered_by: staffId, created_at: Date()
        )
        _ = try await createAssessment(scale)
        try await supabase.from("scale_requests")
            .update(["status": "imported"])
            .eq("id", value: req.id)
            .execute()
    }

    // MARK: - 오늘 정기심사 대상 환자 (정신건강복지법 §55)

    func fetchReviewsDueToday() async throws -> [Admission] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return try await supabase.from("admissions")
            .select()
            .is("discharged_at", value: "null")
            .gte("next_review_date", value: today.ISO8601Format())
            .lt("next_review_date", value: tomorrow.ISO8601Format())
            .execute()
            .value
    }
}
