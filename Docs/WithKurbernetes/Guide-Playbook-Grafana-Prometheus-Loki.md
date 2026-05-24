 here is a practical step-by-step way to verify Prometheus, Grafana, and Loki in your Minikube/ArgoCD setup.

1) Check pods first
Start by confirming the pods are running in the right namespaces.

bash
kubectl -n monitoring get pods
kubectl -n logging get pods
What you want to see:

Prometheus pods: Running

Grafana pods: Running

Loki pods: Running

If any pod is Pending, CrashLoopBackOff, or Terminating, fix that first before moving on.

2) Check services
Make sure the services exist and are exposing the expected ports.

bash
kubectl -n monitoring get svc
kubectl -n logging get svc
Look for:

Prometheus service

Grafana service

Loki service

This confirms the app is deployed and reachable inside the cluster.

3) Check Prometheus readiness
Port-forward Prometheus and test its health endpoint.

bash
kubectl -n monitoring port-forward svc/<prometheus-service-name> 9091:9090
In another terminal:

bash
curl -sf http://127.0.0.1:9091/-/ready
Expected result:

HTTP 200

Prometheus is ready

You can also open:

http://127.0.0.1:9091/targets

That page should show scrape targets and whether they are up.

4) Check Grafana login
Port-forward Grafana and confirm the login page opens.

bash
kubectl -n monitoring port-forward svc/<grafana-service-name> 3001:80
Then open:

bash
curl -sf http://127.0.0.1:3001/login
Or open it in the browser.

Expected result:

Grafana login page loads

If you want to verify dashboards:

Log in

Check Data Sources

Confirm Prometheus is present

Confirm Loki is present if you configured it

5) Check Loki service
First, confirm Loki pods are healthy:

bash
kubectl -n logging get pods
Then check the Loki service:

bash
kubectl -n logging get svc
If you have a Loki HTTP endpoint, test it with port-forward:

bash
kubectl -n logging port-forward svc/<loki-service-name> 3100:3100
Then check:

bash
curl -sf http://127.0.0.1:3100/ready
Expected result:

Loki responds as ready

6) Check logs appear in Grafana
Once Grafana is up:

Go to Explore

Select Loki as the data source

Run a simple query like:

text
{namespace="monitoring"}
Or use whichever labels your promtail/loki setup emits.

If logs appear, Loki is working end-to-end.

7) Check Prometheus targets
Inside Prometheus UI:

Open Status > Targets

Confirm your service monitors are listed

Each target should be UP

This is the best way to verify Prometheus is scraping your apps.

8) Suggested order for your setup
For your current workflow, use this order:

kubectl -n monitoring get pods

kubectl -n logging get pods

Prometheus port-forward and /ready

Grafana port-forward and /login

Loki port-forward and /ready

Grafana Explore with Loki

Prometheus Targets page

9) Quick health checklist
A healthy stack usually means:

Prometheus pods are Running

Grafana pods are Running

Loki pods are Running

Prometheus /ready returns OK

Grafana login page loads

Loki /ready returns OK

Grafana can query Prometheus

Grafana can query Loki