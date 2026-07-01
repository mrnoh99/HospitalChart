-- =====================================================
-- Row Level Security (의료법 §23: 접근 권한 제한)
-- =====================================================
alter table staff_profiles  enable row level security;
alter table patients         enable row level security;
alter table chart_records    enable row level security;
alter table admissions       enable row level security;
alter table admission_reviews enable row level security;
alter table prescriptions    enable row level security;
alter table patient_consents enable row level security;

-- 헬퍼: 현재 사용자 역할
create or replace function my_staff_role()
returns staff_role language sql security definer stable as $$
  select staff_role from staff_profiles where id = auth.uid();
$$;

-- 헬퍼: 승인된 직원 여부
create or replace function is_approved_staff()
returns boolean language sql security definer stable as $$
  select approved from staff_profiles where id = auth.uid();
$$;

-- 헬퍼: 차트 열람 가능 역할 (비서 제외)
create or replace function can_view_charts()
returns boolean language sql security definer stable as $$
  select my_staff_role() != 'secretary' and is_approved_staff();
$$;

-- 헬퍼: 처방 가능 역할
create or replace function can_prescribe()
returns boolean language sql security definer stable as $$
  select my_staff_role() in ('superadmin','attending','resident') and is_approved_staff();
$$;

-- [staff_profiles] 본인·관리자만
create policy "직원_본인_조회" on staff_profiles for select
  using (id = auth.uid() or my_staff_role() = 'superadmin');

create policy "직원_본인_수정" on staff_profiles for update
  using (id = auth.uid());

-- [patients] 차트 열람 가능 직원만 (비서 제외)
create policy "환자_조회" on patients for select
  using (can_view_charts() and not is_deleted);

create policy "환자_등록" on patients for insert
  with check (is_approved_staff() and my_staff_role() != 'secretary');

create policy "환자_수정" on patients for update
  using (can_view_charts());

-- 물리 삭제 금지 (의료법 §22)
create policy "환자_삭제_금지" on patients for delete
  using (false);

-- [chart_records] 차트 열람 가능 직원만
create policy "진료기록_조회" on chart_records for select
  using (can_view_charts() and not is_deleted);

create policy "진료기록_작성" on chart_records for insert
  with check (can_view_charts() and author_id = auth.uid());

create policy "진료기록_수정" on chart_records for update
  using (author_id = auth.uid() or my_staff_role() = 'superadmin');

-- 물리 삭제 금지 (의료법 §22)
create policy "진료기록_삭제_금지" on chart_records for delete
  using (false);

-- [admissions]
create policy "입원_조회" on admissions for select
  using (can_view_charts());

create policy "입원_등록" on admissions for insert
  with check (my_staff_role() in ('superadmin','attending'));

create policy "입원_수정" on admissions for update
  using (my_staff_role() in ('superadmin','attending'));

-- [prescriptions]
create policy "처방_조회" on prescriptions for select
  using (can_view_charts());

create policy "처방_작성" on prescriptions for insert
  with check (can_prescribe());

create policy "처방_서명" on prescriptions for update
  using (can_prescribe() and prescriber_id = auth.uid());

-- 처방 취소 시 취소 상태로만 변경 (물리 삭제 금지)
create policy "처방_삭제_금지" on prescriptions for delete
  using (false);

-- [patient_consents]
create policy "동의_조회" on patient_consents for select
  using (can_view_charts());

create policy "동의_등록" on patient_consents for insert
  with check (is_approved_staff());

-- Grant
grant usage on schema public to authenticated;
grant select, insert, update on all tables in schema public to authenticated;
