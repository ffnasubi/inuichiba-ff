# 実行方法
# .\set-iam-minimum-ffdeploy2.ps1 -projectId "inuichiba-ffprod"
# .\set-iam-minimum-ffdeploy2.ps1 -projectId "inuichiba-ffdev"

# Cloud Run webhook サービスに invoker 付与
$projectId = "inuichiba-ffprod"
$serviceName = "webhook"
$region = "asia-northeast1"

$serviceAccountEmail = "$projectId@appspot.gserviceaccount.com"

# Cloud Run Invoker 付与
gcloud run services add-iam-policy-binding $serviceName `
  --member="serviceAccount:$serviceAccountEmail" `
  --role="roles/run.invoker" `
  --region=$region `
  --project=$projectId

# Service Account Token Creator（必要なら）
gcloud projects add-iam-policy-binding $projectId `
  --member="serviceAccount:$serviceAccountEmail" `
  --role="roles/iam.serviceAccountTokenCreator"
