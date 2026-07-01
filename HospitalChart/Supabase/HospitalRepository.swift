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
