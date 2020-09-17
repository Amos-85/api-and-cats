from __future__ import print_function

import os
import boto3
from datetime import datetime
import redis

print('Loading validation function')

ses_client = boto3.client('sesv2', region_name=os.environ['AWS_REGION'])
redis = redis.Redis(host=os.environ['REDIS_MASTER_ENDPOINT'], port=6379, db=0, charset="utf-8", decode_responses=True)

EMAIL_RECIPIENT = os.environ['EMAIL_RECEPIENT']

CHARSET='UTF-8'

FED_MESSAGE='THE CAT HAS BEEN FED'
NOT_FED_MESSAGE='THE CAT DID NOT EAT OVER 15 MINUTES'


def email(message):
    response = ses_client.send_email(
        FromEmailAddress=EMAIL_RECIPIENT,
        Destination={
            'ToAddresses': [
                EMAIL_RECIPIENT,
            ]
        },
        Content={
            'Simple': {
                'Subject': {
                    'Data': 'Cat Status',
                    'Charset': CHARSET
                },
                'Body': {
                    'Text': {
                        'Data': message,
                        'Charset': CHARSET
                    },
                    'Html': {
                        'Data': message,
                        'Charset': CHARSET
                    }
                }
            }
        }
    )
    return response


get_key = lambda key: redis.get(key)
set_key = lambda key, value: redis.set(key, value)


def lambda_handler(event, context):
    try:
        redis.get('last_fed_timestamps')
        converted_last_fed = datetime.strptime(redis.get('last_fed_timestamps'), '%Y-%m-%d %H:%M:%S.%f')
        diff = (datetime.now() - converted_last_fed).total_seconds()

        if diff > 900.00:
            print('cat is hungry')
            if get_key('MESSAGE_NOT_FED_SENT') == 'False':
                email(NOT_FED_MESSAGE)
                print('Message sent')
                set_key('cat_status', 'hungry')
                set_key('MESSAGE_NOT_FED_SENT', 'True')
        elif get_key('cat_status') == 'ok':
            print('cat has been fed')
            if get_key('MESSAGE_FED_SENT') == 'False':
                email(FED_MESSAGE)
                print('Message sent')
                set_key('MESSAGE_FED_SENT', 'True')
        print('Seconds diff time is {}'.format(diff))

        return 'Job Finished'

    except Exception as e:
        print(e)
        raise e
