-- =====================================================
-- 접근 기록 로그 (의료법 §23: 전자의무기록 접근 이력 보존)
-- =====================================================
create table if not exists audit_log (
  id          bigserial primary key,
  user_id     uuid references auth.users(id),
  table_name  text not null,
  record_id   uuid,
  action      text not null,   -- SELECT, INSERT, UPDATE
  details     jsonb,
  ip_address  text,
  accessed_at timestamptz not null default now()
);

-- audit_log 자체는 삭제 불가 (의료법 §23)
alter table audit_log enable row level security;
create policy "감사로그_삽입만" on audit_log for insert with check (true);
create policy "감사로그_조회_관리자" on audit_log for select
  using (my_staff_role() = 'superadmin');
create policy "감사로그_삭제금지" on audit_log for delete using (false);

-- 환자 차트 접근 시 자동 기록 함수
create or replace function log_chart_access()
returns trigger language plpgsql security definer as $$
begin
  insert into audit_log(user_id, table_name, record_id, action)
  values (auth.uid(), tg_table_name, new.id, tg_op);
  return new;
end;
$$;

-- INSERT·UPDATE 시 기록 (SELECT는 Supabase RPC로 별도 기록)
create trigger audit_chart_records
  after insert or update on chart_records
  for each row execute procedure log_chart_access();

create trigger audit_admissions
  after insert or update on admissions
  for each row execute procedure log_chart_access();

create trigger audit_prescriptions
  after insert or update on prescriptions
  for each row execute procedure log_chart_access();

create trigger audit_assessment_scales
  after insert or update on assessment_scales
  for each row execute procedure log_chart_access();

-- 환자 조회 기록 RPC (클라이언트가 환자 열람 시 호출)
create or replace function log_patient_view(patient_id uuid)
returns void language plpgsql security definer as $$
begin
  insert into audit_log(user_id, table_name, record_id, action)
  values (auth.uid(), 'patients', patient_id, 'VIEW');
end;
$$;
