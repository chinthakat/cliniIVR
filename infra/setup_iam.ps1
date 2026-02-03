$RoleName = "ClinicVoiceLambdaRole"
$PolicyName = "ClinicVoiceLambdaPolicy"

Write-Host "Creating IAM Role: $RoleName"
aws iam create-role --role-name $RoleName --assume-role-policy-document file://infra/trust-policy.json --no-cli-pager

# Wait a bit
Start-Sleep -Seconds 5

Write-Host "Putting Role Policy: $PolicyName"
aws iam put-role-policy --role-name $RoleName --policy-name $PolicyName --policy-document file://infra/permissions-policy.json --no-cli-pager

Write-Host "Done. Role ARN:"
aws iam get-role --role-name $RoleName --query "Role.Arn" --output text --no-cli-pager
