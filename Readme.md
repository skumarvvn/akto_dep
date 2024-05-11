1. Clone the repo
2. Move to the helm directory (api_scan_akto_poc/ckp/helm)
3. Login to the target ckp cluster
4. Set the context (kubectl config set-context --current --namespace=csoc-mon-akto)
5. Run the below command to start the services
   helm -f ./api_scan_akto_poc/values.yaml upgrade --install csoc-api ./api_scan_akto_poc
6. Uninstall the release
   helm uninstall csoc-api