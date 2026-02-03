$Region = "us-east-1"
$InstanceAlias = "clinic-voice-demo-mvp-v2" # New alias just in case old one is stuck deleting

Write-Host "Creating Connect Instance in $Region..."
$Instance = aws connect create-instance --identity-management-type CONNECT_MANAGED --inbound-calls-enabled --outbound-calls-enabled --instance-alias $InstanceAlias --region $Region --no-cli-pager

$InstanceId = $Instance | ConvertFrom-Json | Select-Object -ExpandProperty Id
Write-Host "Instance Created: $InstanceId"

# Wait a bit
Start-Sleep -Seconds 10

$LambdaFunctionName = "ClinicVoiceOrchestrator"
$LambdaArn = aws lambda get-function --function-name $LambdaFunctionName --region $Region --query "Configuration.FunctionArn" --output text --no-cli-pager

Write-Host "Associating Lambda: $LambdaArn"
aws connect associate-lambda-function --instance-id $InstanceId --function-arn $LambdaArn --region $Region --no-cli-pager

Write-Host "Creating Admin User..."
# We need to find the ID of the 'Admin' security profile and Default routing profile for this new instance
$RoutingProfileId = aws connect list-routing-profiles --instance-id $InstanceId --region $Region --query "RoutingProfileSummaryList[0].Id" --output text --no-cli-pager
$SecurityProfileId = aws connect list-security-profiles --instance-id $InstanceId --region $Region --query "SecurityProfileSummaryList[?Name=='Admin'].Id" --output text --no-cli-pager
if (-not $SecurityProfileId) {
    # Fallback
    $SecurityProfileId = aws connect list-security-profiles --instance-id $InstanceId --region $Region --query "SecurityProfileSummaryList[0].Id" --output text --no-cli-pager
}

aws connect create-user --instance-id $InstanceId --username "admin" --password "ClinicDemo123!" --identity-info FirstName=Admin, LastName=User --routing-profile-id $RoutingProfileId --security-profile-ids $SecurityProfileId --phone-config PhoneType=SOFT_PHONE, AutoAccept=false --region $Region --no-cli-pager

Write-Host "Searching for US Number..."
# Searching for US Toll Free
$Phone = aws connect search-available-phone-numbers --instance-id $InstanceId --phone-number-country-code US --phone-number-type TOLL_FREE --max-results 1 --region $Region --query "AvailableNumbersList[0].PhoneNumber" --output text --no-cli-pager

if ($Phone -and $Phone -ne "None") {
    Write-Host "Found US Toll Free: $Phone. Attempting Claim..."
    aws connect claim-phone-number --instance-id $InstanceId --phone-number $Phone --description "Clinic Demo" --region $Region --no-cli-pager
}
else {
    Write-Host "No US Toll Free. Searching DID..."
    $Phone = aws connect search-available-phone-numbers --instance-id $InstanceId --phone-number-country-code US --phone-number-type DID --max-results 1 --region $Region --query "AvailableNumbersList[0].PhoneNumber" --output text --no-cli-pager
    if ($Phone -and $Phone -ne "None") {
        Write-Host "Found US DID: $Phone. Attempting Claim..."
        aws connect claim-phone-number --instance-id $InstanceId --phone-number $Phone --description "Clinic Demo" --region $Region --no-cli-pager
    }
    else {
        Write-Host "No US numbers found available."
    }
}
