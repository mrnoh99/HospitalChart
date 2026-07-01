import SwiftUI

// =====================================================
// 한국인 정신건강 척도 실시·채점·해석 화면 (NDS·NAS·NSS)
// 문항 응답 입력 → 실시간 총점·심각도·해석 + 자살사고 경고.
// 저장 시 AssessmentScale 기록 생성(척도검사 탭·타임라인에 반영).
// =====================================================
struct ScaleEntryView: View {
    @EnvironmentObject private var vm: HospitalViewModel
    @Environment(\.dismiss) private var dismiss

    let patient: Patient
    let scale: NationalScale
    var onSaved: () -> Void = {}

    @State private var useBrief = false
    @State private var method: AssessmentScale.AdministrationMethod = .tablet
    @State private var responses: [Int?]
    @State private var isSaving = false

    init(patient: Patient, scale: NationalScale, onSaved: @escaping () -> Void = {}) {
        self.patient = patient
        self.scale = scale
        self.onSaved = onSaved
        _responses = State(initialValue: Array(repeating: nil, count: scale.items.count))
    }

    // 현재 폼에서 채점 대상 문항 인덱스
    private var activeIndexes: [Int] {
        useBrief ? scale.briefItemIndexes : Array(scale.items.indices)
    }
    private var allAnswered: Bool {
        activeIndexes.allSatisfy { responses[$0] != nil }
    }
    private var total: Int {
        activeIndexes.reduce(0) { $0 + (responses[$1] ?? 0) }
    }
    private var cutoff: Int { useBrief ? scale.briefCutoff : scale.screeningCutoff }
    private var maxScore: Int { useBrief ? scale.briefMaxScore : scale.maxScore }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                itemList
                Divider()
                resultPanel
                    .frame(width: 300)
            }
        }
        .frame(minWidth: 720, minHeight: 560)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(scale.title).font(.headline)
                Text("차트 \(patient.chart_number) · \(patient.name_display)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $useBrief) {
                Text("표준형").tag(false)
                Text("단축형").tag(true)
            }
            .pickerStyle(.segmented).fixedSize()
            Picker("", selection: $method) {
                ForEach(AssessmentScale.AdministrationMethod.allCases, id: \.self) {
                    Text($0.label).tag($0)
                }
            }
            .fixedSize()
            Button("닫기") { dismiss() }
        }
        .padding(12)
    }

    private var itemList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(scale.instruction)
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                ForEach(activeIndexes, id: \.self) { idx in
                    ItemRow(
                        number: displayNumber(idx),
                        text: scale.items[idx],
                        isSuicideItem: scale.suicideItemIndex == idx,
                        selection: Binding(
                            get: { responses[idx] },
                            set: { responses[idx] = $0 }
                        )
                    )
                }
            }
            .padding(12)
        }
    }

    // 단축형이면 1,2,3 으로 재번호
    private func displayNumber(_ idx: Int) -> Int {
        (activeIndexes.firstIndex(of: idx) ?? 0) + 1
    }

    private var resultPanel: some View {
        let interp = scale.interpretation(
            for: total,
            itemResponses: responses.map { $0 ?? 0 }
        )
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 총점
                VStack(alignment: .leading, spacing: 4) {
                    Text("총점").font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(total)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(severityColor(interp.severity))
                        Text("/ \(maxScore)").font(.callout).foregroundStyle(.secondary)
                    }
                    SeverityBadge(severity: allAnswered ? interp.severity : .unknown)
                    if !useBrief, let t = scale.tScore(for: total) {
                        Text("T점수 ≈ \(t)").font(.caption).foregroundStyle(.secondary)
                    }
                }

                ScoreBar(score: total, max: maxScore, color: severityColor(interp.severity))

                // 자살사고 경고
                if interp.suicideAlert {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("자살사고 응답 확인 — 자살위험 평가·안전계획 필요")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.danger, in: RoundedRectangle(cornerRadius: 8))
                }

                // 해석
                VStack(alignment: .leading, spacing: 6) {
                    Text("해석").font(.caption.bold())
                    ForEach(Array(interp.lines.enumerated()), id: \.offset) { _, line in
                        Text("• \(line)").font(.caption)
                    }
                }

                // 심각도 구간표
                VStack(alignment: .leading, spacing: 4) {
                    Text("점수 구간 (\(useBrief ? "단축형" : "표준형"))")
                        .font(.caption.bold())
                    if useBrief {
                        Text("• 3점 이상: 임상군 의심 (절단점 2.5)").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(scale.bands.enumerated()), id: \.offset) { i, band in
                            let upper = i + 1 < scale.bands.count ? scale.bands[i+1].lower - 1 : maxScore
                            Text("• \(band.lower)–\(upper)점: \(band.label)")
                                .font(.caption2)
                                .foregroundStyle(total >= band.lower &&
                                                 (i + 1 >= scale.bands.count || total < scale.bands[i+1].lower)
                                                 ? severityColor(interp.severity) : .secondary)
                        }
                    }
                }

                Spacer(minLength: 8)

                Button {
                    Task { await save(interp) }
                } label: {
                    if isSaving { ProgressView() }
                    else { Text("검사 저장").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!allAnswered || isSaving)

                Text("출처: 국립정신건강센터 한국인 정신건강 척도 지침서")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func save(_ interp: ScaleInterpretation) async {
        isSaving = true
        defer { isSaving = false }
        var subscores: [String: Int] = [:]
        for idx in activeIndexes { subscores["q\(idx + 1)"] = responses[idx] ?? 0 }

        let record = AssessmentScale(
            id: UUID(), patient_id: patient.id, chart_record_id: nil,
            scale_type: scale.scaleType,
            administered_at: Date(),
            raw_score: total,
            subscores: subscores,
            method: method,
            status: .reviewed,
            ai_summary: interp.lines.joined(separator: " "),
            administered_by: vm.currentStaff?.id,
            created_at: Date()
        )
        _ = try? await HospitalRepository.shared.createAssessment(record)
        onSaved()
        dismiss()
    }
}

// 문항 한 줄 (0~3 응답)
struct ItemRow: View {
    let number: Int
    let text: String
    var isSuicideItem: Bool = false
    @Binding var selection: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Text("\(number).").font(.callout.bold()).foregroundStyle(.secondary)
                Text(text).font(.callout)
                if isSuicideItem {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(AppColor.danger)
                }
            }
            Picker("", selection: $selection) {
                Text("—").tag(Int?.none)
                ForEach(NationalScale.responseOptions, id: \.value) { opt in
                    Text("\(opt.value) \(opt.label)").tag(Int?.some(opt.value))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(8)
        .background((isSuicideItem && (selection ?? 0) >= 1)
                    ? AppColor.danger.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
    }
}
