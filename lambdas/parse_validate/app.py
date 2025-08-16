import json, boto3
s3 = boto3.client("s3")
REQUIRED = ["user_id", "event_type", "timestamp"]
def handler(event, context):
    bucket, key = event["s3_bucket"], event["s3_key"]
    payload = json.loads(s3.get_object(Bucket=bucket, Key=key)["Body"].read())
    for f in REQUIRED:
        if f not in payload or payload[f] in ("", None):
            raise ValueError(f"Missing field: {f}")
    item = {
        "user_id": str(payload["user_id"]),
        "event_ts": str(payload["timestamp"]),
        "event_type": str(payload["event_type"]),
        "metadata": payload.get("metadata", {}),
        "_s3_bucket": bucket,
        "_s3_key": key,
    }
    return item

