import os
import json
import boto3
from botocore.exceptions import ClientError

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

INSTANCE_ID = os.environ.get("TARGET_INSTANCE_ID")
SNS_TOPIC_ARN = os.environ.get("ALERT_TOPIC_ARN")


def lambda_handler(event, context):
    # Log incoming alert payload for debugging
    print("Received event:", json.dumps(event))

    if not INSTANCE_ID or not SNS_TOPIC_ARN:
        print("Missing configuration: TARGET_INSTANCE_ID or ALERT_TOPIC_ARN")
        return {"status": "error", "reason": "missing configuration"}

    try:
        # Reboot EC2 instance
        print(f"Rebooting instance {INSTANCE_ID}")
        ec2.reboot_instances(InstanceIds=[INSTANCE_ID])

        message = {
            "message": "Slow /api/data alert - instance rebooted",
            "instance_id": INSTANCE_ID,
            "event": event,
        }

        # Publish notification to SNS
        print(f"Publishing notification to {SNS_TOPIC_ARN}")
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="Slow /api/data alert - instance rebooted",
            Message=json.dumps(message),
        )

        return {"status": "ok"}

    except ClientError as e:
        print("Error during reboot or SNS publish:", e)
        return {"status": "error", "reason": str(e)}
