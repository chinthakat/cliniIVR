
import json
import uuid
import subprocess
import sys

def action_id():
    return str(uuid.uuid4())

# valid flow
def get_lambda_arn(function_name):
    try:
        # Try to get from AWS CLI
        result = subprocess.run(
            ["aws", "lambda", "get-function", "--function-name", function_name, "--query", "Configuration.FunctionArn", "--output", "text", "--no-cli-pager"],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except Exception as e:
        sys.stderr.write(f"Warning: Could not fetch Lambda ARN for {function_name}: {e}\n")
        return f"arn:aws:lambda:us-east-1:ACCOUNT_ID:function:{function_name}"

def get_lex_bot_alias_arn(bot_name, alias_name):
    try:
        # Get Bot ID
        bot_id_result = subprocess.run(
            ["aws", "lexv2-models", "list-bots", "--query", f"botSummaries[?botName=='{bot_name}'].botId", "--output", "text", "--no-cli-pager"],
            capture_output=True,
            text=True,
            check=True
        )
        bot_id = bot_id_result.stdout.strip()
        
        if not bot_id:
             raise Exception(f"Bot {bot_name} not found")

        # Get Alias ID
        alias_id_result = subprocess.run(
            ["aws", "lexv2-models", "list-bot-aliases", "--bot-id", bot_id, "--query", f"botAliasSummaries[?botAliasName=='{alias_name}'].botAliasId", "--output", "text", "--no-cli-pager"],
            capture_output=True,
            text=True,
            check=True
        )
        alias_id = alias_id_result.stdout.strip()
        
        if not alias_id:
            raise Exception(f"Alias {alias_name} not found for bot {bot_name}")
            
        # Construct ARN (Region us-east-1 hardcoded for now or fetch from AWS config)
        # Getting region
        region_result = subprocess.run(
            ["aws", "configure", "get", "region"],
            capture_output=True,
            text=True
        )
        region = region_result.stdout.strip() or "us-east-1"
        
        # Getting Account ID
        account_result = subprocess.run(
            ["aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text", "--no-cli-pager"],
             capture_output=True,
            text=True,
            check=True
        )
        account_id = account_result.stdout.strip()

        return f"arn:aws:lex:{region}:{account_id}:bot-alias/{bot_id}/{alias_id}"

    except Exception as e:
        sys.stderr.write(f"Warning: Could not fetch Lex Bot Alias ARN for {bot_name}: {e}\n")
        return "arn:aws:lex:us-east-1:ACCOUNT_ID:bot-alias/BOT_ID/ALIAS_ID"

lambda_arn = get_lambda_arn("ClinicVoiceOrchestrator")
lex_bot_alias_arn = get_lex_bot_alias_arn("ClinicListener", "Prod")

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
      "Parameters": { "Voice": "Olivia" },
      "Transitions": { "NextAction": id_invoke_init }
    },
    {
      "Identifier": id_invoke_init,
      "Type": "InvokeLambdaFunction",
      "Parameters": {
        "LambdaFunctionARN": lambda_arn,
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
        "BotAliasArn": lex_bot_alias_arn
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
        "LambdaFunctionARN": lambda_arn,
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
