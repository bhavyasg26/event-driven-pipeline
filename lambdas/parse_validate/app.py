import os, json, boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

TABLE = os.environ.get("TABLE_NAME") or os.environ["EVENTS_TABLE"]
REQUIRED = ["user_id", "event_type", "timestamp"]

def handler(event, context):
    
    bucket = event.get("bucket") or event.get("s3_bucket")
    key    = event.get("key")    or event.get("s3_key")
    if not bucket or not key:
        raise ValueError(f"Missing S3 location. Got: {event}")

    obj = s3.get_object(Bucket=bucket, Key=key)
    payload = json.loads(obj["Body"].read())

    
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

    table = dynamodb.Table(TABLE)
    table.put_item(Item=item)

    return {"status":"ok","table":TABLE,"wrote_user_id":item["user_id"],"wrote_event_ts":item["event_ts"]}
    
    



