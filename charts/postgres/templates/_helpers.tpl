{{- define "postgres.name" -}}
postgres
{{- end }}

{{- define "postgres.fullname" -}}
{{ .Release.Name }}-postgres
{{- end }}