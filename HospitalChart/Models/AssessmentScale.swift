import Foundation

// =====================================================
// 척도검사 (심리척도) — TrueDoc Mental 참조 핵심 기능
// 정신과 진료의 핵심: 환자 1명당 평균 2~12개 척도검사.
// 환자가 태블릿/스마트폰/웹링크로 자가 응답 → 실시간 점수 집계.
// 재방문 시 과거 검사와 비교 분석 + AI 결과 요약.
// =====================================================
struct AssessmentScale: Identifiable, Codable {
    let id: UUID
    var patient_id: UUID
    var chart_record_id: UUID?          // 연결된 진료기록 (선택)
    var scale_type: ScaleType
    var administered_at: Date           // 검사 시행 시각
    var raw_score: Int                  // 총점
    var subscores: [String: Int]        // 하위 척도 점수 (선택)
    var method: AdministrationMethod    // 시행 방식
    var status: ScaleStatus             // 발송/완료
    var ai_summary: String?             // 생성형 AI 결과 요약 (TrueDoc Mental 최초 도입)
    var administered_by: UUID?          // 시행 담당 직원 (자가검사면 nil)
    var created_at: Date

    // 심각도 (총점 기반 자동 판정)
    var severity: Severity { scale_type.severity(for: raw_score) }

    // 시행 방식 — 웹링크(진료실 밖) / 태블릿(진료실) / 지필
    enum AdministrationMethod: String, Codable, CaseIterable {
        case tablet = "tablet"          // 태블릿 (진료실)
        case web_link = "web_link"      // 웹링크 (진료실 밖, 스마트폰/PC)
        case paper = "paper"            // 지필
        case interview = "interview"    // 면담 평정

        var label: String {
            switch self {
            case .tablet:    return "태블릿"
            case .web_link:  return "웹링크"
            case .paper:     return "지필"
            case .interview: return "면담평정"
            }
        }
    }

    enum ScaleStatus: String, Codable {
        case sent = "sent"              // 발송됨 (미응답)
        case completed = "completed"    // 응답 완료
        case reviewed = "reviewed"      // 의사 확인 완료

        var label: String {
            switch self {
            case .sent:      return "응답 대기"
            case .completed: return "완료"
            case .reviewed:  return "확인 완료"
            }
        }
    }
}

// 심각도 밴드
enum Severity: String, Codable {
    case none = "none"          // 정상
    case mild = "mild"          // 경도
    case moderate = "moderate"  // 중등도
    case severe = "severe"      // 중증
    case unknown = "unknown"    // 미응답

    var label: String {
        switch self {
        case .none:     return "정상"
        case .mild:     return "경도"
        case .moderate: return "중등도"
        case .severe:   return "중증"
        case .unknown:  return "-"
        }
    }
}

// =====================================================
// 척도 종류 — 국내 정신과 상용 척도
// =====================================================
enum ScaleType: String, Codable, CaseIterable {
    // 한국형 국가 척도 (한국인 정서·문화 반영)
    case nds = "NDS"       // 한국인 우울 척도
    case nas = "NAS"       // 한국인 불안 척도
    case nss = "NSS"       // 한국인 스트레스 척도
    // 국제 표준 척도
    case phq9 = "PHQ-9"    // 우울 선별
    case gad7 = "GAD-7"    // 범불안
    case phq15 = "PHQ-15"  // 신체화 증상
    case pdss = "PDSS"     // 공황장애 심각도
    case ybocs = "Y-BOCS"  // 강박
    case isi = "ISI"       // 불면증
    case audit = "AUDIT-K" // 알코올 사용
    case mdq = "MDQ"       // 조울증 선별
    case kmmse = "K-MMSE"  // 인지 선별

    var label: String {
        switch self {
        case .nds:   return "한국인 우울 척도 (NDS)"
        case .nas:   return "한국인 불안 척도 (NAS)"
        case .nss:   return "한국인 스트레스 척도 (NSS)"
        case .phq9:  return "우울 (PHQ-9)"
        case .gad7:  return "불안 (GAD-7)"
        case .phq15: return "신체증상 (PHQ-15)"
        case .pdss:  return "공황장애 (PDSS)"
        case .ybocs: return "강박 (Y-BOCS)"
        case .isi:   return "불면증 (ISI)"
        case .audit: return "알코올 (AUDIT-K)"
        case .mdq:   return "조울증 선별 (MDQ)"
        case .kmmse: return "인지 선별 (K-MMSE)"
        }
    }

    // 도메인 분류 (통합 화면 색상 구분용)
    var domain: String {
        switch self {
        case .nds, .phq9, .mdq:          return "우울/기분"
        case .nas, .gad7, .pdss:         return "불안"
        case .nss:                       return "스트레스"
        case .phq15:                     return "신체증상"
        case .ybocs:                     return "강박"
        case .isi:                       return "수면"
        case .audit:                     return "물질"
        case .kmmse:                     return "인지"
        }
    }

    var maxScore: Int {
        switch self {
        case .nds, .nas, .nss: return 100  // 표준점수(T) 근사
        case .phq9:  return 27
        case .gad7:  return 21
        case .phq15: return 30
        case .pdss:  return 28
        case .ybocs: return 40
        case .isi:   return 28
        case .audit: return 40
        case .mdq:   return 13
        case .kmmse: return 30
        }
    }

    // K-MMSE는 점수가 낮을수록 위험 (역방향)
    var isReversed: Bool { self == .kmmse }

    // 총점 → 심각도 밴드 (임상 절단점 기반)
    func severity(for score: Int) -> Severity {
        switch self {
        case .phq9:
            switch score {
            case ..<5:   return .none
            case 5..<10: return .mild
            case 10..<20: return .moderate
            default:     return .severe
            }
        case .gad7:
            switch score {
            case ..<5:   return .none
            case 5..<10: return .mild
            case 10..<15: return .moderate
            default:     return .severe
            }
        case .phq15:
            switch score {
            case ..<5:   return .none
            case 5..<10: return .mild
            case 10..<15: return .moderate
            default:     return .severe
            }
        case .isi:
            switch score {
            case ..<8:    return .none
            case 8..<15:  return .mild
            case 15..<22: return .moderate
            default:      return .severe
            }
        case .pdss:
            switch score {
            case ..<6:    return .none
            case 6..<10:  return .mild
            case 10..<15: return .moderate
            default:      return .severe
            }
        case .ybocs:
            switch score {
            case ..<8:    return .none
            case 8..<16:  return .mild
            case 16..<24: return .moderate
            default:      return .severe
            }
        case .audit:
            switch score {
            case ..<8:    return .none
            case 8..<16:  return .mild
            case 16..<20: return .moderate
            default:      return .severe
            }
        case .mdq:
            return score >= 7 ? .moderate : .none  // 선별 양성 절단점
        case .kmmse:
            switch score {   // 낮을수록 위험
            case 24...:   return .none
            case 20..<24: return .mild
            case 10..<20: return .moderate
            default:      return .severe
            }
        case .nds, .nas, .nss:
            switch score {   // 표준점수 T 기준 근사
            case ..<55:   return .none
            case 55..<65: return .mild
            case 65..<75: return .moderate
            default:      return .severe
            }
        }
    }
}
