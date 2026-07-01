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
  Models/        Patient · ChartRecord · Admission · Prescription
  Views/         LoginView · MainWindowView · PatientListView
                 PatientChartView · AdmissionView · PrescriptionView
  ViewModel/     HospitalViewModel (ObservableObject)
  Supabase/      SupabaseClient · HospitalRepository
  Design/        AppDesign (색상·폰트·공통 컴포넌트)
supabase/        01_schema → 02_rls → 03_audit_log → 04_seeds 순 실행
docs/            의료법_준수사항.md
```

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

## 핵심 도메인 규칙
- 진료기록 삭제: `is_deleted = true` 처리 (DELETE RLS로 거부)
- 모든 patients/chart_records 접근: `audit_log` 트리거 자동 기록
- 처방전 발행: `signed_at + prescriber_id` 필수 (미서명 = draft)
- 비자의 입원: `next_review_date` 자동 계산 (입원일 + 1·3·6개월)
- 빌드 환경: **macOS Xcode 15.2+** 필요, XcodeGen(`project.yml`)으로 프로젝트 생성
