import Foundation

// =====================================================
// 한국인 정신건강 척도 해석 모듈 (NDS·NAS·NSS)
// 출처: 국립정신건강센터 「한국인 정신건강(우울·불안·스트레스) 척도
//       사용자 지침서 통합본」 — 대한신경정신의학회 개발.
// 자가보고식·4점 리커트(최근 2주)·단순합산 채점. 만 19~65세 검증.
// 이 모듈은 문항 응답 → 총점 → 심각도 → 해석문구를 자동 산출한다.
// =====================================================
enum NationalScale: String, CaseIterable, Identifiable {
    case nds = "NDS"   // 한국인 우울 척도  (12문항)
    case nas = "NAS"   // 한국인 불안 척도  (11문항)
    case nss = "NSS"   // 한국인 스트레스 척도 (11문항)

    var id: String { rawValue }

    // 대응되는 AssessmentScale.ScaleType (기록 저장 시 연결)
    var scaleType: ScaleType {
        switch self {
        case .nds: return .nds
        case .nas: return .nas
        case .nss: return .nss
        }
    }

    var title: String {
        switch self {
        case .nds: return "한국인 우울 척도 (NDS)"
        case .nas: return "한국인 불안 척도 (NAS)"
        case .nss: return "한국인 스트레스 척도 (NSS)"
        }
    }

    var instruction: String {
        let target: String
        switch self {
        case .nds: target = "우울"
        case .nas: target = "불안"
        case .nss: target = "스트레스"
        }
        return "이 검사는 \(target) 정도를 알아보기 위한 것입니다.\n최근 2주간 각 문항의 증상을 얼마나 자주 경험하였는지 선택하세요."
    }

    // 4점 리커트 응답 (0~3) — 세 척도 공통
    static let responseOptions: [(value: Int, label: String, detail: String)] = [
        (0, "전혀 그렇지 않다", "없음"),
        (1, "가끔 그렇다",     "2일 이상"),
        (2, "자주 그렇다",     "1주 이상"),
        (3, "거의 매일 그렇다", "거의 2주")
    ]

    // 표준형 문항
    var items: [String] {
        switch self {
        case .nds:
            return [
                "하루 종일 우울하다",
                "평소에는 즐겁던 일이 재미 없어졌다",
                "죽고 싶다",                              // 3번: 자살사고
                "마음속에서 뭔가 치밀어 오르는 것 같다",
                "사소한 일도 결정하기가 어렵다",
                "자신감을 잃었다",
                "앞으로도 좋은 일이 생길 것 같지 않다",
                "안절부절못하거나 느려졌다는 말을 듣는다",
                "잠을 지나치게 많이 자거나 적게 잔다",
                "식욕이 지나치게 늘거나 줄었다",
                "피곤하고 기진맥진한 상태이다",
                "하루를 생활하기가 버겁다"
            ]
        case .nas:
            return [
                "이유 없이 불안하다",
                "안절부절못한다",
                "불안이나 걱정으로 일상생활이 안된다",
                "나쁜 일이 일어날까 두렵다",
                "걱정이 많다는 것을 알면서도 걱정을 멈출 수 없다",
                "집중하는 것이 어렵다",
                "금방 피로해진다",
                "신경이 날카롭다",
                "근육이 긴장된다",
                "잠들기가 어렵거나 자는 도중 자꾸 깬다",
                "두근거림, 떨림, 입마름 등의 증상이 있다"
            ]
        case .nss:
            return [
                "스트레스를 많이 받는다",
                "변화에 적응하기 어렵다",
                "문제가 생기면 직접 처리할 자신이 없다",
                "머리가 아프다",
                "어지럽다",
                "소화가 안 된다",
                "가슴이 답답하다",
                "불안하고 초조하다",
                "쉽게 화가 난다",
                "쉽게 짜증이 난다",
                "뭘 자꾸 먹게 된다"
            ]
        }
    }

    // 단축형(Brief Version, 3문항) 문항 인덱스 (표준형 기준)
    var briefItemIndexes: [Int] {
        switch self {
        case .nds: return [0, 5, 11]   // 하루종일 우울 / 자신감 상실 / 하루 생활 버거움
        case .nas: return [1, 4, 10]   // 안절부절 / 걱정 멈출수없음 / 두근거림
        case .nss: return [1, 7, 8]    // 변화 적응 어려움 / 불안·초조 / 쉽게 화
        }
    }

    var maxScore: Int { scaleType.maxScore }         // NDS 36 / NAS·NSS 33
    var briefMaxScore: Int { 9 }                      // 3문항 × 0~3

    // 자살사고 문항 인덱스 (NDS 3번 "죽고 싶다"만 해당)
    var suicideItemIndex: Int? { self == .nds ? 2 : nil }

