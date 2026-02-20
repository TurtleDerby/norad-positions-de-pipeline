import json
import boto3
import os
from datetime import datetime, timezone
import uuid

s3 = boto3.client('s3')

BUCKET = os.environ['DATA_LAKE_BUCKET']

def handler(event, context):
    now = datetime.now(timezone.utc)
    dt = now.strftime("%Y-%m-%d")
    hr = now.strftime("%H")

    run_id = str(uuid.uuid4())

    payload = {
        "message": "lambda test write",
        "timestamp_utc": now.isoformat(),
        "run_id": run_id
    }

    key = f"bronze/norad_positions/dt={dt}/hr={hr}/data_{run_id}.json"

    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=json.dumps(payload),
        ContentType='application/json'
    )
    return {"status": "success", "key": key}