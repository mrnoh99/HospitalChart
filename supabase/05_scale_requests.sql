-- =====================================================
-- 환자앱(PTCommunication) 척도 요청·수신 브리지
-- 병원(HospitalChart)과 환자앱이 공유하는 교환 테이블.
-- 연결 키: chart_number (patients.chart_number ↔ patient_accounts.chart_number)
--
-- 흐름: 병원이 요청(status='requested') → 환자가 대기 중 응답 제출
--       (status='submitted') → 병원이 assessment_scales 로 반영(status='imported').
--
-- ※ PTCommunication 의 supabase/03_scales.sql 과 동일 스키마.
--   임상 자산 교환을 위해 두 앱이 같은 Supabase 프로젝트를 공유하거나
--   동기화하여 배포한다.
-- =====================================================
create table if not exists scale_requests (
  id              uuid primary key default gen_random_uuid(),
  chart_number    text not null,
  scale_type      text not null check (scale_type in ('NDS','NAS','NSS')),
  status          text not null default 'requested'
                  check (status in ('requested','submitted','imported')),
  item_responses  jsonb,
  raw_score       int,
  requested_by    uuid references staff_profiles(id),
  requested_at    timestamptz not null default now(),
  submitted_at    timestamptz,
  created_at      timestamptz not null default now()
);
create index if not exists idx_scale_requests_chart
  on scale_requests(chart_number, status);

alter table scale_requests enable row level security;

-- 차트 열람 가능 직원만 요청·조회·반영 (비서 제외)
create policy "척도요청_조회" on scale_requests for select
  using (can_view_charts());

create policy "척도요청_생성" on scale_requests for insert
  with check (can_view_charts());

create policy "척도요청_반영" on scale_requests for update
  using (can_view_charts());

-- assessment_scales.method 에 'patient_app' 허용 (환자앱 제출본 반영)
-- 01_schema.sql 의 method 컬럼은 자유 text 이므로 별도 제약 변경 불필요.

grant select, insert, update on scale_requests to authenticated;
