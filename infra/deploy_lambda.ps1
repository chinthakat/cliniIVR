$FunctionName = "ClinicVoiceOrchestrator"
$RoleName = "ClinicVoiceLambdaRole"
$Region = "us-east-1"

# Get Role ARN directly (Global resource, but we want to confirm it exists)
$RoleArn = aws iam get-role --role-name $RoleName --query "Role.Arn" --output text --no-cli-pager
Write-Host "Using Role ARN: $RoleArn"

# Install deps and Zip
Set-Location orchestrator
npm install
Compress-Archive -Path * -DestinationPath ..\function.zip -Force
Set-Location ..

# Check if function exists in Region
Write-Host "Checking function in $Region..."
$exists = aws lambda get-function --function-name $FunctionName --region $Region --no-cli-pager
if ($?) {
    Write-Host "Updating Function Code..."
    aws lambda update-function-code --function-name $FunctionName --zip-file fileb://function.zip --region $Region --no-cli-pager
}
else {
    Write-Host "Creating Function in $Region..."
    aws lambda create-function --function-name $FunctionName `
        --runtime nodejs20.x `
        --role $RoleArn `
        --handler index.handler `
        --zip-file fileb://function.zip `
        --timeout 15 `
        --region $Region `
        --no-cli-pager
}
