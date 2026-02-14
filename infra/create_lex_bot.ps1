$ErrorActionPreference = "Stop"

$BotName = "ClinicListener"
$RoleArn = aws iam get-role --role-name "LexV2ServiceRole_ClinicListener" --query "Role.Arn" --output text --no-cli-pager
if (-not $RoleArn) { throw "Role LexV2ServiceRole_ClinicListener not found. Please run infra/setup_lex_iam.ps1" }

# 1. Create Bot
Write-Host "Creating Bot..."
Write-Host "Using Role ARN: $RoleArn"
$DataPrivacy = @{
    childDirected = $false
} | ConvertTo-Json
$DataPrivacy | Out-File -Encoding ascii data_privacy.json

try {
    $BotJson = aws lexv2-models create-bot --bot-name $BotName --role-arn $RoleArn --data-privacy file://data_privacy.json --idle-session-ttl-in-seconds 300 --output json --no-cli-pager 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Check if it failed because it exists
        if ($BotJson -match "ConflictException") {
            Write-Host "Bot exists (Conflict). transitioning to finding it..."
            throw "Bot exists"
        }
        $ErrorMsg = $BotJson | Out-String
        Write-Error "Failed to create bot: $ErrorMsg"
        exit 1
    }
    $Bot = $BotJson | ConvertFrom-Json
    $BotId = $Bot.botId
    Write-Host "Bot Created. ID: $BotId"
}
catch {
    Write-Host "Bot might already exist. Trying to find it..."
    $BotId = aws lexv2-models list-bots --no-cli-pager --query "botSummaries[?botName=='$BotName'].botId" --output text
    if (-not $BotId) { throw "Could not create or find bot." }
    Write-Host "Found existing Bot ID: $BotId"
}

Start-Sleep -Seconds 5

# 2. Create Locale
Write-Host "Creating Locale en_US..."
try {
    aws lexv2-models create-bot-locale --bot-id $BotId --bot-version "DRAFT" --locale-id "en_AU" --nlu-intent-confidence-threshold 0.40 --no-cli-pager
}
catch {
    Write-Host "Locale might already exist."
}

Start-Sleep -Seconds 5

# 3. Create Intent (CatchAll)
Write-Host "Creating Intent..."
try {
    $EmptyUtterances = @(@{utterance = "help" }, @{utterance = "I want to" }) | ConvertTo-Json
    $EmptyUtterances | Out-File -Encoding ascii infra/empty_utterances.json
    $Intent = aws lexv2-models create-intent --bot-id $BotId --bot-version "DRAFT" --locale-id "en_AU" --intent-name "CatchAll" --sample-utterances file://infra/empty_utterances.json --output json --no-cli-pager | ConvertFrom-Json
    $IntentId = $Intent.intentId
}
catch {
    $IntentId = aws lexv2-models list-intents --bot-id $BotId --bot-version "DRAFT" --locale-id "en_AU" --no-cli-pager --query "intentSummaries[?intentName=='CatchAll'].intentId" --output text
    if (-not $IntentId) { throw "Could not create or find intent." }
}
Write-Host "Intent ID: $IntentId"

# 4. Add Slot to Intent (UserQuery)
Write-Host "Adding CatchAll slot..."
$SlotParams = @{
    slotConstraint      = "Required"
    promptSpecification = @{
        messageGroupsList = @(
            @{
                message = @{
                    plainTextMessage = @{
                        value = "How can I help?"
                    }
                }
            }
        )
        maxRetries        = 1
    }
} | ConvertTo-Json -Depth 5
$SlotParams | Out-File -Encoding ascii slot_params.json

try {
    $Slot = aws lexv2-models create-slot --bot-id $BotId --bot-version "DRAFT" --locale-id "en_AU" --intent-id $IntentId --slot-name "UserQuery" --slot-type-id "AMAZON.FreeFormInput" --value-elicitation-setting file://slot_params.json --output json --no-cli-pager | ConvertFrom-Json
    $SlotId = $Slot.slotId
}
catch {
    $SlotId = aws lexv2-models list-slots --bot-id $BotId --bot-version "DRAFT" --locale-id "en_AU" --intent-id $IntentId --no-cli-pager --query "slotSummaries[?slotName=='UserQuery'].slotId" --output text
}
Write-Host "Slot ID: $SlotId"

# Update Intent Priority
$Priority = @(
    @{
        priority = 1
        slotId   = $SlotId
    }
) | ConvertTo-Json
$Priority | Out-File -Encoding ascii priority.json

aws lexv2-models update-intent --bot-id $BotId --bot-version "DRAFT" --locale-id "en_AU" --intent-id $IntentId --intent-name "CatchAll" --sample-utterances file://infra/intent_utterances.json --slot-priorities file://priority.json --no-cli-pager

# 5. Build Bot
Write-Host "Building Bot..."
aws lexv2-models build-bot-locale --bot-id $BotId --bot-version "DRAFT" --locale-id "en_AU" --no-cli-pager

# Wait for build
Write-Host "Waiting for build..."
do {
    Start-Sleep -Seconds 5
    $Status = aws lexv2-models describe-bot-locale --bot-id $BotId --bot-version "DRAFT" --locale-id "en_AU" --query "botLocaleStatus" --output text --no-cli-pager
    Write-Host "Status: $Status"
} until ($Status -eq "Built" -or $Status -eq "ReadyExpressTesting" -or $Status -eq "Failed")

if ($Status -eq "Failed") {
    Write-Error "Bot build failed."
}

# 6. Create Version
Write-Host "Creating Version..."
$VersionSpec = @{
    en_AU = @{
        sourceBotVersion = "DRAFT"
    }
} | ConvertTo-Json
$VersionSpec | Out-File -Encoding ascii version_spec.json

$Version = aws lexv2-models create-bot-version --bot-id $BotId --bot-version-locale-specification file://version_spec.json --output json --no-cli-pager | ConvertFrom-Json
$VersionId = $Version.botVersion
Write-Host "Version: $VersionId"

Start-Sleep -Seconds 5

# 7. Create Alias
Write-Host "Creating Alias 'Prod'..."
try {
    $Alias = aws lexv2-models create-bot-alias --bot-id $BotId --bot-alias-name "Prod" --bot-version $VersionId --output json --no-cli-pager | ConvertFrom-Json
    $AliasId = $Alias.botAliasId
}
catch {
    $AliasId = aws lexv2-models list-bot-aliases --bot-id $BotId --no-cli-pager --query "botAliasSummaries[?botAliasName=='Prod'].botAliasId" --output text
    # Update alias if exists
    aws lexv2-models update-bot-alias --bot-id $BotId --bot-alias-id $AliasId --bot-alias-name "Prod" --bot-version $VersionId --no-cli-pager
}

Write-Host "Lex Bot Setup Complete."
Write-Host "BotId: $BotId"
Write-Host "AliasId: $AliasId"
