"""Billing auto-shutoff Cloud Function.

GCP Budget이 임계값 초과 시 Pub/Sub 메시지를 보내면, 이 함수가 트리거되어
지정된 프로젝트의 billing account 연결을 *분리*함. 결과: 모든 결제 API 즉시 중단.

PROJECT_ID는 환경변수로 주입 (deploy 시 --set-env-vars 사용).
"""

from __future__ import annotations

import base64
import json
import os

from googleapiclient import discovery
from googleapiclient.errors import HttpError


PROJECT_ID = os.environ["TARGET_PROJECT_ID"]
PROJECT_NAME = f"projects/{PROJECT_ID}"


def stop_billing(event: dict, context: object) -> str:
    """Pub/Sub 트리거 진입점. Budget 초과 시 billing 분리."""
    pubsub_data = base64.b64decode(event["data"]).decode("utf-8")
    pubsub_json = json.loads(pubsub_data)

    cost = pubsub_json.get("costAmount", 0)
    budget = pubsub_json.get("budgetAmount", 0)

    print(f"[killswitch] cost={cost} budget={budget} project={PROJECT_ID}")

    if cost <= budget:
        return f"No action: cost {cost} <= budget {budget}"

    billing = discovery.build("cloudbilling", "v1", cache_discovery=False)

    try:
        info = billing.projects().getBillingInfo(name=PROJECT_NAME).execute()
    except HttpError as e:
        print(f"[killswitch] Error getting billing info: {e}")
        raise

    if not info.get("billingEnabled"):
        return f"Billing already disabled on {PROJECT_ID}"

    try:
        billing.projects().updateBillingInfo(
            name=PROJECT_NAME, body={"billingAccountName": ""}
        ).execute()
    except HttpError as e:
        print(f"[killswitch] Error disabling billing: {e}")
        raise

    return f"✓ Disabled billing for {PROJECT_ID} (cost {cost} > budget {budget})"
