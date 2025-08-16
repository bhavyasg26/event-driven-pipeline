import os, boto3
TABLE = os.environ["TABLE_NAME"]
ddb = boto3.resource("dynamodb").Table(TABLE)
def handler(event, context):
    ddb.put_item(Item=event)
    return {"status": "ok", "put": {"table": TABLE, "pk": event["user_id"], "sk": event["event_ts"]}}

