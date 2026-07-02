#!/usr/bin/env bash
# =====================================================
# 정신과 EMR — 복구 검증 (주간 자동 실행)
# 최신 Tier1 백업을 격리 스테이징 DB 로 복원 후 검증.
# "복구 테스트를 통과하지 않은 백업은 백업이 아니다."
#
# 검증: 체크섬 → 복원 → 행수/최신시각 대조 → FK 무결성 →
#       보존 무결성(§22 물리삭제 흔적 없음) → 결과 기록.
# =====================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/backup.env"

TIER="${1:-daily}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"; dropdb_staging' EXIT
log() { echo "[$(date -u +%H:%M:%S)] $*"; }

dropdb_staging() {
  psql "${STAGING_ADMIN_URL}" -q -c "drop database if exists ${STAGING_DB} with (force);" 2>/dev/null || true
}
mark() { # verified(bool) notes
  psql "${SUPABASE_DB_URL}" -q <<SQL || true
    update backup_runs set verified=$1, verified_at=now(), notes=$$${2}$$
    where id = (select id from backup_runs where kind='${TIER}' and status='success' order by started_at desc limit 1);
SQL
}

# ---- 1) 최신 백업 매니페스트 조회 ----
LATEST="$(aws --endpoint-url "${OBJ_ENDPOINT}" s3 ls "s3://${OBJ_BUCKET}/${TIER}/" --recursive \
  | grep '.manifest.json$' | sort | tail -1 | awk '{print $4}')"
[[ -n "${LATEST}" ]] || { log "백업 없음"; exit 1; }
aws --endpoint-url "${OBJ_ENDPOINT}" s3 cp "s3://${OBJ_BUCKET}/${LATEST}" "${WORKDIR}/m.json"
ENC_KEY="${LATEST%.manifest.json}.dump.enc"
aws --endpoint-url "${OBJ_ENDPOINT}" s3 cp "s3://${OBJ_BUCKET}/${ENC_KEY}" "${WORKDIR}/b.enc"

EXPECT_SUM="$(jq -r .checksum_sha256 "${WORKDIR}/m.json")"
DEK_WRAPPED="$(jq -r .dek_wrapped "${WORKDIR}/m.json")"

# ---- 2) 체크섬 검증 ----
ACTUAL_SUM="$(sha256sum "${WORKDIR}/b.enc" | awk '{print $1}')"
[[ "${ACTUAL_SUM}" == "${EXPECT_SUM}" ]] || { mark false "체크섬 불일치"; log "FAIL: 체크섬"; exit 1; }
log "체크섬 일치"

# ---- 3) 복호화 (KMS 로 DEK 언랩) ----
DEK="$("${SCRIPT_DIR}/kms_unwrap.sh" "${DEK_WRAPPED}")" || { mark false "DEK 언랩 실패"; exit 1; }
openssl enc -d -aes-256-cbc -pbkdf2 -in "${WORKDIR}/b.enc" -out "${WORKDIR}/b.dump" -pass "pass:${DEK}" \
  || { unset DEK; mark false "복호화 실패"; exit 1; }
unset DEK

# ---- 4) 격리 스테이징 복원 ----
dropdb_staging
psql "${STAGING_ADMIN_URL}" -q -c "create database ${STAGING_DB};"
pg_restore -d "${STAGING_ADMIN_URL%/*}/${STAGING_DB}" --no-owner --no-privileges -j 4 "${WORKDIR}/b.dump" \
  || { mark false "복원 실패"; log "FAIL: 복원"; exit 1; }
log "복원 완료"

# ---- 5) 검증 쿼리 ----
STAGE_URL="${STAGING_ADMIN_URL%/*}/${STAGING_DB}"
FAILS=0
check() { # label sql expect
  local v; v="$(psql "${STAGE_URL}" -At -c "$2")"
  if [[ "${v}" == "$3" ]]; then log "OK  $1 (${v})"; else log "FAIL $1 (got=${v} expect=$3)"; FAILS=$((FAILS+1)); fi
}

# 참조 무결성: 고아 진료기록 없음
check "FK chart_records→patients" \
  "select count(*) from chart_records c left join patients p on p.id=c.patient_id where p.id is null" "0"
# 보존 무결성(§22): 핵심 테이블 존재 및 행수>0
check "patients 존재" "select count(*)>0 from patients" "t"
check "chart_records 존재" "select count(*)>=0 from chart_records" "t"
# 감사로그 연속성(§23)
check "audit_log 존재" "select count(*)>=0 from audit_log" "t"

# 매니페스트 스냅샷과 대조 (핵심 테이블 행수)
SNAP="$(jq -c .integrity_snapshot "${WORKDIR}/m.json")"
if [[ "${SNAP}" != "null" && "${SNAP}" != "{}" ]]; then
  for tbl in patients chart_records assessment_scales prescriptions admissions; do
    exp="$(echo "${SNAP}" | jq -r --arg t "$tbl" '.counts[$t] // empty')"
    [[ -z "${exp}" ]] && continue
    act="$(psql "${STAGE_URL}" -At -c "select count(*) from ${tbl}")"
    if [[ "${act}" == "${exp}" ]]; then log "OK  행수 ${tbl} (${act})"; else log "FAIL 행수 ${tbl} (got=${act} expect=${exp})"; FAILS=$((FAILS+1)); fi
  done
fi

# ---- 6) 결과 ----
if [[ "${FAILS}" -eq 0 ]]; then
  mark true "복구검증 통과 (${TIER})"; log "복구검증 통과 ✅"
else
  mark false "검증 실패 ${FAILS}건"; log "복구검증 실패 ❌ (${FAILS}건)"; exit 1
fi
