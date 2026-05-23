#!/usr/bin/env bash
# Billing killswitch 배포 스크립트.
#
# 실행 전 확인:
#   - gcloud 인증됨 (gcloud auth list)
#   - 활성 프로젝트가 weather-friend-genius (또는 아래 PROJECT_ID와 일치)
#
# 단계:
#   1) 필요한 API 활성화
#   2) Pub/Sub 토픽 생성
#   3) Cloud Function 배포
#   4) Function의 SA에 billing.admin 권한 부여
#   5) Budget을 토픽에 연결 (GCP Console에서 수동, 안내 출력)

set -euo pipefail

PROJECT_ID="weather-friend-genius"
TOPIC_NAME="budget-killswitch"
FUNCTION_NAME="stop-billing"
REGION="asia-northeast3"

echo "==> Project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

echo "==> 1) Enable APIs"
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  pubsub.googleapis.com \
  cloudbilling.googleapis.com \
  cloudresourcemanager.googleapis.com \
  run.googleapis.com \
  eventarc.googleapis.com

echo "==> 2) Create Pub/Sub topic ($TOPIC_NAME)"
if ! gcloud pubsub topics describe "$TOPIC_NAME" >/dev/null 2>&1; then
  gcloud pubsub topics create "$TOPIC_NAME"
else
  echo "    (이미 존재 — 스킵)"
fi

echo "==> 3) Deploy Cloud Function ($FUNCTION_NAME)"
gcloud functions deploy "$FUNCTION_NAME" \
  --gen2 \
  --region="$REGION" \
  --runtime=python312 \
  --source=. \
  --entry-point=stop_billing \
  --trigger-topic="$TOPIC_NAME" \
  --set-env-vars="TARGET_PROJECT_ID=$PROJECT_ID" \
  --memory=256MB \
  --timeout=60s

echo "==> 4) Grant Function SA the Billing Account User role"
FUNCTION_SA=$(gcloud functions describe "$FUNCTION_NAME" \
  --region="$REGION" --gen2 \
  --format="value(serviceConfig.serviceAccountEmail)")

echo "    Function SA: $FUNCTION_SA"

# Project IAM에 billing 권한 부여
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$FUNCTION_SA" \
  --role="roles/billing.projectManager"

# Billing Account에도 권한 필요 — 결제 계정 ID 직접 찾기
BILLING_ACCOUNT=$(gcloud billing projects describe "$PROJECT_ID" \
  --format="value(billingAccountName)" | sed 's|billingAccounts/||')

echo "    Billing Account: $BILLING_ACCOUNT"

gcloud billing accounts add-iam-policy-binding "$BILLING_ACCOUNT" \
  --member="serviceAccount:$FUNCTION_SA" \
  --role="roles/billing.user"

echo ""
echo "========================================================"
echo "✅ Cloud Function 배포 완료."
echo "========================================================"
echo ""
echo "==> 5) 마지막 단계 — Budget을 Pub/Sub 토픽에 연결 (콘솔 작업)"
echo ""
echo "    1. https://console.cloud.google.com/billing/budgets?project=$PROJECT_ID"
echo "    2. 기존 'weather-genius-safety' 예산 클릭 (없으면 새로 만들기)"
echo "    3. '편집' → '작업' 섹션까지 스크롤"
echo "    4. 'Pub/Sub 주제에 알림 메시지 연결' 체크"
echo "    5. Topic 선택: projects/$PROJECT_ID/topics/$TOPIC_NAME"
echo "    6. 저장"
echo ""
echo "    그 후 테스트 권장: Budget을 임시로 \$0.01로 낮춰서 자동 차단 동작 확인"
