# 아주 정신과 차트 (HospitalChart)

정신건강의학과 전용 전자의무기록(EMR) — macOS 앱

## 기술 스택
- **플랫폼**: macOS 14.0+
- **UI**: SwiftUI (3-column NavigationSplitView)
- **백엔드**: Supabase (Postgres + Auth + Storage)
- **빌드**: XcodeGen (`project.yml`)

## 시작하기

```bash
brew install xcodegen
cd HospitalChart  # 프로젝트 루트
cp local.properties.example local.properties  # Supabase URL·Key 입력
xcodegen generate
open HospitalChart.xcodeproj
```

## Supabase 설정 순서
1. `supabase/01_schema.sql` — 테이블 생성
2. `supabase/02_rls.sql` — Row Level Security
3. `supabase/03_audit_log.sql` — 접근 로그 트리거
4. `supabase/04_seeds.sql` — 초기 데이터 (superadmin 등록)

## 의료법령 준수
- 진료기록 10년 보존 (의료법 §22)
- EMR 접근 로그 (의료법 §23)
- 입원 유형별 관리 (정신건강복지법 §31~44)
- 정기 심사 추적 (정신건강복지법 §55)
- 환자 개인정보 암호화 (개인정보보호법)

자세한 내용: [`docs/의료법_준수사항.md`](docs/의료법_준수사항.md)
