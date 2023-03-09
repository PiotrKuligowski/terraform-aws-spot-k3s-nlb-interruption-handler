import boto3
import time
import os

asg_client = boto3.client('autoscaling', region_name=os.getenv('REGION'))
ec2_client = boto3.client('ec2', region_name=os.getenv('REGION'))
ssm_client = boto3.client('ssm', region_name=os.getenv('REGION'))


def describe_instance(instance_id):
    return ec2_client.describe_instances(
        InstanceIds=[instance_id]
    )['Reservations'][0]['Instances'][0]

def get_tag_value(tags, key):
    for tag in tags:
        if tag['Key'] == key:
            return tag['Value']
    return None

def get_command_by_status(command_id, status='Success'):
    return ssm_client.list_command_invocations(
        CommandId=command_id,
        Filters=[
            {
                'key': 'Status',
                'value': status
            },
        ],
        Details=True
    )['CommandInvocations']

def wait_until_command_complete(command_id):
    max_timeout = 60
    while len(get_command_by_status(command_id)) == 0:
        time.sleep(1)
        max_timeout -= 1
        if max_timeout <= 0:
            break

def get_ssm_param_value(param_name):
    return ssm_client.get_parameter(
        Name=param_name
    )['Parameter']['Value']

def wait_until_new_nlb_ready(current_id):
    max_timeout = 120
    param_name = os.getenv('CURRENT_NLB_ID_PARAM_NAME')
    while current_id == get_ssm_param_value(param_name):
        time.sleep(1)
        max_timeout -= 1
        if max_timeout <= 0:
            break

def handle_interrupted_nlb(instance_id, asg_name):
    print("Network load balancer has been interrupted")

    print("Detaching interrupted NLB and adding replacement node")
    asg_client.detach_instances(
        InstanceIds=[instance_id],
        AutoScalingGroupName=asg_name,
        ShouldDecrementDesiredCapacity=False
    )

    wait_until_new_nlb_ready(instance_id)
    ec2_client.terminate_instances(InstanceIds=[instance_id])


def lambda_handler(event, context):
    instance_id = event['detail']['instance-id']
    instance_describe = describe_instance(instance_id)
    tags = instance_describe['Tags']

    asg_name = get_tag_value(tags, 'aws:autoscaling:groupName')
    if not asg_name:
        print("Interrupted instance is not part of any autoscaling group, returning")
        return {'statusCode': 409}

    project = os.getenv('PROJECT')
    name = get_tag_value(tags, 'Name')

    if f"{project}-nlb" in name:
        handle_interrupted_nlb(instance_id, asg_name)

    return {
        'statusCode': 200,
        'body': 'result'
    }