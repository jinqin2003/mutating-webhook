{{/*
Expand the name of the chart.
*/}}
{{- define "harbor-proxy-webhook.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "harbor-proxy-webhook.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "harbor-proxy-webhook.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "harbor-proxy-webhook.labels" -}}
helm.sh/chart: {{ include "harbor-proxy-webhook.chart" . }}
{{ include "harbor-proxy-webhook.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "harbor-proxy-webhook.selectorLabels" -}}
app.kubernetes.io/name: {{ include "harbor-proxy-webhook.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Tagging labels
*/}}
{{- define "harbor-proxy-webhook.taggingLabels" -}}
team: sre
Cogito.Finance.Class: {{ default "revenue" .Values.tagging.finance.class }}
{{- if .Values.tagging.finance.costcenter }}
Cogito.Finance.CostCenter: {{ .Values.tagging.finance.costcenter }}
{{- else }}
Cogito.Finance.CostCenter: cogito.{{ .Values.tagging.ownership.team }}
{{- end }}
Cogito.Operations.EnvironmentLevel: {{ required ".Values.tagging.operations.environmentLevel is required!" .Values.tagging.operations.environmentLevel }}
Cogito.Ownership.Team: {{ required ".Values.tagging.ownership.team is required!" .Values.tagging.ownership.team }}
Cogito.Security.DataConfidentiality: {{ required ".Values.tagging.security.dataConfidentiality is required!" .Values.tagging.security.dataConfidentiality }}
Cogito.Security.Exposure: {{ required ".Values.tagging.security.exposure is required!" .Values.tagging.security.exposure }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "harbor-proxy-webhook.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "harbor-proxy-webhook.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
