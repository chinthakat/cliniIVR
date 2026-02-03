$Region = "us-east-1"
$InstanceId = aws connect list-instances --region $Region --query "InstanceSummaryList[?InstanceAlias=='clinic-voice-demo-mvp-v2'].Id" --output text --no-cli-pager

$LambdaFunctionName = "ClinicVoiceOrchestrator"
$LambdaArn = aws lambda get-function --function-name $LambdaFunctionName --region $Region --query "Configuration.FunctionArn" --output text --no-cli-pager
Write-Host "Lambda ARN: $LambdaArn"

Write-Host "Associating Lambda..."
aws connect associate-lambda-function --instance-id $InstanceId --function-arn $LambdaArn --region $Region --no-cli-pager

Write-Host "Creating Admin User..."
$RoutingProfileId = aws connect list-routing-profiles --instance-id $InstanceId --region $Region --query "RoutingProfileSummaryList[0].Id" --output text --no-cli-pager
$SecurityProfileId = aws connect list-security-profiles --instance-id $InstanceId --region $Region --query "SecurityProfileSummaryList[?Name=='Admin'].Id" --output text --no-cli-pager
if (-not $SecurityProfileId) {
    $SecurityProfileId = aws connect list-security-profiles --instance-id $InstanceId --region $Region --query "SecurityProfileSummaryList[0].Id" --output text --no-cli-pager
}

aws connect create-user --instance-id $InstanceId --username "admin" --password "ClinicDemo123!" --identity-info FirstName=Admin, LastName=User --routing-profile-id $RoutingProfileId --security-profile-ids $SecurityProfileId --phone-config PhoneType=SOFT_PHONE, AutoAccept=false --region $Region --no-cli-pager

Write-Host "Searching for US Number..."
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
