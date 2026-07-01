-- =====================================================
-- 아주 정신과 차트 — 데이터베이스 스키마
-- 실행 순서: 01 → 02 → 03 → 04
-- =====================================================

-- [확장]
create extension if not exists "pgcrypto";  -- AES 암호화 (개인정보보호법)
create extension if not exists "pg_net";    -- Edge Function 호출

-- [직원 역할 ENUM]
create type staff_role as enum (
  'superadmin', 'attending', 'resident',
  'nurse', 'pa', 'psychologist', 'secretary'
);

-- [입원 유형 ENUM] (정신건강복지법 §31~44)
create type admission_type as enum (
  'voluntary',      -- §31 자의입원
  'guardian',       -- §41 보호의무자에 의한 입원
  'emergency',      -- §43 응급입원
  'administrative'  -- §44 행정입원
);

-- [환자 상태 ENUM]
create type admission_status as enum ('outpatient', 'inpatient', 'discharged');

-- [처방 상태 ENUM]
create type prescription_status as enum ('draft', 'signed', 'dispensed', 'cancelled');

-- =====================================================
-- 직원 프로필 (auth.users 기반)
-- =====================================================
create table if not exists staff_profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text not null,
  email         text not null,
  phone         text,
  staff_role    staff_role not null default 'resident',
  license_number text,              -- 의사 면허 번호 (처방전에 필요)
  approved      boolean not null default false,
  created_at    timestamptz not null default now()
);

-- superadmin 자동 생성 트리거
create or replace function public.handle_new_staff()
returns trigger language plpgsql security definer as $$
begin
  insert into public.staff_profiles(id, name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)), new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace trigger on_staff_signup
  after insert on auth.users
  for each row execute procedure public.handle_new_staff();

-- =====================================================
-- 환자 (의료법 §22: 10년 보존, 개인정보보호법: 이름 암호화)
-- =====================================================
create table if not exists patients (
  id                       uuid primary key default gen_random_uuid(),
  chart_number             text not null unique,     -- 차트번호 (2025-001234)
  name_display             text not null,            -- 표시용 이름 (마스킹 가능)
  name_enc                 bytea,                    -- AES-256 암호화 이름 (pgcrypto)
  birth_date               date not null,
  gender                   char(1) not null check (gender in ('M','F')),
  registration_number_hash text,                     -- 주민번호 bcrypt 해시 (검색용)
  phone                    text,
  address                  text,
  emergency_contact_name   text,
  emergency_contact_phone  text,
  guardian_name            text,                     -- 보호의무자
  guardian_relationship    text,
  guardian_phone           text,
  admission_status         admission_status not null default 'outpatient',
  attending_id             uuid references staff_profiles(id),
  is_deleted               boolean not null default false,  -- 소프트 삭제 (의료법 §22)
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

-- updated_at 자동 갱신
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;
create trigger patients_updated_at before update on patients
  for each row execute procedure update_updated_at();

-- =====================================================
-- 진료기록부 (의료법 §22: SOAP 형식, 10년 보존)
-- =====================================================
create table if not exists chart_records (
  id           uuid primary key default gen_random_uuid(),
  patient_id   uuid not null references patients(id),
  visit_date   timestamptz not null default now(),
  record_type  text not null default 'outpatient',
  subjective   text not null default '',   -- S: 주관적 호소
  objective    text not null default '',   -- O: 객관적 소견
  assessment   text not null default '',   -- A: 평가·진단
  plan         text not null default '',   -- P: 치료 계획
  icd10_codes  text[] not null default '{}',
  dsm5_diagnosis text,
  mse          jsonb,                      -- 정신상태검사 (MSE)
  author_id    uuid not null references staff_profiles(id),
  is_deleted   boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create trigger chart_records_updated_at before update on chart_records
  for each row execute procedure update_updated_at();

-- =====================================================
-- 입원 관리 (정신건강복지법 §31~44)
-- =====================================================
create table if not exists admissions (
  id                          uuid primary key default gen_random_uuid(),
  patient_id                  uuid not null references patients(id),
  admission_type              admission_type not null,
  admitted_at                 timestamptz not null default now(),
  discharged_at               timestamptz,
  ward                        text,
  bed_number                  text,
  attending_id                uuid not null references staff_profiles(id),
  diagnosis_at_admission      text,
  consent_patient_signed      boolean not null default false,
  consent_patient_signed_at   timestamptz,
  consent_guardian_signed     boolean not null default false,
  consent_guardian_signed_at  timestamptz,
  guardian_name               text,
  guardian_relationship       text,
  guardian_phone              text,
  -- 정기 심사 (§55)
  next_review_date            date,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);
create trigger admissions_updated_at before update on admissions
  for each row execute procedure update_updated_at();

-- 입원 시 next_review_date 자동 계산 (§55)
create or replace function set_review_date()
returns trigger language plpgsql as $$
begin
  if new.admission_type = 'emergency' then
    new.next_review_date := (new.admitted_at + interval '3 days')::date;
  elsif new.admission_type in ('guardian','administrative') then
    new.next_review_date := (new.admitted_at + interval '1 month')::date;
  end if;
  return new;
end;
$$;
create trigger admissions_review_date before insert on admissions
  for each row execute procedure set_review_date();

-- =====================================================
-- 정기 심사 이력 (§55)
-- =====================================================
create table if not exists admission_reviews (
  id               uuid primary key default gen_random_uuid(),
  admission_id     uuid not null references admissions(id),
  review_date      date not null,
  reviewer_id      uuid not null references staff_profiles(id),
  outcome          text not null check (outcome in ('continue','discharge','transfer')),
  next_review_date date,
  notes            text,
  created_at       timestamptz not null default now()
);

-- =====================================================
-- 처방전 (의료법 §23: 전자서명 필수, 2년 보존)
-- =====================================================
create table if not exists prescriptions (
  id                   uuid primary key default gen_random_uuid(),
  patient_id           uuid not null references patients(id),
  chart_record_id      uuid references chart_records(id),
  prescriber_id        uuid not null references staff_profiles(id),
  prescribed_at        timestamptz not null default now(),
  status               prescription_status not null default 'draft',
  signed_at            timestamptz,   -- 전자서명 시각 (의료법 §23)
  medications          jsonb not null default '[]',
  special_instructions text,
  dispensed_at         timestamptz,
  dispensed_by         text,
  created_at           timestamptz not null default now()
);

-- =====================================================
-- 환자 동의 이력 (개인정보보호법)
-- =====================================================
create table if not exists patient_consents (
  id            uuid primary key default gen_random_uuid(),
  patient_id    uuid not null references patients(id),
  consent_type  text not null,
  consented     boolean not null,
  consented_at  timestamptz,
  consented_by  text,
  notes         text,
  created_at    timestamptz not null default now()
);
