#!/usr/bin/env bash
# =====================================================
# DEK 봉투암호화 (KMS 마스터키로 데이터키 래핑)
# 입력: $1 = 평문 DEK(hex)   출력(stdout): base64 래핑 블롭
# 국내 KMS(NCP/KT/AWS KMS 호환)에 맞게 CLI 호출부만 교체.
# ⚠️ 평문 DEK 는 저장/로그 금지.
# =====================================================
set -Eeuo pipefail
DEK_HEX="${1:?DEK 필요}"

# --- AWS KMS 호환 예시 (국내 KMS 엔드포인트로 교체) ---
#   plaintext(DEK) → ciphertext blob(base64)
aws kms encrypt \
  --key-id "${KMS_KEY_ID:?KMS_KEY_ID 미설정}" \
  --plaintext "fileb://<(printf '%s' "${DEK_HEX}" | xxd -r -p)" \
  --output text --query CiphertextBlob
