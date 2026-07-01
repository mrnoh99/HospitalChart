# CLAUDE.md — 아주 정신과 차트 (HospitalChart)

정신건강의학과 전용 전자의무기록(EMR) macOS 앱

## 프로젝트 개요
- **무엇**: 대학병원 정신건강의학과 EMR — 진료기록·처방·입원 관리
- **기술**: macOS 14+ · Swift + SwiftUI · Supabase (Auth/Postgres/Storage)
- **브랜치**: `claude/psychiatric-emr-system-g4d3o3`
- **언어**: UI·커밋 모두 한국어 우선

## 법령 준수 (절대 유지)

### 의료법
- **§22 진료기록 보존**: 10년 — `is_deleted=true` 소프트 삭제만 허용, 물리 DELETE 금지
- **§23 전자의무기록**: role-based 접근제한 + audit_log 자동 기록 + 처방 전자서명(signed_at)

### 정신건강복지법
- **§31 자의입원** / **§41 보호의무자입원** / **§43 응급입원** / **§44 행정입원** — 입원 유형 코드 필수
- **§55 정기심사**: 비자의 입원 → 1·3·6개월 심사일 자동 계산·알림

### 개인정보보호법
- 환자 이름·주민번호: DB **pgcrypto AES-256 암호화**
- 진단·처방: nurse 이상 역할만 열람 (RLS 강제)
- 수집·제공 **동의 이력** patient_consents 테이블에 보관

## 저장소 구조
```
HospitalChart/
  App/           HospitalChartApp.swift (진입점·인증)
  Models/        Patient · ChartRecord · Admission · Prescription · AssessmentScale
  Views/         LoginView · MainWindowView · PatientListView
                 PatientChartView · TimelineView · AssessmentView · AdmissionView
  ViewModel/     HospitalViewModel (ObservableObject)
  Supabase/      SupabaseClient · HospitalRepository
  Design/        AppDesign (색상·폰트·공통 컴포넌트)
supabase/        01_schema → 02_rls → 03_audit_log → 04_seeds 순 실행
docs/            의료법_준수사항.md
```

### 진료차트 탭 순서 (PatientChartView)
`타임라인`(기본) · `진료기록`(SOAP) · `척도검사` · `입원` · `처방` · `심리`

## 사용자 역할 (staff_role)
| 역할 | 설명 | 주요 권한 |
|------|------|----------|
| superadmin | 원장 (1명) | 전체 관리·모든 차트 |
| attending | 주치의 | 담당 환자 CRUD |
| resident | 전공의 | 담당 환자 CRUD (지도 하) |
| nurse | 간호사 | 간호기록·처방 확인 |
| pa | PA | 지정 범위 내 접근 |
| psychologist | 심리사 | 심리평가 기록 |
| secretary | 비서 | 예약·행정 (차트 열람 불가) |

## 진료차트 설계 — TrueDoc Mental 참조
정신건강의학과 특화 클라우드 EMR **트루닥 멘탈(TrueDoc Mental)**의 진료차트 UX를 참조.
| 참조 기능 | 구현 |
|-----------|------|
| **시간순 통합 배열** (진료·검사·처방을 한 시간축) | `Views/TimelineView.swift` — `.timeline` 탭(기본) |
| **척도검사** (환자 자가응답, 실시간 점수) | `Models/AssessmentScale.swift` + `Views/AssessmentView.swift` — `.assessment` 탭 |
| **웹링크 발송** (진료실 밖 스마트폰/PC 응답) | `sendScaleLink()` · `method=web_link` |
| **재방문 과거 비교** (추세) | `ScaleCard` 추세 표시 + `ScaleHistoryRow` |
| **생성형 AI 결과 요약** | `assessment_scales.ai_summary` 필드 + 보라색 요약 카드 |
| **반복 처방 빠른 입력** | `repeatLastPrescription()` — 직전 처방 복제(미서명 draft) |
| **통합 점수 화면** (척도별 심각도 색상) | `AssessmentView` 카드 + 점수 막대 |

- 척도 종류: 한국형 국가척도(NDS/NAS/NSS) + 국제표준(PHQ-9·GAD-7·PHQ-15·PDSS·Y-BOCS·ISI·AUDIT-K·MDQ·K-MMSE). 절단점 기반 심각도 자동 판정(`ScaleType.severity`).
- 척도검사도 진료 보조기록 → **물리 삭제 금지**(의료법 §22, RLS `false`) + `audit_log` 자동 기록(§23).

## 핵심 도메인 규칙
- 진료기록 삭제: `is_deleted = true` 처리 (DELETE RLS로 거부)
- 모든 patients/chart_records 접근: `audit_log` 트리거 자동 기록
- 처방전 발행: `signed_at + prescriber_id` 필수 (미서명 = draft)
- 비자의 입원: `next_review_date` 자동 계산 (입원일 + 1·3·6개월)
- 빌드 환경: **macOS Xcode 15.2+** 필요, XcodeGen(`project.yml`)으로 프로젝트 생성
