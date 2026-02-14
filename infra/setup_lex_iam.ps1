$ErrorActionPreference = "Stop"

$RoleName = "LexV2ServiceRole_ClinicListener"
$TrustPolicyPath = "file://infra/lex-trust-policy.json"

Write-Host "Creating IAM Role: $RoleName"
try {
    aws iam create-role --role-name $RoleName --assume-role-policy-document $TrustPolicyPath --no-cli-pager
}
catch {
    Write-Host "Role might already exist. Updating trust policy..."
    aws iam update-assume-role-policy --role-name $RoleName --policy-document $TrustPolicyPath --no-cli-pager
}

Write-Host "Attaching AmazonLexFullAccess..."
aws iam attach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/AmazonLexFullAccess" --no-cli-pager

Write-Host "Lex Service Role Setup Complete."
