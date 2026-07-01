import Foundation

// 의료법 §23: 처방전 전자서명 필수 (signed_at + prescriber_id)
// 처방전 보존: 2년 (의료법 §22)
struct Prescription: Identifiable, Codable {
    let id: UUID
    var patient_id: UUID
    var chart_record_id: UUID?
    var prescriber_id: UUID            // 처방 의사 staff_profile.id
    var prescribed_at: Date
    var status: PrescriptionStatus
    var signed_at: Date?               // 전자서명 시각 (의료법 §23)
    var medications: [MedicationItem]
    var special_instructions: String?
    var dispensed_at: Date?
    var dispensed_by: String?
    var created_at: Date

    enum PrescriptionStatus: String, Codable {
        case draft = "draft"           // 미서명
        case signed = "signed"         // 전자서명 완료
        case dispensed = "dispensed"   // 조제 완료
        case cancelled = "cancelled"   // 취소

        var label: String {
            switch self {
            case .draft:     return "미서명"
            case .signed:    return "서명 완료"
            case .dispensed: return "조제 완료"
            case .cancelled: return "취소"
            }
        }
    }
}

struct MedicationItem: Identifiable, Codable {
    let id: UUID
    var drug_name: String              // 약품명
    var generic_name: String?          // 성분명
    var dose: String                   // 용량 (예: 10mg)
    var route: MedicationRoute         // 투여 경로
    var frequency: String              // 용법 (예: 1일 2회)
    var days: Int                      // 투여 일수
    var total_quantity: String?        // 총 조제량
    var notes: String?

    enum MedicationRoute: String, Codable, CaseIterable {
        case oral = "oral"             // 경구
        case im = "im"                 // 근주
        case iv = "iv"                 // 정주
        case sc = "sc"                 // 피하
        case topical = "topical"       // 외용
        var label: String {
            switch self {
            case .oral:    return "경구"
            case .im:      return "근주"
            case .iv:      return "정주"
            case .sc:      return "피하"
            case .topical: return "외용"
            }
        }
    }
}
