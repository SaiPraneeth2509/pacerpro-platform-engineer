# Platform Engineer 

## Part 1: Sumo Logic Query and Alert

This task involves setting up proactive monitoring in Sumo Logic to identify performance degradation and automate the alerting process for high-latency events on the /api/data endpoint.

### 1.1 Create a log source

In Sumo, create a Hosted Collector with an HTTP Logs Source.
This gives a unique HTTPS URL of Sumo to POST logs.

### 1.2 Sumo Logic Query

To identify slow requests, we use a query that parses logs, filters by the specific endpoint, and identifies instances where the response time exceeds the 3-second (3000ms) threshold.

Query:

```
_sourceCategory=app/logs
| json field=_raw "endpoint","response_time_ms"
| where endpoint="/api/data" and response_time_ms > 3000
| count
```

### 1.3 Alert Configuration

1. Create Monitor: Navigate to Manage Data > Monitoring > Monitors and click Add New Monitor.
2. Define Query: Paste the query above into the Monitor's query field.
3. Set Trigger: Under Trigger Conditions, select Critical and set the result to Greater than 5 within a 10 minute window.
4. Configure Notifications: Add webhook connection to ensure the alert reaches the appropriate remediation system (such as the AWS Lambda function URL).

## Part 2: AWS Lambda Function

This task focuses on the development and deployment of a Python-based AWS Lambda function designed to handle incoming webhooks from Sumo Logic and perform administrative actions on AWS infrastructure.

### 2.1 Lambda Function Logic

The function is written in Python using the boto3 library. It performs three primary actions upon execution:

- EC2 Recovery: It identifies the target EC2 instance via environment variables and issues a reboot_instances command to clear the high-latency state.
- Logging: It logs the incoming Sumo Logic payload and the execution status to CloudWatch Logs for auditability.
- Notification: It publishes a message to an Amazon SNS Topic, notifying the engineering team that an automated reboot has occurred.

## Part 3: IaC Setup

This task involves automating the provisioning of the entire AWS environment using Terraform. By codifying the infrastructure, we ensure consistency across environments and eliminate the manual "click-ops" errors associated with the AWS Console.

### 3.1 Automated Resource Provisioning

The Terraform configuration manages the lifecycle of the following interconnected resources:

- Compute: An EC2 Instance (Target) and an AWS Lambda Function.
- Messaging: An SNS Topic and Email Subscription for alerting.
- Security: IAM Roles, Inline Policies, and Lambda Resource-based permissions.
- Packaging: The archive_file data source, which automatically zips the Python source code during deployment.

### 3.2 Workflow

`terraform init`: Initialized the AWS provider and backend.

`terraform plan`: Reviewed the execution plan to confirm that all resources (EC2, Lambda, SNS, IAM) would be created with the correct configurations.

`terraform apply`: Successfully provisioned the stack in the us-east-2 region.

`terraform destroy`: This will safely remove all resources managed by Terraform configuration.

Used the AWS CLI to confirm the Lambda function was active and successfully performed a "Dry Run" of the reboot command.
