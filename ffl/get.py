from pymemcache.client import base
import json
import os

endpoint = os.environ.get('endpoint')
port = os.environ.get('port')


def ffl(event, context):
    client = base.Client((endpoint, port))
    team = json.loads(client.get('ffl').decode('utf-8'))

    json_string = json.dumps(team, ensure_ascii=False, indent=4).encode('utf8')

    return {
        'statusCode': 200,
        'body': json_string.decode(),
        "headers": {
            "content-type": "application/json; charset=utf-8"
        }
    }
