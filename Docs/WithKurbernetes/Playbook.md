Step 1 – Set up Kubernetes locally (Minikube)
What you need first
Before installing Minikube, make sure you have:

    A machine with enough resources, ideally at least 2 CPU cores and 4 GB RAM.

    A container runtime or virtualization option available, such as Docker or a VM driver.

    kubectl, the Kubernetes command-line tool, so you can interact with the cluster after it starts.

Minikube’s official docs describe it as a lightweight Kubernetes implementation for local development, and the basic lifecycle commands include start, stop, status, and delete.

Install Minikube
The exact install command depends on your operating system. Minikube’s official start page provides OS-specific installation instructions and download options.

On Windows
A common official approach is to download the minikube-windows-amd64.exe release, rename it to minikube.exe, and place it in a directory on your PATH.

On Linux
A typical installation method is to download the binary and install it into /usr/local/bin, for example using the release download from the official Minikube site.

On macOS
Use the installation command or package method shown in the official Minikube docs for macOS, then verify that the binary is available in your terminal.

Install kubectl
You also need kubectl installed because Minikube creates the cluster, but kubectl is what you use to inspect and control Kubernetes objects.

After installation, verify both tools:

    minikube version

    kubectl version --client

If both commands return version information, your local tooling is ready.

Start the cluster
Once Minikube and kubectl are installed, start the cluster with:

bash
minikube start
Minikube will create the local cluster and download the Kubernetes components it needs on the first run, which can take a few minutes.

If you want to use a specific driver, you can choose one supported by your environment, such as Docker or VirtualBox. Minikube supports multiple local drivers and virtualization setups depending on your system.

Check cluster status
After the cluster starts, confirm it is running:

bash
minikube status
kubectl get nodes
A healthy setup should show the Minikube node as Ready, which confirms your local Kubernetes cluster is up.

Useful Minikube commands
These are the first commands you’ll use most often:

    minikube start to create or resume the cluster.

    minikube stop to pause it.

    minikube delete to remove the cluster entirely.

    minikube status to check whether it is running.

A simple workflow
A practical first workflow is:

    Install Minikube.

    Install kubectl.

    Start the cluster with minikube start.

    Verify with kubectl get nodes.

    Move on to deploying your first app.

Step 2: Add health endpoints in myapp / mylearning
For Kubernetes, the key goal is to expose separate endpoints for liveness and readiness so Minikube and later your real clusters can manage restarts and traffic safely.

A good baseline is:

/healthz for liveness.

/readyz for readiness.

Keep them lightweight and fast.

Make readiness fail when dependencies are unavailable, while liveness should only fail if the app itself is broken.

What to implement
You should add these checks in both services in a consistent way:

myapp

mylearning

Each service should:

Start normally.

Expose health endpoints.

Return simple JSON responses.

Be easy to wire into Kubernetes probes later.

A practical rule is:

Liveness answers: “Is the process alive?”

Readiness answers: “Can this instance serve traffic right now?”.

Recommended endpoint behavior

| Endpoint | Purpose         | Suggested response                                            |
| -------- | --------------- | ------------------------------------------------------------- |
| /healthz | Liveness probe  | 200 OK with {"status":"ok"} when process is healthy Memory    |
| /readyz  | Readiness probe | 200 OK only when dependencies are ready; otherwise 503 Memory |

For a first version, if your app does not yet depend on a database or external service, /readyz can still return 200 OK, but you should structure it so you can add dependency checks later without redesigning it.

FastAPI-style implementation
If your services are FastAPI apps, the pattern should look like this:

    Add a small health router or inline routes.

    Use app startup/shutdown hooks or lifespan for future dependency setup.

    Track readiness with a boolean flag or dependency check function.

    Return 503 during startup or shutdown if the app should not receive traffic.

Example structure:

python
    from fastapi import FastAPI
    from fastapi.responses import JSONResponse

    app = FastAPI()

    @app.get("/healthz")
    async def healthz():
        return {"status": "ok"}

    @app.get("/readyz")
    async def readyz():
        return JSONResponse(status_code=200, content={"status": "ready"})
That is the simplest version, and it is enough to get Kubernetes probes working in Minikube later.

Better enterprise pattern
To keep this enterprise-ready from the beginning, I recommend this pattern:

    Put health endpoints in a dedicated module, not inside business routes.

    Add a readiness check function that can later include DB, cache, or queue checks.

    Make liveness stay extremely simple.

    Exclude probe endpoints from noisy metrics/tracing if needed later.

That gives you a clean path for:

    Kubernetes probes now.

    Helm templates later.

    Argo Rollouts readiness gating later.

    Graceful shutdown and rollback support later.

What to do next
The best next implementation order is:

    Add /healthz and /readyz to myapp.

    Add the same endpoints to mylearning.

    Confirm both services return the expected HTTP codes.

    Then wire them into Kubernetes liveness/readiness probes in the Helm chart.