import SwiftUI

// =====================================================
// 시간순 통합 타임라인 — TrueDoc Mental 참조
// 진료기록·척도검사·처방·입원을 하나의 시간축에 통합 배열.
// "진료·기록·검사결과·처방을 시간 순으로 배열"한 GUI.
// =====================================================
struct TimelineView: View {
    let patient: Patient
    let records: [ChartRecord]
    let scales: [AssessmentScale]
    let prescriptions: [Prescription]
    let admissions: [Admission]

    // 통합 이벤트 종류
    enum EventKind {
        case record(ChartRecord)
        case scale(AssessmentScale)
        case prescription(Prescription)
        case admission(Admission)

        var date: Date {
            switch self {
            case .record(let r):       return r.visit_date
            case .scale(let s):        return s.administered_at
            case .prescription(let p): return p.prescribed_at
            case .admission(let a):    return a.admitted_at
            }
        }
        var icon: String {
            switch self {
            case .record:       return "doc.text.fill"
            case .scale:        return "list.clipboard.fill"
            case .prescription: return "pills.fill"
            case .admission:    return "bed.double.fill"
            }
        }
        var color: Color {
            switch self {
            case .record:       return AppColor.accent
            case .scale:        return .purple
            case .prescription: return AppColor.success
            case .admission:    return AppColor.inpatient
            }
        }
    }

    struct TimelineEvent: Identifiable {
        let id: String
        let kind: EventKind
    }

    private var events: [TimelineEvent] {
        var all: [TimelineEvent] = []
        all += records.map { TimelineEvent(id: "r-\($0.id)", kind: .record($0)) }
        all += scales.map { TimelineEvent(id: "s-\($0.id)", kind: .scale($0)) }
        all += prescriptions.map { TimelineEvent(id: "p-\($0.id)", kind: .prescription($0)) }
        all += admissions.map { TimelineEvent(id: "a-\($0.id)", kind: .admission($0)) }
        return all.sorted { $0.kind.date > $1.kind.date }
    }

    var body: some View {
        if events.isEmpty {
            ContentUnavailableView("기록 없음", systemImage: "chart.line.uptrend.xyaxis",
                                   description: Text("진료·척도·처방·입원 기록이 시간순으로 표시됩니다."))
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(events) { event in
                        TimelineRow(event: event)
                    }
                }
                .padding(16)
            }
        }
    }
}

struct TimelineRow: View {
    let event: TimelineView.TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 시간축 (아이콘 + 연결선)
            VStack(spacing: 0) {
                Image(systemName: event.kind.icon)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(event.kind.color, in: Circle())
                Rectangle()
                    .fill(.gray.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 26)

            // 내용 카드
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.kind.date, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                content
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.12)))
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch event.kind {
        case .record(let r):
            VStack(alignment: .leading, spacing: 3) {
                Text(r.record_type.label).font(.subheadline.bold())
                if !r.assessment.isEmpty {
                    Text("A: \(r.assessment)").font(.caption).lineLimit(2)
                }
                if let dsm = r.dsm5_diagnosis, !dsm.isEmpty {
                    Text(dsm).font(.caption2).foregroundStyle(AppColor.accent)
                }
                if !r.icd10_codes.isEmpty {
                    Text("ICD-10: " + r.icd10_codes.joined(separator: ", "))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        case .scale(let s):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.scale_type.label).font(.subheadline.bold())
                    Text("\(s.method.label) · \(s.status.label)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if s.status != .sent {
                    Text("\(s.raw_score)")
                        .font(.title3.bold())
                        .foregroundStyle(severityColor(s.severity))
                    SeverityBadge(severity: s.severity)
                }
            }
        case .prescription(let p):
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("처방").font(.subheadline.bold())
                    Text(p.status.label)
                        .font(.caption2)
                        .foregroundStyle(p.status == .signed ? AppColor.success : AppColor.inpatient)
                }
                ForEach(p.medications.prefix(4)) { med in
                    Text("• \(med.drug_name) \(med.dose) \(med.frequency)")
                        .font(.caption).lineLimit(1)
                }
                if p.medications.count > 4 {
                    Text("외 \(p.medications.count - 4)건").font(.caption2).foregroundStyle(.secondary)
                }
            }
        case .admission(let a):
            VStack(alignment: .leading, spacing: 3) {
                Text(a.admission_type.label).font(.subheadline.bold())
                if let dx = a.diagnosis_at_admission, !dx.isEmpty {
                    Text(dx).font(.caption)
                }
                if a.discharged_at == nil {
                    Text("입원 중").font(.caption2).foregroundStyle(AppColor.inpatient)
                } else if let d = a.discharged_at {
                    Text("퇴원: \(d.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
