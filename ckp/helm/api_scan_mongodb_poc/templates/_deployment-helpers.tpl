{{/*
Helper file for the applications deployment configuration
*/}}
{{/*
The name of the Deployment
*/}}
{{- define "csoc-mon-akto.deployment.name" -}}
{{ template "csoc-mon-akto.fullname" . }}
{{- end }}

{{/*
The name of the Certs volume secret
*/}}
{{- define "csoc-mon-akto.secret.name" -}}
csoc-mon-akto-cert{{ .Values.global.deploymentSuffix }}
{{- end }}