-- =====================================================
-- 초기 데이터 (개발·테스트용)
-- 운영 전 superadmin 이메일을 실제 원장 이메일로 변경
-- =====================================================

-- superadmin 승인 처리 (가입 후 실행)
-- update staff_profiles set staff_role='superadmin', approved=true
-- where email='hospital-admin@ajoumc.or.kr';

-- 테스트 환자 (실제 주민번호 절대 입력 금지)
insert into patients (chart_number, name_display, birth_date, gender, admission_status)
values
  ('2025-000001', '홍*동', '1980-05-15', 'M', 'outpatient'),
  ('2025-000002', '김*희', '1992-11-20', 'F', 'inpatient'),
  ('2025-000003', '이*수', '1975-03-08', 'M', 'discharged')
on conflict do nothing;
