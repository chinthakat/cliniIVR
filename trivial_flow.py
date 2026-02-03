
import json
import uuid

def get_id(): return str(uuid.uuid4())

id_start = get_id()
id_disco = get_id()

flow = {
    "Version": "2019-10-30",
    "StartAction": id_start, 
    "Metadata": {
        "entryPointPosition": {"x": 20, "y": 20},
        "snapToGrid": True,
        "ActionMetadata": {
            id_start: {"position": {"x": 200, "y": 20}},
            id_disco: {"position": {"x": 450, "y": 20}}
        }
    },
    "Actions": [
        {
            "Identifier": id_start,
            "Type": "UpdateContactTextToSpeechVoice",
            "Parameters": {"Voice": "Danielle"},
            "Transitions": {"NextAction": id_disco}
        },
        {
            "Identifier": id_disco,
            "Type": "DisconnectParticipant",
            "Parameters": {},
            "Transitions": {}
        }
    ]
}
print(json.dumps(flow, indent=2))
