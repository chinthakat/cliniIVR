$InstanceId = "1d0cb989-48de-4053-8b12-fba13fe49d6b"
$LambdaFunctionName = "ClinicVoiceOrchestrator"
$LambdaArn = aws lambda get-function --function-name $LambdaFunctionName --query "Configuration.FunctionArn" --output text --no-cli-pager

Write-Host "Associating Lambda: $LambdaArn to Connect: $InstanceId"
aws connect associate-lambda-function --instance-id $InstanceId --function-arn $LambdaArn --no-cli-pager

Write-Host "Creating Admin User..."
# Note: Password complexity rules apply.
aws connect create-user --instance-id $InstanceId --username "admin" --password "ClinicDemo123!" --identity-info FirstName=Admin, LastName=User --routing-profile-id (aws connect list-routing-profiles --instance-id $InstanceId --query "RoutingProfileSummaryList[0].Id" --output text --no-cli-pager) --security-profile-ids (aws connect list-security-profiles --instance-id $InstanceId --query "SecurityProfileSummaryList[?Name=='Admin'].Id" --output text --no-cli-pager) --phone-config PhoneType=SOFT_PHONE, AutoAccept=false --no-cli-pager

Write-Host "Searching for Phone Number..."
$Phone = aws connect search-available-phone-numbers --instance-id $InstanceId --phone-number-country-code US --phone-number-type DID --max-results 1 --query "AvailableNumbersList[0].PhoneNumber" --output text --no-cli-pager

if ($Phone -and $Phone -ne "None") {
    Write-Host "Claiming Phone Number: $Phone"
    $Claimed = aws connect claim-phone-number --instance-id $InstanceId --phone-number $Phone --description "Clinic Demo" --no-cli-pager
    $PhoneId = $Claimed | ConvertFrom-Json | Select-Object -ExpandProperty PhoneNumberId
    Write-Host "Claimed ID: $PhoneId"
}
else {
    Write-Host "No phone numbers found available to claim."
}

Write-Host "Done. Login URL:"
aws connect get-federation-token --instance-id $InstanceId --no-cli-pager
