{{/*
This file defines reusable Helm named templates that help 
generate consistent resource names in your chart. 
In your example, myapp.name returns the fixed chart 
name myapp, and myapp.fullname builds a release-specific 
name like release-name-myapp.

Why _helpers.tpl exists
_helpers.tpl is the conventional place to store template 
helpers and partials in a Helm chart. Files beginning 
with _ are not rendered as standalone Kubernetes manifests, 
so this file is used as a utility file rather than a deployable 
resource. That keeps shared logic in one place and prevents 
Helm from trying to create an invalid Kubernetes object from 
the helper file itself.

Real use case
The main reason is reusability and consistency. Instead of 
hardcoding names in every Deployment, Service, ConfigMap, 
and Secret, you define the naming logic once and reuse it 
everywhere with include. This reduces duplication and ensures 
all resources for the same release follow the same naming pattern.

A typical example is:
Deployment.metadata.name: {{ include "myapp.fullname" . }}
Service.metadata.name: {{ include "myapp.fullname" . }}
labels like app.kubernetes.io/name: {{ include "myapp.name" . }}

Why this matters in Kubernetes
Kubernetes resource names should be predictable, unique, and 
ideally short enough to stay within DNS naming limits. Using 
helpers makes it easier to manage multiple installs of the 
same chart because each Helm release can get its own unique 
resource names. 
For example, installing the same chart twice as dev and prod 
can produce dev-myapp and prod-myapp, avoiding name collisions
*/}}

{{/*
This defines a small reusable template called myapp.name that 
always outputs the string myapp. The {{- and -}} trim extra 
whitespace, which keeps rendered YAML cleaner.
*/}}
{{- define "myapp.name" -}}
myapp
{{- end }}

{{/*
This defines another reusable template called myapp.fullname. 
It combines the Helm release name (.Release.Name) with the 
helper myapp.name using printf "%s-%s", so if the release is 
demo, the result becomes demo-myapp.
*/}}
{{- define "myapp.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "myapp.name" .) -}}
{{- end }}