
import json
import uuid

def action_id():
    return str(uuid.uuid4())

# Generate IDs
id_start = action_id()
id_set_voice = id_start
id_invoke_init = action_id()
id_play_prompt = action_id()
id_disconnect = action_id()
id_get_input = action_id()

flow = {
  "Version": "2019-10-30",
  "StartAction": id_set_voice,
  "Metadata": {
    "entryPointPosition": {"x": 20, "y": 20},
    "snapToGrid": True,
    "ActionMetadata": {
      id_set_voice: { "position": { "x": 200, "y": 20 } }, 
      id_invoke_init: { "position": { "x": 450, "y": 20 } },
      id_play_prompt: { "position": { "x": 700, "y": 20 } },
      id_get_input: { "position": { "x": 950, "y": 20 } },
      id_disconnect: { "position": { "x": 1200, "y": 20 } }
    }
  },
  "Actions": [
    {
      "Identifier": id_set_voice,
      "Type": "UpdateContactTextToSpeechVoice",
      "Parameters": { "Voice": "Danielle" },
      "Transitions": { "NextAction": id_invoke_init }
    },
    {
      "Identifier": id_invoke_init,
      "Type": "InvokeLambdaFunction",
      "Parameters": {
        "LambdaFunctionARN": "arn:aws:lambda:us-east-1:554800146362:function:ClinicVoiceOrchestrator",
        "InvocationTimeLimitSeconds": "8"
      },
      "Transitions": { 
        "NextAction": id_play_prompt,
        "Errors": [{ "NextAction": id_disconnect, "ErrorType": "NoMatchingError" }]
      }
    },
    {
      "Identifier": id_play_prompt,
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "$.External.responseText"
      },
      "Transitions": { "NextAction": id_get_input }
    },
    {
      "Identifier": id_get_input,
      "Type": "GetUserInput",
      "Parameters": {
        "Text": "Please enter digits.",
        "Timeout": "5",
        "MaxDigits": "5"
      },
      "Transitions": {
        "NextAction": id_disconnect,
        "Errors": [{ "NextAction": id_disconnect, "ErrorType": "NoMatchingError" }, { "NextAction": id_disconnect, "ErrorType": "NoInput" }]
      }
    },
    {
      "Identifier": id_disconnect,
      "Type": "DisconnectParticipant",
      "Parameters": {},
      "Transitions": {}
    }
  ]
}

print(json.dumps(flow, indent=2))