    // 선별 절단점 — 이 점수 이상이면 임상군 가능성 높음
    var screeningCutoff: Int {
        switch self {
        case .nds: return 9    // 9점 이상 우울장애 가능성 높음
        case .nas: return 10   // 10점 이상 불안장애 가능성 높음
        case .nss: return 11   // 11점 이상 정신건강의학과 평가 권고
        }
    }
    var briefCutoff: Int { 3 } // 단축형 3점 이상 의심 (세 척도 공통, 절단점 2.5)

    // 심각도 밴드 (하한 점수, 라벨, 참고 T점수 범위)
    var bands: [(lower: Int, label: String, tRange: String)] {
        switch self {
        case .nds:
            return [
                (0,  "정상",              "T ≤ 45"),
                (9,  "경증 우울장애",      "T 46–55"),
                (19, "중등도 우울장애",    "T 56–66"),
                (29, "중증 우울장애",      "T ≥ 67")
            ]
        case .nas:
            return [
                (0,  "정상",              "T ≤ 46"),
                (10, "경증 불안장애",      "T 47–55"),
                (17, "중등도 불안장애",    "T 56–65"),
                (25, "중증 불안장애",      "T ≥ 66")
            ]
        case .nss:
            return [
                (0,  "낮은 수준의 스트레스",        "T ≤ 48"),
                (11, "중등도 이상의 스트레스",      "T 49–62"),
                (21, "매우 높은 중증 수준의 스트레스", "T ≥ 63")
            ]
        }
    }

    // 총점 → 심각도 라벨
    func bandLabel(for score: Int) -> String {
        var result = bands.first?.label ?? "-"
        for band in bands where score >= band.lower { result = band.label }
        return result
    }

    // 총점 → 심각도 Severity (색상·배지 공용)
    func severity(for score: Int) -> Severity { scaleType.severity(for: score) }

    // 해석 문구 자동 생성 (지침서 표현 반영)
    func interpretation(for score: Int, itemResponses: [Int]? = nil) -> ScaleInterpretation {
        let band = bandLabel(for: score)
        let positive = score >= screeningCutoff

        var lines: [String] = []
        lines.append("총점 \(score) / \(maxScore)점 — \(band)")

        switch self {
        case .nds:
            lines.append(positive
                ? "절단점 9점 이상 → 우울장애 가능성이 높습니다. 정신건강의학과적 평가를 권고합니다."
                : "절단점 9점 미만 → 정상 범위입니다.")
        case .nas:
            lines.append(positive
                ? "절단점 10점 이상 → 불안장애 가능성이 높습니다. 정신건강의학과적 평가를 권고합니다."
                : "절단점 10점 미만 → 정상 범위입니다.")
        case .nss:
            if score >= 21 {
                lines.append("21점 이상 → 반드시 전문적인 평가가 필요한 상태입니다.")
            } else if score >= 11 {
                lines.append("11점 이상 → 정신건강의학과적 평가를 권고합니다.")
            } else {
                lines.append("11점 미만 → 낮은 수준의 스트레스입니다.")
            }
        }

        // 자살사고 문항(NDS 3번) 별도 경고
        var suicideAlert = false
        if let idx = suicideItemIndex, let resp = itemResponses, idx < resp.count, resp[idx] >= 1 {
            suicideAlert = true
            lines.append("⚠️ 자살사고 문항('죽고 싶다')에 응답이 확인되었습니다. 자살위험 평가 및 안전계획이 필요합니다.")
        }

        return ScaleInterpretation(
            score: score, maxScore: maxScore, bandLabel: band,
            screeningPositive: positive, suicideAlert: suicideAlert,
            severity: severity(for: score), lines: lines
        )
    }

    // 원점수 → T점수 (NDS만 지침서 규준표 제공)
    func tScore(for score: Int) -> Int? {
        guard self == .nds else { return nil }
        let table: [Int: Int] = [
            0:36, 1:37, 2:38, 3:39, 4:40, 5:41, 6:43, 7:44, 8:45, 9:46,
            10:47, 11:48, 12:49, 13:50, 14:51, 15:52, 16:53, 17:54, 18:55,
            19:56, 20:57, 21:58, 22:60, 23:61, 24:62, 25:63, 26:64, 27:65,
            28:66, 29:67, 30:68, 31:69, 32:70, 33:71, 34:72, 35:73, 36:75
        ]
        return table[max(0, min(maxScore, score))]
    }
}

// 해석 결과
struct ScaleInterpretation {
    let score: Int
    let maxScore: Int
    let bandLabel: String
    let screeningPositive: Bool
    let suicideAlert: Bool
    let severity: Severity
    let lines: [String]
}
