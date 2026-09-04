# Cilium host firewall operations

The policy in this directory protects the public `eth0` interface. It permits
no public TCP ingress, including ports 80 and 443. SSH and the Kubernetes API
remain available through Tailscale. Public applications are reachable only
through the outbound Cloudflare Tunnel, which connects to Traefik on port 8443
under a separate pod-to-pod Cilium policy.

Before changing the policy, identify the endpoint with identity
`reserved:host`, enable `PolicyAuditMode`, and observe policy verdicts with
Hubble and `cilium-dbg monitor`. Audit mode does not survive a Cilium agent
restart.

Emergency recovery:

1. Connect through Tailscale SSH or the Hetzner console.
2. Enable `PolicyAuditMode` on the `reserved:host` endpoint.
3. Suspend the `cilium-host-firewall` Flux Kustomization.
4. Revert the policy through Git and reconcile Flux.
