import os, json, uuid, datetime
import boto3
s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET_NAME"]
def handler(event, context):
    detail = event.get("detail") or {}
    detail.setdefault("timestamp", datetime.datetime.utcnow().isoformat() + "Z")
    y, m, d = detail["timestamp"][:10].split("-")
    key = f"year={y}/month={m}/day={d}/{uuid.uuid4().hex}.json"
    s3.put_object(Bucket=BUCKET, Key=key, Body=json.dumps(detail).encode("utf-8"))
    return {"s3_bucket": BUCKET, "s3_key": key}

