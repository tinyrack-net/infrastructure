# Cilium host firewall operations

The policy in this directory protects the public `eth0` interface. SSH and the
Kubernetes API remain available through Tailscale and are intentionally not
allowed from the public internet.

Before changing the policy, identify the endpoint with identity
`reserved:host`, enable `PolicyAuditMode`, and observe policy verdicts with
Hubble and `cilium-dbg monitor`. Audit mode does not survive a Cilium agent
restart.

Emergency recovery:

1. Connect through Tailscale SSH or the Hetzner console.
2. Enable `PolicyAuditMode` on the `reserved:host` endpoint.
3. Suspend the `cilium-host-firewall` Flux Kustomization.
4. Revert the policy through Git and reconcile Flux.
