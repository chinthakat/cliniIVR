aws lambda invoke --function-name ClinicVoiceOrchestrator --payload file://infra/test_event.json response.json --cli-binary-format raw-in-base64-out --no-cli-pager
Get-Content response.json
