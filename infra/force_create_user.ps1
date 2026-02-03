$Region = "us-east-1"
$InstanceId = "ff581f4d-f5b0-48c9-874c-3d76c910cc6e"
$RoutingProfileId = "af986384-7c8a-461e-abe8-2b45720d8023"

# Fetch Admin Profile ID carefully
$AdminProfileId = aws connect list-security-profiles --instance-id $InstanceId --region $Region --query "SecurityProfileSummaryList[?Name=='Admin'].Id" --output text --no-cli-pager

if (-not $AdminProfileId) {
    Write-Host "Could not find 'Admin' profile. Listing all..."
    aws connect list-security-profiles --instance-id $InstanceId --region $Region --no-cli-pager
    exit 1
}

Write-Host "Creating Admin User with Profile: $AdminProfileId"
# Note: Added single quotes around complex arguments for PowerShell/CLI safety
aws connect create-user --instance-id $InstanceId --username "admin" --password "ClinicDemo123!" --identity-info 'FirstName=Admin,LastName=User' --routing-profile-id $RoutingProfileId --security-profile-ids $AdminProfileId --phone-config 'PhoneType=SOFT_PHONE,AutoAccept=false' --region $Region --no-cli-pager
