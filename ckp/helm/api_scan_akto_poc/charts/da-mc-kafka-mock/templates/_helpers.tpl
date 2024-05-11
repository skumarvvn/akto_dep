{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "da-mc-kafka-mock.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "da-mc-kafka-mock.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s%s" .Values.name .Values.global.deploymentSuffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "da-mc-kafka-mock.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "da-mc-kafka-mock.selectorLabels" -}}
app.kubernetes.io/name: {{ include "da-mc-kafka-mock.name" . }}
app.kubernetes.io/instance: {{ include "da-mc-kafka-mock.fullname" . }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "da-mc-kafka-mock.labels" -}}
helm.sh/chart: {{ include "da-mc-kafka-mock.chart" . }}
{{ include "da-mc-kafka-mock.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

