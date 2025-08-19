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


**Repository Strucuture**
```
event-driven-pipeline/
├─ lambdas/
│  ├─ collect_to_s3/     # Lambda: collects/ingests raw event and writes to S3
│  ├─ parse_validate/    # Lambda: parses + validates the event payload
│  └─ write_to_ddb/      # Lambda: writes processed record to DynamoDB
├─ .gitignore
├─ .terraform.lock.hcl
├─ README.md
├─ app.py
├─ main.tf               # Terraform stack (S3, Lambdas, Step Functions, DynamoDB, IAM)
├─ outputs.tf
├─ providers.tf
├─ provisioner-policy.json
└─ variables.tf
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

## How to RUN
```bash
EXEC_ARN=$(aws stepfunctions start-execution \
  --state-machine-arn "$STATE_MACHINE_ARN" \
  --input "{\"s3Bucket\":\"$BUCKET\",\"s3Key\":\"$KEY\"}" \
  --region "$REGION" \
  --query executionArn --output text); echo "$EXEC_ARN"
```

### Then check status
```bash
aws stepfunctions describe-execution \
  --execution-arn "$EXEC_ARN" --region "$REGION" \
  --query status --output text
```


## What to Verify
- **Step Functions → user-activity-state-machine → Executions(Details: Status = Succeeded, Duration,Graph view: CollectData → ParseAndValidate → (write) all green)
- **Step Functions:** Execution **Succeeded**; graph shows `CollectData → ParseAndValidate`.
- **CloudWatch Logs:** Log streams exist for both Lambdas (START/END/REPORT).
- **DynamoDB:** New item matching the processed record is present.


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



## How Data Looks

```json
{
  "userId": "user-fd7721",
  "eventType": "click",
  "timestamp": "2025-08-18T19:00:00Z",
  "metadata": { "note": "test data", "source": "collect_lambda" }
}
```

** How Processed Record Looks in DynamoDB
```json
{
  "user_id": "user-fd7721",
  "event_type": "click",
  "event_ts": "2025-08-18T19:00:00Z",
  "metadata": { "note": "test data", "source": "collect_lambda" },
  "_s3_key": "year=2025/month=08/day=18/e9fc4ba24ecd463f898d6dec7f5a55f3.json"
}




