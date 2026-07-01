import SwiftUI

// =====================================================
// 척도검사 통합 화면 — TrueDoc Mental 참조
// · 척도별 최신 점수 카드 (심각도 색상)
// · 재방문 시 과거 검사와 비교(추세)
// · 생성형 AI 결과 요약
// · 웹링크 발송(진료실 밖 자가응답)
// =====================================================
struct AssessmentView: View {
    @EnvironmentObject private var vm: HospitalViewModel
    let patient: Patient
    let scales: [AssessmentScale]
    var onSendLink: (ScaleType) -> Void = { _ in }
    var onReload: () -> Void = {}

    @State private var entryScale: NationalScale?

    // 척도별로 그룹핑 → 최신순 정렬
    private var byType: [(type: ScaleType, items: [AssessmentScale])] {
        Dictionary(grouping: scales, by: { $0.scale_type })
            .map { (type: $0.key, items: $0.value.sorted { $0.administered_at > $1.administered_at }) }
            .sorted { $0.type.rawValue < $1.type.rawValue }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // 발송·직접시행 바
                ScaleSendBar(onSend: onSendLink, onEnter: { entryScale = $0 })

                if scales.isEmpty {
                    ContentUnavailableView("척도검사 없음", systemImage: "list.clipboard",
                                           description: Text("웹링크를 발송하거나 태블릿으로 검사를 시행하세요."))
                        .padding(.top, 40)
                } else {
                    ForEach(byType, id: \.type) { group in
                        ScaleCard(group: group)
                    }
                }
            }
            .padding(16)
        }
        .sheet(item: $entryScale) { scale in
            ScaleEntryView(patient: patient, scale: scale, onSaved: onReload)
                .environmentObject(vm)
        }
    }
}

// 척도 발송·직접시행 바
struct ScaleSendBar: View {
    var onSend: (ScaleType) -> Void
    var onEnter: (NationalScale) -> Void
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.clipboard")
                .foregroundStyle(AppColor.accent)
            Text("척도검사")
                .font(.subheadline.bold())
            Spacer()
            // 한국인 정신건강 척도 직접 시행 (문항 입력·자동 해석)
            Menu {
                ForEach(NationalScale.allCases) { scale in
                    Button(scale.title) { onEnter(scale) }
                }
            } label: {
                Label("직접 시행", systemImage: "square.and.pencil")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            // 진료실 밖 자가응답용 웹링크
            Menu {
                ForEach(ScaleType.allCases, id: \.self) { type in
                    Button(type.label) { onSend(type) }
                }
            } label: {
                Label("웹링크 발송", systemImage: "link")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(12)
        .background(AppColor.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// 척도별 카드: 최신 점수 + 심각도 + 추세 + AI 요약
struct ScaleCard: View {
    let group: (type: ScaleType, items: [AssessmentScale])

    private var latest: AssessmentScale? { group.items.first }
    private var previous: AssessmentScale? { group.items.dropFirst().first }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.type.label).font(.headline)
                    Text(group.type.domain)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let latest {
                    SeverityBadge(severity: latest.status == .sent ? .unknown : latest.severity)
                }
            }

            if let latest {
                // 점수 + 추세
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if latest.status == .sent {
                        Text("응답 대기").font(.title3).foregroundStyle(.secondary)
                    } else {
                        Text("\(latest.raw_score)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(severityColor(latest.severity))
                        Text("/ \(group.type.maxScore)")
                            .font(.caption).foregroundStyle(.secondary)
                        if let previous, latest.status != .sent {
                            TrendIndicator(current: latest.raw_score,
                                           previous: previous.raw_score,
                                           reversed: group.type.isReversed)
                        }
                    }
                    Spacer()
                    Text(latest.administered_at, style: .date)
                        .font(.caption).foregroundStyle(.secondary)
                    Text(latest.method.label)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.gray.opacity(0.15), in: Capsule())
                }

                // 점수 막대 (통합 화면 시각화)
                ScoreBar(score: latest.raw_score, max: group.type.maxScore,
                         color: severityColor(latest.severity),
                         reversed: group.type.isReversed)

                // AI 결과 요약 (TrueDoc Mental 국내 최초 도입 참조)
                if let ai = latest.ai_summary, !ai.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles").foregroundStyle(.purple)
                        Text(ai).font(.caption)
                    }
                    .padding(8)
                    .background(.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }

                // 과거 이력 (재방문 비교)
                if group.items.count > 1 {
                    ScaleHistoryRow(items: Array(group.items.prefix(6)),
                                    reversed: group.type.isReversed)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.15)))
    }
}

// 심각도 → 색상
func severityColor(_ s: Severity) -> Color {
    switch s {
    case .none:     return AppColor.success
    case .mild:     return AppColor.warning
    case .moderate: return AppColor.inpatient
    case .severe:   return AppColor.danger
    case .unknown:  return .secondary
    }
}

struct SeverityBadge: View {
    let severity: Severity
    var body: some View {
        Text(severity.label)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(severityColor(severity), in: Capsule())
    }
}

// 추세 표시 (이전 대비 증감) — 역방향 척도(K-MMSE)는 개선/악화 반대
struct TrendIndicator: View {
    let current: Int
    let previous: Int
    let reversed: Bool
    var body: some View {
        let delta = current - previous
        let improved = reversed ? delta > 0 : delta < 0
        HStack(spacing: 2) {
            Image(systemName: delta == 0 ? "minus" : (delta > 0 ? "arrow.up" : "arrow.down"))
            Text("\(abs(delta))")
        }
        .font(.caption.bold())
        .foregroundStyle(delta == 0 ? .secondary : (improved ? AppColor.success : AppColor.danger))
    }
}

struct ScoreBar: View {
    let score: Int
    let max: Int
    let color: Color
    var reversed: Bool = false
    var body: some View {
        GeometryReader { geo in
            let ratio = Swift.max(0, Swift.min(1, Double(score) / Double(max)))
            ZStack(alignment: .leading) {
                Capsule().fill(.gray.opacity(0.15))
                Capsule().fill(color).frame(width: geo.size.width * ratio)
            }
        }
        .frame(height: 8)
    }
}

// 과거 검사 이력 한 줄 (점수 칩)
struct ScaleHistoryRow: View {
    let items: [AssessmentScale]   // 최신순
    let reversed: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("경과").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                // 과거→현재 순으로 표시
                ForEach(items.reversed()) { item in
                    VStack(spacing: 2) {
                        Text("\(item.raw_score)")
                            .font(.caption2.bold())
                            .foregroundStyle(severityColor(item.severity))
                        Text(item.administered_at, format: .dateTime.month().day())
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}
