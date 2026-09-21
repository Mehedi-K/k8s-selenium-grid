# k8s-selenium-grid

![Kubernetes](https://img.shields.io/badge/Kubernetes-kind-326CE5?logo=kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-Chart-0F1689?logo=helm&logoColor=white)
![Selenium Grid](https://img.shields.io/badge/Selenium%20Grid-4.49-43B02A?logo=selenium&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)
![pytest](https://img.shields.io/badge/Tests-pytest-0A9EDC?logo=pytest&logoColor=white)
![CI](https://github.com/Mehedi-K/k8s-selenium-grid/actions/workflows/ci.yml/badge.svg)

A **Selenium Grid** — one hub plus Chrome and Firefox nodes — packaged as a
Helm chart and deployed to Kubernetes, with a pytest smoke-test suite that
proves the grid actually works by running real `RemoteWebDriver` sessions
against it. GitHub Actions spins up a real, disposable [kind](https://kind.sigs.k8s.io/)
(Kubernetes-in-Docker) cluster, installs the chart, waits for every pod to
report Ready, runs the tests through the hub Service, and tears the whole
cluster down again on every push and pull request.

This is a portfolio project focused on **test infrastructure**, not test
authoring: taking a multi-component, stateful-ish service (a hub that
browser nodes register with over an event bus) and deploying it to
Kubernetes the way you'd deploy any real application — a Helm chart with
resource requests/limits, readiness/liveness probes, and a Service, rather
than a pile of `kubectl run` one-offs.

It's the spiritual successor to this account's
[`docker-selenium-grid`](https://github.com/Mehedi-K/docker-selenium-grid)
repo: same Selenium Grid concept (hub + Chrome node + Firefox node), same
smoke-test approach, but deployed to Kubernetes via Helm instead of plain
Docker Compose — the natural next step after "runs in a container" is "runs
on a cluster."

## Why Kubernetes for a Selenium Grid?

A Selenium Grid is a good fit for Kubernetes for the same reasons any
multi-component service is: the hub and nodes are independent, replicable
units that need to find each other, restart themselves when they crash, and
scale independently.

- **Declarative, reproducible infrastructure** — the entire grid topology
  (image versions, resource limits, probes, service wiring) lives in a Helm
  chart instead of imperative setup steps, so `helm install` on any cluster
  reproduces the same grid.
- **Self-healing** — Kubernetes restarts a node pod that crashes mid-session
  and only routes traffic to pods that pass their readiness probe, instead
  of a hub blindly trusting a dead node.
- **Independent scaling** — `chromeNode.replicaCount` and
  `firefoxNode.replicaCount` scale each browser's capacity separately
  (`helm upgrade --set chromeNode.replicaCount=3 ...`), the same shape
  you'd use to scale any other Deployment.
- **A realistic CKA-adjacent exercise** — Deployments, Services, probes,
  resource requests/limits, namespaces, and Helm templating are exactly the
  primitives covered by the Kubernetes administrator certification, applied
  to something more interesting than a demo nginx pod.

## Architecture

```
                          Namespace: selenium-grid
                 ┌──────────────────────────────────────────┐
                 │                                            │
kubectl          │   ┌────────────────────┐                   │
port-forward /   │   │ Service             │                  │
NodePort  ───────┼──▶│ selenium-grid-hub   │  :4444 console    │
                 │   │                     │  :4442 event bus  │
                 │   └──────────┬──────────┘  :4443 event bus  │
                 │              │                              │
                 │   ┌──────────▼──────────┐                   │
                 │   │ Deployment           │                  │
                 │   │ selenium-grid-hub    │                  │
                 │   │ (selenium/hub)       │                  │
                 │   └──────────┬───────────┘                  │
                 │              │ event bus (register/route)   │
                 │     ┌────────┴────────┐                     │
                 │     ▼                 ▼                     │
                 │ ┌──────────┐    ┌───────────┐               │
                 │ │Deployment│    │Deployment │               │
                 │ │chrome-node│   │firefox-node│              │
                 │ └──────────┘    └───────────┘               │
                 │                                              │
                 └──────────────────────────────────────────────┘
```

The hub and both node Deployments run in a dedicated `selenium-grid`
namespace. Nodes find the hub through the hub's Service DNS name
(`selenium-grid-hub`, resolved in-cluster as
`selenium-grid-hub.selenium-grid.svc.cluster.local`) via the standard
Selenium Grid 4 `SE_EVENT_BUS_HOST` environment variable — nothing is wired
to a host IP, local hostname, or NodePort, so the same chart installs
unmodified on kind, minikube, or any other cluster.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (kind runs cluster nodes as
  containers)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) (or
  [minikube](https://minikube.sigs.k8s.io/docs/start/) — the chart makes no
  kind-specific assumptions)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- Python 3.9+ if you want to run the smoke tests from your host instead of
  relying on CI

This project is designed to run entirely against a **disposable local or CI
cluster**. There is nothing cloud-specific in the chart or CI workflow — no
LoadBalancer Services, no cloud-provider storage classes, no managed-cluster
credentials. `kind delete cluster` (or the CI runner simply ending) leaves
nothing behind.

## Spinning up a local cluster

```bash
kind create cluster --config kind-config.yaml
kubectl cluster-info --context kind-kind
```

`kind-config.yaml` defines a single control-plane node and maps host port
`4444` to container port `30444`, which is only used if you switch the
hub's Service to `NodePort` (see below). The default Service type is
`ClusterIP`, reached via `kubectl port-forward`.

## Installing the chart

```bash
helm install selenium-grid ./charts/selenium-grid \
  --namespace selenium-grid \
  --create-namespace
```

Every value in `charts/selenium-grid/values.yaml` has a sensible default —
no `--set` flags are required for a working install. Watch the rollout and
confirm every pod reaches `Ready`:

```bash
kubectl get pods -n selenium-grid -w
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/instance=selenium-grid \
  -n selenium-grid --timeout=240s
```

### Reaching the hub

By default the hub Service is `ClusterIP`, so reach it with a port-forward:

```bash
kubectl port-forward -n selenium-grid svc/selenium-grid-hub 4444:4444
```

Then browse `http://localhost:4444` for the Grid console, or point a
`RemoteWebDriver` client at `http://localhost:4444/wd/hub`.

To skip the port-forward, install (or upgrade) with a NodePort Service and
use the port `kind-config.yaml` already maps to the host:

```bash
helm upgrade --install selenium-grid ./charts/selenium-grid \
  --namespace selenium-grid \
  --create-namespace \
  --set hub.service.type=NodePort
```

The Grid console is then reachable directly at `http://localhost:4444`
(via the `30444 -> 4444` mapping in `kind-config.yaml`), no
`kubectl port-forward` needed.

## Running the smoke tests

The smoke-test suite in `smoke-tests/` is a standalone pytest project. With
the hub reachable at `http://localhost:4444` (via either method above):

```bash
cd smoke-tests
pip install -r requirements.txt

SELENIUM_REMOTE_URL=http://localhost:4444/wd/hub pytest -v

# target Firefox instead of the default Chrome:
SELENIUM_REMOTE_URL=http://localhost:4444/wd/hub BROWSER=firefox pytest -v
```

The first test hits the hub's `/status` endpoint directly and asserts it
reports `ready: true` with at least one node registered — proof the chart's
hub and node Deployments actually found each other over the event bus, not
just that the pods are `Running`. The remaining tests open real
`RemoteWebDriver` sessions and drive them against
[the-internet.herokuapp.com](https://the-internet.herokuapp.com/), a public
site built for exercising this kind of browser automation.

On any test failure, a screenshot is saved to `smoke-tests/screenshots/`
(gitignored locally, uploaded as a CI artifact on failure).

## Tearing down

```bash
helm uninstall selenium-grid --namespace selenium-grid
kubectl delete namespace selenium-grid

# and/or remove the whole cluster:
kind delete cluster
```

## Continuous Integration

`.github/workflows/ci.yml` runs on every push and pull request to `main`,
as a matrix over Chrome and Firefox:

1. Creates a real kind cluster (`helm/kind-action`, using
   `kind-config.yaml`).
2. Lints the chart with `helm lint`.
3. Installs it with `helm install`.
4. Waits for the hub and node pods to reach `Ready` with
   `kubectl wait --for=condition=Ready`.
5. Port-forwards the hub Service and polls `/wd/hub/status` until the grid
   reports ready (bounded retry loop, not a fixed sleep).
6. Runs the smoke tests against the forwarded endpoint.
7. On failure, dumps pod events/logs and uploads screenshots + JUnit XML as
   build artifacts.
8. Always uninstalls the release and deletes the kind cluster, even if the
   tests failed.

## Chart structure

```
charts/selenium-grid/
  Chart.yaml                     Chart metadata
  values.yaml                    Image tags, replica counts, resources, probes, Service type
  templates/
    _helpers.tpl                 Name/label templates shared by every resource
    hub-deployment.yaml           selenium/hub Deployment (readiness/liveness on /wd/hub/status)
    hub-service.yaml              ClusterIP/NodePort Service exposing console + event bus ports
    chrome-node-deployment.yaml   selenium/node-chrome Deployment, registers via SE_EVENT_BUS_HOST
    firefox-node-deployment.yaml  selenium/node-firefox Deployment, registers via SE_EVENT_BUS_HOST
    NOTES.txt                     Post-install instructions (printed by `helm install`/`helm status`)
```

## Project structure

```
k8s-selenium-grid/
  charts/selenium-grid/        Helm chart (see above)
  smoke-tests/
    requirements.txt            selenium, pytest, requests
    conftest.py                 RemoteWebDriver fixture (SELENIUM_REMOTE_URL, BROWSER), failure screenshots
    test_grid_smoke.py          7 end-to-end tests proving the grid deploys and routes real sessions
  kind-config.yaml              Single-node kind cluster with a NodePort->host port mapping
  .github/workflows/ci.yml      Creates a kind cluster, installs the chart, runs the smoke tests, tears down
  .gitignore
```
