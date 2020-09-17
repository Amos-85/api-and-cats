import os
import boto3
import redis
import json
import urllib
from datetime import datetime

print('Loading produce function')

rekognition = boto3.client('rekognition')
redis = redis.Redis(host=os.environ['REDIS_MASTER_ENDPOINT'], port=6379, db=0)


def detect_labels(bucket, key):
    try:
        response = rekognition.detect_labels(
            Image={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': key
                }
            },
            MaxLabels=3,
            MinConfidence=90
        )
        return response
    except Exception as e:
        print(e)
        raise e


def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.quote_plus(event['Records'][0]['s3']['object']['key'].encode('utf8'))
    print("Image file is {}".format(key))
    try:
        response = detect_labels(bucket, key)
        cat_food = (
                'Bread' in json.dumps(response['Labels']) or
                'Fish' in json.dumps(response['Labels']) or
                'Milk' in json.dumps(response['Labels'])
        )

        if cat_food is True:
            redis.set('last_fed_timestamps', '{}'.format(datetime.now()))
            redis.set('cat_status', 'ok')
            redis.set('MESSAGE_FED_SENT', 'False')
            redis.set('MESSAGE_NOT_FED_SENT ', 'False')
            print('Updated timestamps in Elastic-Cache')
            print('Given Food to cat')
        else:
            print('Not a right food for cat')

        return response['Labels']
    except Exception as e:
        print(e)
        print("Error processing object {} from bucket {}. ".format(key, bucket) +
              "Make sure your object and bucket exist and your bucket is in the same region as this function.")
        raise e
