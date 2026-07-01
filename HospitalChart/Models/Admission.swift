import Foundation

// 정신건강복지법 §31~44: 입원 유형별 관리
// §55: 비자의 입원 환자 정기 심사 추적
struct Admission: Identifiable, Codable {
    let id: UUID
    var patient_id: UUID
    var admission_type: AdmissionType
    var admitted_at: Date
    var discharged_at: Date?
    var ward: String?                    // 병동
    var bed_number: String?              // 병상 번호
    var attending_id: UUID               // 주치의
    var diagnosis_at_admission: String?  // 입원 시 진단
    // 동의서 (정신건강복지법 §31, §41)
    var consent_patient_signed: Bool
    var consent_patient_signed_at: Date?
    var consent_guardian_signed: Bool
    var consent_guardian_signed_at: Date?
    // 보호의무자 (§41 보호의무자입원, §43 응급입원)
    var guardian_name: String?
    var guardian_relationship: String?
    var guardian_phone: String?
    // 정기 심사 (§55) — 비자의 입원만 해당
    var next_review_date: Date?          // 다음 심사일
    var review_history: [AdmissionReview] // 심사 이력
    var is_involuntary: Bool { admission_type != .voluntary }
    var created_at: Date
    var updated_at: Date

    // 정신건강복지법 §31, §41, §43, §44
    enum AdmissionType: String, Codable, CaseIterable {
        case voluntary = "voluntary"           // §31 자의입원
        case guardian = "guardian"             // §41 보호의무자에 의한 입원
        case emergency = "emergency"           // §43 응급입원 (72시간)
        case administrative = "administrative" // §44 행정입원

        var label: String {
            switch self {
            case .voluntary:      return "자의입원 (§31)"
            case .guardian:       return "보호의무자입원 (§41)"
            case .emergency:      return "응급입원 (§43)"
            case .administrative: return "행정입원 (§44)"
            }
        }
        var requiresGuardianConsent: Bool {
            self == .guardian || self == .emergency
        }
        // 정기 심사 필요 여부 (§55: 비자의 입원만)
        var requiresPeriodicReview: Bool {
            self != .voluntary
        }
        // 초기 심사까지 기간 (일)
        var firstReviewDays: Int {
            switch self {
            case .voluntary:      return 0
            case .guardian:       return 30    // 1개월
            case .emergency:      return 3     // 72시간
            case .administrative: return 30
            }
        }
    }
}

// 정기 심사 이력 (§55)
struct AdmissionReview: Identifiable, Codable {
    let id: UUID
    var admission_id: UUID
    var review_date: Date
    var reviewer_id: UUID              // 심사 의사
    var outcome: ReviewOutcome
    var next_review_date: Date?
    var notes: String?

    enum ReviewOutcome: String, Codable {
        case continue_admission = "continue"  // 입원 계속
        case discharge = "discharge"          // 퇴원 결정
        case transfer = "transfer"            // 전원
    }
}
