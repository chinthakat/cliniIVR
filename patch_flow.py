
import json
import uuid

# Configuration
BOT_ALIAS_ARN = "arn:aws:lex:us-east-1:554800146362:bot-alias/WOEOICM5ZJ/HY7HC25NXC"
LAMBDA_ARN = "arn:aws:lambda:us-east-1:554800146362:function:ClinicVoiceOrchestrator"

def get_id():
    return str(uuid.uuid4())

# Load original to preserve Type/Version if needed (though we'll rebuild mostly)
# We'll just build a fresh valid object to be safe
flow = {
    "Version": "2019-10-30",
    "StartAction": "", 
    "Metadata": {
        "entryPointPosition": {"x": 20, "y": 20},
        "snapToGrid": True,
        "ActionMetadata": {}
    },
    "Actions": []
}

# Define IDs
id_set_voice = get_id()
id_init_lambda = get_id()
id_check_end = get_id()
id_play_msg = get_id()
id_term_disco = get_id()
id_get_input = get_id()
id_proc_lambda = get_id()
id_term_error = get_id() # Generic error termination

flow["StartAction"] = id_set_voice

# Helpers
def add_action(id, type, params, transitions, pos_x, pos_y):
    flow["Actions"].append({
        "Identifier": id,
        "Type": type,
        "Parameters": params,
        "Transitions": transitions
    })
    flow["Metadata"]["ActionMetadata"][id] = {
        "position": {"x": pos_x, "y": pos_y}
    }

# 1. Set Voice
add_action(
    id_set_voice,
    "UpdateContactTextToSpeechVoice",
    {"Voice": "Danielle"},
    {"NextAction": id_init_lambda},
    200, 20
)

# 2. Invoke Lambda (Init)
add_action(
    id_init_lambda,
    "InvokeLambdaFunction",
    {
        "LambdaFunctionARN": LAMBDA_ARN,
        "InvocationTimeLimitSeconds": "8"
    },
    {
        "NextAction": id_check_end,
        "Errors": [{"NextAction": id_term_error, "ErrorType": "NoMatchingError"}]
    },
    450, 20
)

# 3. Check End Call
add_action(
    id_check_end,
    "CheckContactAttributes",
    {
        "Attribute": "endCall",
        "AttributeNamespace": "External"
    },
    {
        "NextAction": id_get_input, # Default: continue to input
        "Conditions": [
            {"Operator": "Equals", "Operands": ["true"], "NextAction": id_play_msg}
        ],
        "Errors": [{"NextAction": id_get_input, "ErrorType": "NoMatchingError"}]
    },
    700, 20
)

# 4. Play Message (and disconnect)
add_action(
    id_play_msg,
    "MessageParticipant",
    {"Text": "$.External.responseText"},
    {"NextAction": id_term_disco},
    950, 200 # Lower branch
)

# 5. Disconnect (Normal)
add_action(
    id_term_disco,
    "DisconnectParticipant",
    {},
    {},
    1200, 200
)

# 6. Get Input (Lex V2)
add_action(
    id_get_input,
    "GetUserInput",
    {
        "Text": "$.External.responseText",
        "Timeout": "5",
        "MaxDigits": "1",
        "BotAliasArn": BOT_ALIAS_ARN
    },
    {
        "NextAction": id_proc_lambda,
        "Errors": [
            {"NextAction": id_proc_lambda, "ErrorType": "NoMatchingError"}, # Fallback to lambda? or prompt again?
            {"NextAction": id_check_end, "ErrorType": "NoInput"} # Loop if no input
        ]
    },
    950, 20
)

# 7. Invoke Lambda (Process Input)
add_action(
    id_proc_lambda,
    "InvokeLambdaFunction",
    {
        "LambdaFunctionARN": LAMBDA_ARN,
        "InvocationTimeLimitSeconds": "8",
        "LambdaFunctionParameters": {
            "inputText": "$.Lex.InputTranscript"
        }
    },
    {
        "NextAction": id_check_end, # Loop back to check end/play response
        "Errors": [{"NextAction": id_term_error, "ErrorType": "NoMatchingError"}]
    },
    1200, 20
)

# 8. Terminate Error
add_action(
    id_term_error,
    "DisconnectParticipant",
    {},
    {},
    1450, 20
)

print(json.dumps(flow, indent=2))
