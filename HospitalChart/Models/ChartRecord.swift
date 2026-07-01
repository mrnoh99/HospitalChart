import Foundation

// 의료법 §22: 진료기록부 — SOAP 형식
// 삭제 시 is_deleted=true만 허용 (DELETE 거부)
struct ChartRecord: Identifiable, Codable {
    let id: UUID
    var patient_id: UUID
    var visit_date: Date
    var record_type: RecordType
    var subjective: String            // S: 주관적 호소
    var objective: String             // O: 객관적 소견
    var assessment: String            // A: 평가·진단
    var plan: String                  // P: 치료 계획
    var icd10_codes: [String]         // ICD-10 진단 코드 배열
    var dsm5_diagnosis: String?       // DSM-5 진단
    var mse: MentalStatusExam?        // 정신상태검사
    var author_id: UUID               // 작성자 staff_profile.id
    var is_deleted: Bool              // 소프트 삭제 (물리 삭제 금지)
    var created_at: Date
    var updated_at: Date

    enum RecordType: String, Codable, CaseIterable {
        case outpatient = "outpatient"  // 외래 진료
        case inpatient_daily = "inpatient_daily"  // 입원 경과 기록
        case admission_note = "admission_note"    // 입원 초진
        case discharge_summary = "discharge_summary" // 퇴원 요약
        case nursing = "nursing"        // 간호 기록
        case psychology = "psychology"  // 심리 기록
        case emergency = "emergency"    // 응급 기록

        var label: String {
            switch self {
            case .outpatient:        return "외래 진료"
            case .inpatient_daily:   return "경과 기록"
            case .admission_note:    return "입원 초진"
            case .discharge_summary: return "퇴원 요약"
            case .nursing:           return "간호 기록"
            case .psychology:        return "심리 기록"
            case .emergency:         return "응급 기록"
            }
        }
    }
}

// 정신상태검사 (Mental Status Examination)
struct MentalStatusExam: Codable {
    var appearance: String?           // 외모
    var behavior: String?             // 행동
    var speech: String?               // 언어
    var mood: String?                 // 기분 (환자 보고)
    var affect: String?               // 정동 (관찰)
    var thought_process: String?      // 사고 과정
    var thought_content: String?      // 사고 내용
    var perceptions: String?          // 지각 (환청·환각 등)
    var cognition: String?            // 인지 (지남력·기억·집중)
    var insight: InsightLevel?        // 병식
    var judgment: String?             // 판단력

    enum InsightLevel: String, Codable, CaseIterable {
        case none = "none"            // 병식 없음
        case partial = "partial"      // 부분적 병식
        case full = "full"            // 완전한 병식
        var label: String {
            switch self {
            case .none:    return "없음"
            case .partial: return "부분적"
            case .full:    return "완전"
            }
        }
    }
}
