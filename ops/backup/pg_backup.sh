#!/usr/bin/env bash
# =====================================================
# 정신과 EMR — 일일 논리 백업 (Tier 1/2)
# 국내 백업 러너의 cron 에서 실행 (예: 매일 03:00 KST).
#
# 흐름: pg_dump → 압축(덤프포맷 내장) → AES-256 봉투암호화 →
#       SHA-256 체크섬 + 매니페스트 → 국내 Object Storage 업로드 →
#       backup_runs 기록.
#
# 의료법 §22/개인정보보호법: 산출물은 AES-256 암호화. 데이터키(DEK)는
# 국내 KMS 마스터키로 봉투암호화하여 매니페스트에 동봉(평문 미저장).
#
# 필수: pg_dump, openssl, sha256sum, aws(S3호환), jq, psql
# 설정: backup.env (backup.env.example 참고)
# =====================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/backup.env"

# ---- 파라미터 ----
TIER="${1:-daily}"                       # daily | weekly | monthly | yearly
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORKDIR="$(mktemp -d)"
BASENAME="emr_${TIER}_${STAMP}"
DUMP="${WORKDIR}/${BASENAME}.dump"
ENC="${DUMP}.enc"
MANIFEST="${WORKDIR}/${BASENAME}.manifest.json"
trap 'rm -rf "${WORKDIR}"' EXIT

log()  { echo "[$(date -u +%H:%M:%S)] $*"; }
fail() { log "ERROR: $*"; record_run "failed" "0" "" ""; exit 1; }

# ---- backup_runs 기록 (감사) ----
record_run() { # status size checksum uri
  psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -q <<SQL || true
    insert into backup_runs(kind, status, started_at, finished_at, size_bytes, checksum_sha256, storage_uri)
    values ('${TIER}', '$1', '${STARTED_AT}', now(), NULLIF('$2','')::bigint, NULLIF('$3',''), NULLIF('$4',''));
SQL
}

STARTED_AT="$(date -u +%FT%TZ)"
log "백업 시작: tier=${TIER}"

# ---- 1) 덤프 (읽기전용 롤, custom format = 압축 내장) ----
pg_dump "${BACKUP_RO_DB_URL}" -Fc -Z 6 -f "${DUMP}" \
  || fail "pg_dump 실패"
log "덤프 완료: $(du -h "${DUMP}" | cut -f1)"

# ---- 2) 무결성 스냅샷 (복구검증 대조용) ----
SNAPSHOT="$(psql "${BACKUP_RO_DB_URL}" -At -c "select public.backup_integrity_snapshot()")" \
  || SNAPSHOT="{}"

# ---- 3) 봉투암호화 (랜덤 DEK 로 AES-256, DEK 는 KMS 로 재암호화) ----
DEK="$(openssl rand -hex 32)"                                   # 256-bit 데이터키
openssl enc -aes-256-cbc -pbkdf2 -salt -in "${DUMP}" -out "${ENC}" -pass "pass:${DEK}" \
  || fail "암호화 실패"
# DEK 를 국내 KMS 마스터키로 봉투암호화 (평문 DEK 는 저장하지 않음)
DEK_WRAPPED="$("${SCRIPT_DIR}/kms_wrap.sh" "${DEK}")" || fail "KMS 봉투암호화 실패"
unset DEK

# ---- 4) 체크섬 + 매니페스트 ----
CHECKSUM="$(sha256sum "${ENC}" | awk '{print $1}')"
SIZE="$(stat -c%s "${ENC}")"
cat > "${MANIFEST}" <<JSON
{
  "basename": "${BASENAME}",
  "tier": "${TIER}",
  "created_at": "${STAMP}",
  "size_bytes": ${SIZE},
  "checksum_sha256": "${CHECKSUM}",
  "cipher": "aes-256-cbc/pbkdf2",
  "dek_wrapped": "${DEK_WRAPPED}",
  "integrity_snapshot": ${SNAPSHOT}
}
JSON

# ---- 5) 국내 Object Storage 업로드 (S3 호환) ----
PREFIX="${TIER}/${STAMP:0:4}/${BASENAME}"
aws --endpoint-url "${OBJ_ENDPOINT}" s3 cp "${ENC}"      "s3://${OBJ_BUCKET}/${PREFIX}.dump.enc" \
  || fail "업로드 실패(enc)"
aws --endpoint-url "${OBJ_ENDPOINT}" s3 cp "${MANIFEST}" "s3://${OBJ_BUCKET}/${PREFIX}.manifest.json" \
  || fail "업로드 실패(manifest)"

# 연 단위(Tier2)는 Object Lock 보존기간 설정 (WORM, 의료법 §22)
if [[ "${TIER}" == "yearly" ]]; then
  aws --endpoint-url "${OBJ_ENDPOINT}" s3api put-object-retention \
    --bucket "${OBJ_BUCKET}" --key "${PREFIX}.dump.enc" \
    --retention "Mode=COMPLIANCE,RetainUntilDate=$(date -u -d '+10 years' +%FT%TZ)" \
    || log "경고: Object Lock 설정 실패(버킷 lock 활성화 필요)"
fi

record_run "success" "${SIZE}" "${CHECKSUM}" "s3://${OBJ_BUCKET}/${PREFIX}.dump.enc"
log "백업 성공: ${PREFIX}.dump.enc (${SIZE} bytes, sha256=${CHECKSUM:0:12}…)"
