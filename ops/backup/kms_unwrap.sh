#!/usr/bin/env bash
# =====================================================
# DEK 봉투복호화 (KMS 마스터키로 데이터키 언랩)
# 입력: $1 = base64 래핑 블롭   출력(stdout): 평문 DEK(hex)
# kms_wrap.sh 의 역연산. 국내 KMS 엔드포인트로 교체.
# ⚠️ 평문 DEK 는 호출자 메모리에만 두고 저장/로그 금지.
# =====================================================
set -Eeuo pipefail
WRAPPED_B64="${1:?래핑 블롭 필요}"

# --- AWS KMS 호환 예시 (국내 KMS 엔드포인트로 교체) ---
#   ciphertext blob(base64) → plaintext(DEK hex)
aws kms decrypt \
  --ciphertext-blob "fileb://<(printf '%s' "${WRAPPED_B64}" | base64 -d)" \
  --output text --query Plaintext \
  | base64 -d | xxd -p -c 256
