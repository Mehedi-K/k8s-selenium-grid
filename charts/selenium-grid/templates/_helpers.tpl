{{/*
Chart name, truncated and DNS-1123 safe.
*/}}
{{- define "selenium-grid.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name, respecting fullnameOverride / nameOverride.
*/}}
{{- define "selenium-grid.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart name and version, used in the chart label.
*/}}
{{- define "selenium-grid.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to every resource.
*/}}
{{- define "selenium-grid.labels" -}}
helm.sh/chart: {{ include "selenium-grid.chart" . }}
{{ include "selenium-grid.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Base selector labels shared by every component.
*/}}
{{- define "selenium-grid.selectorLabels" -}}
app.kubernetes.io/name: {{ include "selenium-grid.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Hub component name, e.g. release-selenium-grid-hub.
*/}}
{{- define "selenium-grid.hub.name" -}}
{{ include "selenium-grid.fullname" . }}-hub
{{- end -}}

{{/*
Hub selector labels (base selector + component).
*/}}
{{- define "selenium-grid.hub.selectorLabels" -}}
{{ include "selenium-grid.selectorLabels" . }}
app.kubernetes.io/component: hub
{{- end -}}

{{/*
Hub labels.
*/}}
{{- define "selenium-grid.hub.labels" -}}
{{ include "selenium-grid.labels" . }}
app.kubernetes.io/component: hub
{{- end -}}

{{/*
Chrome node component name.
*/}}
{{- define "selenium-grid.chromeNode.name" -}}
{{ include "selenium-grid.fullname" . }}-chrome-node
{{- end -}}

{{- define "selenium-grid.chromeNode.selectorLabels" -}}
{{ include "selenium-grid.selectorLabels" . }}
app.kubernetes.io/component: chrome-node
{{- end -}}

{{- define "selenium-grid.chromeNode.labels" -}}
{{ include "selenium-grid.labels" . }}
app.kubernetes.io/component: chrome-node
{{- end -}}

{{/*
Firefox node component name.
*/}}
{{- define "selenium-grid.firefoxNode.name" -}}
{{ include "selenium-grid.fullname" . }}-firefox-node
{{- end -}}

{{- define "selenium-grid.firefoxNode.selectorLabels" -}}
{{ include "selenium-grid.selectorLabels" . }}
app.kubernetes.io/component: firefox-node
{{- end -}}

{{- define "selenium-grid.firefoxNode.labels" -}}
{{ include "selenium-grid.labels" . }}
app.kubernetes.io/component: firefox-node
{{- end -}}
