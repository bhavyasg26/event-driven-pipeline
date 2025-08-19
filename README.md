##  Architecture Overview  
  
1. **Event Ingestion** – User activity events are sent to **AWS Lambda (Collect & Ingest)**.  
2. **Raw Storage** – Events are stored in **Amazon S3** in JSON format (partitioned by date).  
3. **Event Validation & Parsing** – Another **AWS Lambda (Parse & Validate)** processes the raw events.  
4. **Orchestration** – **AWS Step Functions** coordinate the pipeline flow.  
5. **Processed Storage** – Validated events are written to **Amazon DynamoDB** for querying.  
6. **Monitoring** – **Amazon CloudWatch** tracks logs and metrics.  
7. **Security & Access** – **AWS IAM** roles and policies ensure least-privilege execution.  

---

##  Services Used  

- **Amazon S3** – Stores raw JSON event files.  
- **AWS Lambda** – Collects user events and validates them.  
- **AWS Step Functions** – Orchestrates the ETL workflow.  
- **Amazon DynamoDB** – Stores validated user activity events.  
- **Amazon CloudWatch** – Monitors logs and pipeline execution.  
- **AWS IAM** – Manages secure access and permissions.  

---

##  Project Structure  

```
event-pipeline/
│── collect_to_s3/
│   └── app.py         # Lambda for collecting & ingesting events
│── parse_validate/
│   └── app.py         # Lambda for parsing & validating events
│── state_machine.json # Step Functions definition
│── iam_policies.json  # IAM roles & permissions
│── README.md          # Project documentation
```

---

##  Workflow Example  

- A user event (e.g., `click`, `login`) is sent → Lambda collects it → stores in S3.  
- Step Function triggers validation Lambda → validates JSON & schema.  
- Validated event is written to DynamoDB with metadata.  
- Logs are pushed to CloudWatch for monitoring.  

---

##  Key Outcomes  

- Built a **serverless event-driven pipeline** entirely using AWS CLI.  
- Implemented **data validation and transformation** before storage.  
- Demonstrated **end-to-end automation** without console/Terraform.  
- Ensured **secure, scalable, and monitored** architecture.  
