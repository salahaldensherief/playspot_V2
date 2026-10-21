# MTTL-W01 feasibility — source research, 21 October 2026

**Decision:** pursue a small vendor-specific native local TCP adapter, initially
mock-only. Do not require Home Assistant, Matter, MQTT or custom firmware for
PlaySpot. Feasibility on some stock firmware is supported by source code;
compatibility of the owner's two units is **unverified**.

## Electrical gate

The [LG U+ product page](https://www.lguplus.com/smart-home/device/IOT1000005)
identifies MTTL-W01, four independently controlled outlets and an input range
of 220V ±10%, 60Hz. The owner's label also says 60Hz; the supplied local mains
frequency is 50Hz. This research establishes no 50Hz approval. A manufacturer
confirmation or qualified electrical assessment covering the actual revision,
power supply, metering, protection and loads is required. Similar voltage or a
successful Wi-Fi connection does not settle frequency compatibility. Keep both
units unpowered for this work. Do not attach test loads, reset, provision, flash
or switch them. Separate explicit owner approval is needed for live work even
after electrical clearance.

## Sources pinned for reproducibility

| Source | Inspected commit | What it establishes |
|---|---|---|
| [ardabil/ha-mttl-w01](https://github.com/ardabil/ha-mttl-w01/tree/aee0cae7dbff918db4607cc59b46f1472ab34f59) | aee0cae7dbff918db4607cc59b46f1472ab34f59 | Python TCP server; README specifically claims stock 1.0.66 |
| [ttaengz/mttl-w01-matterbridge](https://github.com/ttaengz/mttl-w01-matterbridge/tree/dacc31148a01c301bc78161b0a79db71ee03e72a) | dacc31148a01c301bc78161b0a79db71ee03e72a | TypeScript protocol/parser, TCP queues/timeouts, provisioning source |
| [af950833/mttl_w01_standalone](https://github.com/af950833/mttl_w01_standalone/tree/cc850d9febe5b415329da27554a98d214ff0d1fb) | cc850d9febe5b415329da27554a98d214ff0d1fb | Replacement firmware with web/MQTT, OTA/recovery tradeoffs |

These are reverse-engineered community implementations, not an LG protocol
guarantee or approval for the owner's revision. Independent implementation is
preferable; review licenses and third-party dependencies before copying code.

## Findings and confidence

| Question | Evidence-led answer | Owner's exact units |
|---|---|---|
| Stock local TCP? | Both native implementations support a device-initiated TCP session. Python README names stock 1.0.66. | Unknown until safe enrollment and firmware evidence |
| Discovery? | Devices identify themselves after connecting to the configured local server. No requirement for a broad LAN scan or mDNS discovery is demonstrated. | No discovery attempted |
| Wi-Fi provisioning? | Setup source connects to a strip's temporary SoftAP, then TCP 30300 at 192.168.1.1; supplies router Wi-Fi and local server IPv4, then reboots. | Not run; changing Wi-Fi is a live device operation |
| Firmware detection? | Boot information includes model, MAC/client identifier and firmware string. Connection list exposes firmwareVersion. | Read labels/existing records first; boot detection requires powered connection and approval |
| Without flashing? | Reasonable first approach for compatible stock revisions; no need to install standalone firmware simply to test feasibility. | Conditional, not certified |
| Two independent devices? | Server maintains per-MAC connection and request queues; channels 1–4 are scoped to the connection. | Logical support yes; physical proof absent |
| ACK? | TypeScript waits for an exact on/off response on that device connection. Python treats socket drain as success and optimistically changes local state. | Must measure approved readback; don't copy optimistic semantics |
| Timeout? | TypeScript defaults: response 3 seconds, boot 10 seconds, status polling 10 seconds. | Starting hypotheses, not promised device timings |

See pinned files:
[TCP server](https://github.com/ttaengz/mttl-w01-matterbridge/blob/dacc31148a01c301bc78161b0a79db71ee03e72a/mttl-w01-matterbridge/src/tcp-device-server.ts),
[protocol](https://github.com/ttaengz/mttl-w01-matterbridge/blob/dacc31148a01c301bc78161b0a79db71ee03e72a/mttl-w01-matterbridge/src/mttl-protocol.ts),
[Wi-Fi setup](https://github.com/ttaengz/mttl-w01-matterbridge/blob/dacc31148a01c301bc78161b0a79db71ee03e72a/tools/src/setup_wifi.py),
[Python behavior](https://github.com/ardabil/ha-mttl-w01/blob/aee0cae7dbff918db4607cc59b46f1472ab34f59/custom_components/mttl_w01/tcp_server.py).

## Connection architecture and protocol evidence

After authorized provisioning, the strip is a TCP **client** and the Windows
adapter would be a TCP server on a dedicated lab LAN address, default 10086.
PlaySpot cloud traffic must be independently outbound HTTPS from Windows.
Do not expose 10086, 30300, a dashboard or RDP on WAN. Bind a future listener to
the lab interface and use narrow host/firewall rules plus an isolated SSID/VLAN.
Disable router port forwards/UPnP for the lab. Do not install a listener now.

Observed protocol is line-oriented text with CRLF; references account for
fragmented frames and, in Python, null padding. Boot message shape includes
`up:bootinfo:<model>;<MAC>;<clientId>;<firmware>;connect`. The TypeScript parser
requires 12 hex digits for both identities and equality of MAC/clientId.
Status read uses `up:getinfo:all` and four channel records; each has twelve
semicolon-separated fields. Power and energy conversions are reverse-engineered
and require verification before displaying measurements as accurate.

These strings are protocol evidence, **not instructions to transmit**. No working
device command script is delivered. Channel writes carry desired on/off state
and may receive an echo or an unsolicited state event. There is no demonstrated
vendor transaction ID, signed ACK, TLS or device-bound cryptographic identity.
One in-flight command per connection, bounded frames and timeouts, connection
generation checks, and state readback are necessary. A late ACK from an old
connection must not resolve a new operation. Stock polling may delay state
visibility; do not advertise instant push updates across all firmware.

An ACK means protocol acceptance, not proof that a real load was powered or that
the electrical protection worked. A socket write alone proves even less. On
timeout after sending, record UNKNOWN, block conflicting actions and reconcile
observed state; never blindly resend an old power change after reconnect.
Matching state does not prove which actor caused it. Physical buttons and
scheduled device functions can change state independently.

## Security review of reference projects

The Python implementation binds all interfaces, accepts device identity strings
without cryptographic authentication, and emits automatic startup analytics to
third-party endpoints in `__init__.py`. Its outlet defaults are false before
readback and its relay function updates optimistically. These are reasons to
study it as protocol evidence, not to deploy it as the PlaySpot connector.
The TypeScript server has framing limits, response queues and per-device state,
but these do not authenticate MAC identities or make the protocol exactly-once.
Do not execute bundled third-party provisioning or OTA binaries in this review.

Standalone firmware changes the device's networking/behavior and adds web/MQTT.
Its current documentation describes flash-wear and settings-migration concerns
and recovery limitations. It is a different firmware route, not evidence that a
stock unit exposes a web API. Flashing is excluded from this project stage.

## Safe validation order, only after later approvals

1. Record each unpowered unit's complete model/revision/label/serial separately.
2. Obtain electrical clearance tied to the actual unit and local 50Hz supply.
3. Obtain owner's explicit approval for a narrow read-only live protocol trial.
4. Review provisioning tool source, release authenticity and local Wi-Fi handling;
   keep passwords out of logs. Do one unit at a time with no attached loads.
5. On isolated LAN, enroll the expected identity, capture bounded boot metadata,
   and reject unapproved models/firmware/duplicate identity connections.
6. Compare passive/approved status observations to physical indicators; obtain
   separate explicit approval before any outlet switching or load testing.
7. Test two-unit isolation and connection replacement; record actual firmware
   compatibility and timing. Retain UNKNOWN for untested revisions.

No electrical compatibility certificate, exact firmware inventory, live network
capture or hardware control result was produced by this review.
