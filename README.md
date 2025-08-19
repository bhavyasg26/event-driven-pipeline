# Event-Driven Data Pipeline (AWS)

**Services:** Amazon S3 • AWS Lambda • AWS Step Functions • Amazon DynamoDB • Amazon CloudWatch • IAM  
**Provisioning:** Terraform & AWS CLI (no console-created resources)

## Overview
Ingest raw event files from **S3**, orchestrate processing with **Step Functions**, transform/validate in **Lambda**, and persist structured records to **DynamoDB**. **CloudWatch** provides logs and metrics end-to-end.

## Architecture (Flow)
```
S3 (raw JSON object)
        │
        ▼
AWS Step Functions ──► Lambda: CollectData ──► Lambda: ParseAndValidate ──► DynamoDB (processed)
        │                                                            │
        └────────────────────────────── CloudWatch Logs & Metrics ───┘
```

## Data Model(Raw-event)-Example

```json
{
  "userId": "user-fd7721",
  "eventType": "click",
  "timestamp": "2025-08-18T19:00:00Z",
  "metadata": { "note": "test data", "source": "collect_lambda" }
}
```

**Processed record (DynamoDB – example)**
```json
{
  "user_id": "user-fd7721",
  "event_type": "click",
  "event_ts": "2025-08-18T19:00:00Z",
  "metadata": { "note": "test data", "source": "collect_lambda" },
  "_s3_key": "year=2025/month=08/day=18/e9fc4ba24ecd463f898d6dec7f5a55f3.json"
}
```

## Repo Structure (example)
```
.
├─ terraform/
│  ├─ main.tf           # S3, Lambdas, Step Functions, DynamoDB, IAM
│  ├─ variables.tf
│  ├─ outputs.tf
│  └─ lambda/           # (optional) packaged Lambda code paths
├─ src/
│  ├─ collect_lambda/   # CollectData handler
│  └─ parse_lambda/     # ParseAndValidate handler
└─ README.md
```

## Prerequisites
- AWS account & credentials configured (`aws configure`)
- **AWS CLI v2**
- **Terraform ≥ 1.5**
- Region: **us-east-1** (update if different)

## Deploy (Terraform)
```bash
cd terraform
terraform init
terraform plan -out tfplan
terraform apply tfplan
```


## Configure (env vars for a quick demo)
Replace with your real values:
```bash
REGION="us-east-1"
STATE_MACHINE_ARN="arn:aws:states:us-east-1:940603400696:stateMachine:user-activity-state-machine"
BUCKET="event-pipeline-bucket"
KEY="year=2025/month=08/day=18/e9fc4ba24ecd463f898d6dec7f5a55f3.json"  # existing object from our project
```

## Run a Demo (Happy Path)
Start one execution using an existing S3 object:
```bash
EXEC_ARN=$(aws stepfunctions start-execution   --state-machine-arn "$STATE_MACHINE_ARN"   --input "{"s3Bucket":"$BUCKET","s3Key":"$KEY"}"   --region "$REGION"   --query 'executionArn' --output text); echo "$EXEC_ARN"
```

(Optional) Check status/history:
```bash
aws stepfunctions describe-execution   --execution-arn "$EXEC_ARN" --region "$REGION"   --query 'status' --output text

aws stepfunctions get-execution-history   --execution-arn "$EXEC_ARN" --region "$REGION"   --max-results 15 --reverse-order   --query 'events[].{time:timestamp,type:type}' --output table
```

## What to Verify
- **Step Functions:** Execution **Succeeded**; graph shows `CollectData → ParseAndValidate`.
- **CloudWatch Logs:** Log streams exist for both Lambdas (START/END/REPORT).
- **DynamoDB:** New item matching the processed record is present.

## (Optional) Negative Test (Failure Handling)
Trigger a controlled failure with a non-existent key:
```bash
aws stepfunctions start-execution   --state-machine-arn "$STATE_MACHINE_ARN"   --input "{"s3Bucket":"$BUCKET","s3Key":"does/not/exist.json"}"   --region "$REGION"   --query 'executionArn' --output text
```
Review the failed state’s **Error/Cause** in Step Functions.

## IAM & Security (Minimum Needed)
- **Lambda execution roles**:
  - `s3:GetObject` on the raw bucket/prefix
  - `dynamodb:PutItem` on the target table
  - `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`
- **Step Functions role**: permission to invoke both Lambdas.
- If using **SSE-KMS**, include `kms:Decrypt/Encrypt` for the CMK.

## Cost Tips
- Keep test payloads small; use S3 lifecycle rules if needed.
- DynamoDB **On-Demand** for sporadic demos.
- Remove unused resources when done.

## Cleanup
```bash
cd terraform
terraform destroy
```

## Troubleshooting
- **StateMachineDoesNotExist** → wrong ARN/region.  
  ```bash
  aws stepfunctions list-state-machines --region "$REGION"
  ```
- **AccessDenied (StartExecution)** → add `states:StartExecution/DescribeExecution/ListExecutions` to your IAM user/role.
- **S3 AccessDenied/NoSuchKey** → ensure the object exists; Lambda role has `s3:GetObject`.
- **No DynamoDB item** → check Lambda logs; confirm table name/region and `PutItem` permission.

---


