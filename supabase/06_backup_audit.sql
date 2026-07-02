-- =====================================================
-- 백업 이력·무결성 (백업 거버넌스)
-- backup_runs: 모든 백업/복구검증 실행 기록 (감사·모니터링)
-- 의료법 §23 정신: 백업 이력도 위변조 방지 — 삭제 불가, superadmin 열람.
-- 실행 순서: 01~05 이후 06
-- =====================================================
create table if not exists backup_runs (
  id              bigserial primary key,
  kind            text not null,          -- daily | weekly | monthly | yearly | restore_test | pitr
  status          text not null,          -- success | failed
  started_at      timestamptz not null default now(),
  finished_at     timestamptz,
  size_bytes      bigint,
  checksum_sha256 text,
  storage_uri     text,
  verified        boolean not null default false,   -- 복구검증 통과 여부
  verified_at     timestamptz,
  notes           text
);
create index if not exists idx_backup_runs_kind on backup_runs(kind, started_at desc);

alter table backup_runs enable row level security;

-- 열람: superadmin 만 (백업 메타는 민감 운영정보)
create policy "백업이력_조회" on backup_runs for select
  using (my_staff_role() = 'superadmin');

-- 기록: 백업 러너는 service_role(RLS 우회)로 insert/update.
-- authenticated 경로로는 삭제 금지 (위변조 방지).
create policy "백업이력_삭제금지" on backup_runs for delete
  using (false);

-- =====================================================
-- 무결성 스냅샷 — 복구검증 대조용 (핵심 테이블 행수 + 최신 시각)
-- pg_backup.sh 가 덤프 시점에 호출해 매니페스트에 기록,
-- restore_verify.sh 가 복원본과 대조한다.
-- =====================================================
create or replace function public.backup_integrity_snapshot()
returns jsonb language plpgsql security definer stable as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'taken_at', now(),
    'counts', jsonb_build_object(
      'patients',          (select count(*) from patients),
      'chart_records',     (select count(*) from chart_records),
      'assessment_scales', (select count(*) from assessment_scales),
      'prescriptions',     (select count(*) from prescriptions),
      'admissions',        (select count(*) from admissions),
      'audit_log',         (select count(*) from audit_log)
    ),
    'latest', jsonb_build_object(
      'chart_records_updated_at', (select max(updated_at) from chart_records),
      'audit_log_accessed_at',    (select max(accessed_at) from audit_log)
    ),
    -- 보존 무결성(§22): 소프트삭제 비율 — 물리삭제는 RLS 로 원천 차단됨
    'retention', jsonb_build_object(
      'patients_soft_deleted',      (select count(*) from patients where is_deleted),
      'chart_records_soft_deleted', (select count(*) from chart_records where is_deleted)
    )
  ) into result;
  return result;
end;
$$;

-- 최근 백업 상태 요약 뷰 (모니터링 대시보드용)
create or replace view backup_status as
  select kind,
         max(started_at) filter (where status='success')          as last_success,
         max(started_at) filter (where status='success' and verified) as last_verified,
         count(*) filter (where status='failed'
                          and started_at > now() - interval '7 days') as failures_7d
  from backup_runs
  group by kind;
