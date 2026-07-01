import Foundation

// 의료법 §22: 진료기록 10년 보존 — is_deleted로만 삭제
// 개인정보보호법: name_enc(DB 암호화), 화면에는 name_display만 노출
struct Patient: Identifiable, Codable, Hashable {
    let id: UUID
    var chart_number: String          // 차트번호 (예: 2025-001234)
    var name_display: String          // 표시용 이름 (성*이름 마스킹 가능)
    var birth_date: String            // YYYY-MM-DD
    var gender: Gender
    var phone: String?
    var address: String?
    var emergency_contact_name: String?
    var emergency_contact_phone: String?
    var guardian_name: String?        // 보호의무자 이름
    var guardian_relationship: String?
    var guardian_phone: String?
    var admission_status: AdmissionStatus
    var attending_id: UUID?           // 주치의 staff_profile.id
    var is_deleted: Bool              // 소프트 삭제 (물리 삭제 금지)
    var created_at: Date
    var updated_at: Date

    enum Gender: String, Codable, CaseIterable {
        case male = "M"
        case female = "F"
        var label: String { self == .male ? "남" : "여" }
    }

    enum AdmissionStatus: String, Codable, CaseIterable {
        case outpatient = "outpatient"   // 외래
        case inpatient = "inpatient"     // 입원
        case discharged = "discharged"   // 퇴원
        var label: String {
            switch self {
            case .outpatient: return "외래"
            case .inpatient:  return "입원"
            case .discharged: return "퇴원"
            }
        }
        var color: String {
            switch self {
            case .outpatient: return "blue"
            case .inpatient:  return "orange"
            case .discharged: return "gray"
            }
        }
    }
}

struct PatientConsent: Identifiable, Codable {
    let id: UUID
    var patient_id: UUID
    var consent_type: ConsentType
    var consented: Bool
    var consented_at: Date?
    var consented_by: String?         // 동의자 이름
    var notes: String?
    var created_at: Date

    enum ConsentType: String, Codable {
        case personal_info = "personal_info"          // 개인정보 수집·이용
        case sensitive_info = "sensitive_info"        // 민감정보 (진단·처방)
        case third_party = "third_party"              // 제3자 제공
        case voluntary_admission = "voluntary_admission"  // 자의입원 동의
        case treatment = "treatment"                  // 치료 동의
        var label: String {
            switch self {
            case .personal_info:       return "개인정보 수집·이용 동의"
            case .sensitive_info:      return "민감정보 처리 동의"
            case .third_party:         return "개인정보 제3자 제공 동의"
            case .voluntary_admission: return "자의입원 동의서"
            case .treatment:           return "치료 동의서"
            }
        }
    }
}
