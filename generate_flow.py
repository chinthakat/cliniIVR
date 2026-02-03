
import json
import uuid

def action_id():
    return str(uuid.uuid4())

# Generate IDs
id_start = action_id()
id_set_voice = id_start
id_invoke_init = action_id()
id_check_end = action_id()
id_play_disconnect = action_id()
id_disconnect = action_id()
id_get_input = action_id()
id_invoke_process = action_id()

flow = {
  "Version": "2019-10-30",
  "StartAction": id_set_voice,
  "Metadata": {
    "entryPointPosition": {"x": 20, "y": 20},
    "snapToGrid": True,
    "ActionMetadata": {
      id_set_voice: { "position": { "x": 200, "y": 20 } }, 
      id_invoke_init: { "position": { "x": 450, "y": 20 } },
      id_check_end: { "position": { "x": 700, "y": 20 } },
      id_get_input: { "position": { "x": 950, "y": 20 } },
      id_play_disconnect: { "position": { "x": 1200, "y": 20 } },
      id_disconnect: { "position": { "x": 1450, "y": 20 } },
      id_invoke_process: { "position": { "x": 950, "y": 300 } }
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
        "NextAction": id_check_end,
        "Errors": [{ "NextAction": id_disconnect, "ErrorType": "NoMatchingError" }]
      }
    },
    {
      "Identifier": id_check_end,
      "Type": "CheckContactAttributes",
      "Parameters": {
        "Attribute": "endCall",
        "AttributeNamespace": "External"
      },
      "Transitions": {
        "NextAction": id_get_input,
        "Conditions": [
          { "Operator": "Equals", "Operands": ["true"], "NextAction": id_play_disconnect }
        ],
        "Errors": [{ "NextAction": id_get_input, "ErrorType": "NoMatchingError" }]
      }
    },
    {
      "Identifier": id_play_disconnect,
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "$.External.responseText"
      },
      "Transitions": { "NextAction": id_disconnect }
    },
    {
      "Identifier": id_disconnect,
      "Type": "DisconnectParticipant",
      "Parameters": {},
      "Transitions": {}
    },
    {
      "Identifier": id_get_input,
      "Type": "GetUserInput",
      "Parameters": {
        "Text": "$.External.responseText",
        "Timeout": "5",
        "MaxDigits": "1",
        "BotAliasArn": "arn:aws:lex:us-east-1:554800146362:bot-alias/WOEOICM5ZJ/HY7HC25NXC"
      },
      "Transitions": {
        "NextAction": id_invoke_process,
        "Errors": [{ "NextAction": id_invoke_process, "ErrorType": "NoMatchingError" }, { "NextAction": id_invoke_process, "ErrorType": "NoInput" }]
      }
    },
    {
      "Identifier": id_invoke_process,
      "Type": "InvokeLambdaFunction",
      "Parameters": {
        "LambdaFunctionARN": "arn:aws:lambda:us-east-1:554800146362:function:ClinicVoiceOrchestrator",
        "InvocationTimeLimitSeconds": "8",
        "LambdaFunctionParameters": {
            "inputText": "$.Lex.InputTranscript"
        }
      },
      "Transitions": { 
        "NextAction": id_check_end,
        "Errors": [{ "NextAction": id_disconnect, "ErrorType": "NoMatchingError" }]
      }
    }
  ]
}

print(json.dumps(flow, indent=2))
