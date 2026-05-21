"""Firestore briefings 컬렉션 전체 삭제. 개발 중 리셋용.

Usage:
    uv run python cleanup.py
"""

from __future__ import annotations

import logging
import os

from google.cloud import firestore

_BATCH_SIZE = 500  # Firestore batch 한도


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

    project_id = os.environ.get("GCP_PROJECT_ID", "weather-friend-92281")
    os.environ.setdefault("GOOGLE_CLOUD_PROJECT", project_id)

    db = firestore.Client(project=project_id)
    docs = list(db.collection("briefings").stream())

    if not docs:
        logging.info("✓ briefings 컬렉션이 이미 비어있음")
        return

    logging.info("Deleting %d documents from briefings ...", len(docs))

    deleted = 0
    for i in range(0, len(docs), _BATCH_SIZE):
        batch = db.batch()
        chunk = docs[i : i + _BATCH_SIZE]
        for doc in chunk:
            batch.delete(doc.reference)
        batch.commit()
        deleted += len(chunk)
        logging.info("  - %d / %d deleted", deleted, len(docs))

    logging.info("✓ Deleted %d documents", deleted)


if __name__ == "__main__":
    main()
