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

-- =====================================================
-- 척도검사 샘플 (TrueDoc Mental 참조) — 재방문 시 과거 비교 데모
-- 홍*동: PHQ-9 우울이 3회 재방문에 걸쳐 호전(20→14→8)
-- =====================================================
insert into assessment_scales (patient_id, scale_type, administered_at, raw_score, method, status, ai_summary)
select p.id, v.scale_type, v.administered_at, v.raw_score, v.method, v.status, v.ai_summary
from patients p
join (values
  ('2025-000001','PHQ-9', now() - interval '56 days', 20, 'web_link', 'reviewed',
   'PHQ-9 20점(중증). 초기 평가로 항우울제 시작 및 2주 후 재평가 권고.'),
  ('2025-000001','PHQ-9', now() - interval '28 days', 14, 'tablet',  'reviewed',
   'PHQ-9 14점(중등도). 이전 대비 6점 감소로 치료 반응 관찰됨.'),
  ('2025-000001','PHQ-9', now() - interval '2 days',  8,  'tablet',  'completed',
   'PHQ-9 8점(경도). 지속적 호전. 유지 치료 및 재발 예방 교육 권고.'),
  ('2025-000001','GAD-7', now() - interval '2 days',  6,  'tablet',  'completed', null),
  ('2025-000002','NDS',   now() - interval '5 days',  31, 'interview','reviewed',
   '한국인 우울 척도(NDS) 31/36점 — 중증 우울장애. 입원 유지 및 정기 심사 대상.')
) as v(chart_number, scale_type, administered_at, raw_score, method, status, ai_summary)
  on p.chart_number = v.chart_number
on conflict do nothing;
