$InstanceId = "1d0cb989-48de-4053-8b12-fba13fe49d6b"
$LambdaArn = "arn:aws:lambda:us-east-1:554800146362:function:ClinicVoiceOrchestrator"
$RoutingProfileId = "313b2ce0-bbfb-4e9f-8e4f-557f83bf2909"

Write-Host "Associating Lambda..."
aws connect associate-lambda-function --instance-id $InstanceId --function-arn $LambdaArn --no-cli-pager

Write-Host "Getting Security Profile..."
$SecurityProfileId = aws connect list-security-profiles --instance-id $InstanceId --query "SecurityProfileSummaryList[?Name=='Admin'].Id" --output text --no-cli-pager
if (-not $SecurityProfileId) {
    Write-Host "Admin profile not found via query. Using first available."
    $SecurityProfileId = aws connect list-security-profiles --instance-id $InstanceId --query "SecurityProfileSummaryList[0].Id" --output text --no-cli-pager
}
Write-Host "Security Profile: $SecurityProfileId"

Write-Host "Creating Admin User..."
aws connect create-user --instance-id $InstanceId --username "admin" --password "ClinicDemo123!" --identity-info FirstName=Admin, LastName=User --routing-profile-id $RoutingProfileId --security-profile-ids $SecurityProfileId --phone-config PhoneType=SOFT_PHONE, AutoAccept=false --no-cli-pager

Write-Host "Searching for Toll Free Phone..."
$Phone = aws connect search-available-phone-numbers --instance-id $InstanceId --phone-number-country-code US --phone-number-type TOLL_FREE --max-results 1 --query "AvailableNumbersList[0].PhoneNumber" --output text --no-cli-pager

if ($Phone -and $Phone -ne "None") {
    Write-Host "Claiming TOLL_FREE: $Phone"
    aws connect claim-phone-number --instance-id $InstanceId --phone-number $Phone --description "Clinic Demo" --no-cli-pager
}
else {
    Write-Host "No Toll Free found. Trying DID..."
    $Phone = aws connect search-available-phone-numbers --instance-id $InstanceId --phone-number-country-code US --phone-number-type DID --max-results 1 --query "AvailableNumbersList[0].PhoneNumber" --output text --no-cli-pager
    if ($Phone -and $Phone -ne "None") {
        Write-Host "Claiming DID: $Phone"
        aws connect claim-phone-number --instance-id $InstanceId --phone-number $Phone --description "Clinic Demo" --no-cli-pager
    }
    else {
        Write-Host "No phone numbers found."
    }
}
