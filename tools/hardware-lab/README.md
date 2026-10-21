# Isolated mock hardware lab

**Not a real MTTL-W01 adapter or Windows service.** No imports that open sockets,
no physical device commands, no credentials, no booking/payment/session calls.
The service is disabled by default. The demo explicitly enables only its mock.

From the repository root with Node 22 or 24:

```powershell
node --test tools/hardware-lab/mock_hardware.test.mjs
node tools/hardware-lab/demo.mjs
```

Implemented path: synthetic test commands → `BridgeLabCommandService` →
`MockWindowsConnector` → `MockMttlAdapter` → two synthetic four-channel devices.
The connector class names describe intended boundaries, not installed programs.
Scope/actor objects are trusted test fixtures, not authentication tokens.

The envelope uses commandId, deviceId, explicit desired on/off state, channel,
monotonic per-device sequence, expected revision and absolute deadlineMs.
Never use toggle: retrying it can reverse the intended effect. Command IDs are
scoped to tenant and installation; changing the device or payload under an old
ID is a conflict. Duplicate receipts are copied, not mutable shared references.
Unknown effects block new writes on that device until readback reconciliation;
the other device remains isolated. Offline/expired outcomes are retained and
never automatically replayed after reconnect. Revocation precedes replay lookup.
Audit output is copied and contains only validated IDs and result codes.

All receipts, audit, revocation and simulated state disappear when Node exits.
Do not use this runtime for durability, crash recovery or real authorization.
No Windows installer, service, pairing API, TLS transport or physical adapter
exists here. A real implementation needs durable receipts and revocation,
cryptographic server instructions, approved device identity enrollment,
bounded parsers, persistent reconciliation, tenant authorization on the server,
Windows protected keys and a signed installer. Device MAC is not a credential.

The real stock protocol has no demonstrated transaction ID or cryptographic
device identity. Mock revision readback is stronger than stock acknowledgments;
it is not evidence of exactly-once execution on physical devices.

See [Arabic guide](../../docs/bridge/HARDWARE_LAB_GUIDE_AR.md),
[research](../../docs/bridge/MTTL_W01_FEASIBILITY.md), and
[implementation plan](../../docs/bridge/IMPLEMENTATION_PLAN.md).
