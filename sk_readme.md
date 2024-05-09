helm uninstall csoc-api

helm -f ./api_scan_akto_poc/values.yaml upgrade --install csoc-api ./api_scan_akto_poc --debug

kubectl delete pod csoc-api-juiceshop-dc4b5d4c5-pl9kp --force --grace-period=0



kubectl delete ds akto-k8s

kubectl apply -f ../../akto-daemonset-config.yaml


helm -f ./api_scan_mongodb_poc/values.yaml upgrade --install csoc-mongo ./api_scan_mongodb_poc --debug

helm uninstall csoc-mongo

mongodb.csoc-mon-akto.svc.cluster.local:27017
mongodb.csoc-mon-akto


helm -f ./mongodb/values.yaml upgrade --install mongodb ./mongodb --debug
