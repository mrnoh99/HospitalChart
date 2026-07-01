import Foundation

struct StaffProfile: Identifiable, Codable {
    let id: UUID           // auth.users.id 와 동일
    var name: String
    var email: String
    var phone: String?
    var staff_role: StaffRole
    var specialty: String? // 전문 분야
    var license_number: String? // 면허 번호
    var approved: Bool
    var created_at: Date

    enum StaffRole: String, Codable, CaseIterable {
        case superadmin  = "superadmin"
        case attending   = "attending"    // 주치의
        case resident    = "resident"     // 전공의
        case nurse       = "nurse"        // 간호사
        case pa          = "pa"           // PA
        case psychologist = "psychologist" // 심리사
        case secretary   = "secretary"    // 비서

        var label: String {
            switch self {
            case .superadmin:   return "원장"
            case .attending:    return "주치의"
            case .resident:     return "전공의"
            case .nurse:        return "간호사"
            case .pa:           return "PA"
            case .psychologist: return "심리사"
            case .secretary:    return "비서"
            }
        }

        // 차트 열람 가능 여부
        var canViewCharts: Bool {
            self != .secretary
        }
        // 처방 가능 여부
        var canPrescribe: Bool {
            self == .superadmin || self == .attending || self == .resident
        }
        // 입원 결정 가능 여부
        var canAdmit: Bool {
            self == .superadmin || self == .attending
        }
    }
}
