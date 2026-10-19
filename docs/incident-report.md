# Incident Report: Diagnosing TCP Connection Failures

## 1. Summary

A client initially connected successfully to an HTTP service running in an
isolated Linux network lab. A controlled firewall rule was then introduced
inside the server network namespace to silently drop incoming TCP packets
destined for port 8080.

During the failure test, the client repeatedly transmitted TCP SYN packets
without receiving a response. The server-side packet capture also showed the
incoming SYN attempts, and the firewall rule counter increased to five packets
and 300 bytes.

After the DROP rule was removed and the HTTP server was confirmed to be
running, the client connected successfully again. The recovery capture showed
a completed TCP three-way handshake and a successful HTTP exchange.

## 2. Environment and topology

- Operating system: Kali Linux
- Client namespace: `tcp-lab-client`
- Server namespace: `tcp-lab-server`
- Client interface: `veth-labclient`
- Server interface: `veth-labserver`
- Client IPv4 address: `192.0.2.10/24`
- Server IPv4 address: `192.0.2.20/24`
- Application protocol: HTTP
- TCP destination port: 8080
- Server application: Python 3 HTTP server
- Packet capture: `tcpdump`
- Packet analysis: Wireshark
- Firewall: `iptables` inside the server namespace

Both endpoints run in separate network namespaces within the same Kali Linux
VM. A virtual Ethernet pair connects them directly, so no router is required.

The IPv4 addresses belong to `192.0.2.0/24`, a range reserved for
documentation and examples.

## 3. Investigation method

The investigation consisted of three stages:

1. **Baseline:** Test the HTTP service and capture TCP traffic at both endpoints.
2. **Failure:** Insert an INPUT-chain DROP rule in `tcp-lab-server` for TCP
   packets destined for port 8080, then repeat the connection test.
3. **Recovery:** Remove the DROP rule, ensure the HTTP service is listening,
   and capture a new successful connection.

Packet captures were saved to files and inspected using `tcpdump` and
Wireshark. The firewall rule counters were also checked during the failure test.

## 4. Evidence and observations

### 4.1 Baseline

Files:

- `captures/client-baseline.pcap`
- `captures/server-baseline.pcap`

The client capture showed the TCP three-way handshake:

1. Client to server: SYN.
2. Server to client: SYN-ACK.
3. Client to server: ACK.

The client then sent `GET / HTTP/1.1`. The server returned `HTTP/1.0 200 OK`
and the requested HTML page. The capture also showed the TCP connection
closing normally.

The baseline demonstrated that the virtual link, IP addressing, TCP service
and HTTP exchange worked before the controlled fault was introduced.

### 4.2 Failure

Files:

- `captures/client-failure.pcap`
- `captures/server-failure.pcap`

The client capture contained five SYN attempts from
`192.0.2.10:39942` to `192.0.2.20:8080`. The attempts reused the same source
port and sequence number. No SYN-ACK or RST response for this connection
attempt appeared in the client capture.

The server-side capture also contained five incoming SYN attempts, with no
corresponding successful handshake.

The server INPUT-chain firewall counter showed:

| Counter | Observed value |
|---|---:|
| Packets | 5 |
| Bytes | 300 |
| Target | DROP |
| Protocol | TCP |
| Destination port | 8080 |

The packet captures and increasing firewall counter are consistent with the
matching SYN packets arriving at the server interface and then being silently
discarded by the DROP rule.

A missing TCP response alone would not prove a firewall caused the failure.
The controlled rule, its counter, the successful baseline and the subsequent
recovery test provide stronger combined evidence.

### 4.3 Recovery

Files:

- `captures/client-recovery.pcap`
- `captures/server-recovery.pcap`

After the DROP rule was removed and the Python HTTP server was confirmed to
be listening on `192.0.2.20:8080`, the client connected successfully again.
The HTTP request returned `HTTP/1.0 200 OK` and the expected HTML content.

The recovery captures showed the SYN, SYN-ACK and ACK handshake, followed by
the HTTP request, response and normal connection closure.

During recovery testing, an initial connection attempt was refused because
no process was listening on TCP port 8080. The server was restarted, its
listening socket was verified, and the subsequent recovery test succeeded.
This was a separate service-availability issue, not evidence that the removed
DROP rule was still active.

## 5. Root cause

The controlled connection failure was caused by an INPUT-chain firewall
rule inside `tcp-lab-server` that silently dropped TCP packets destined for
port 8080.

The diagnosis is supported by the following evidence:

- The HTTP service worked before the fault was introduced.
- The client capture showed repeated SYN attempts without a response.
- The server-side capture showed the SYN packets arriving at its interface.
- The DROP-rule counter increased to five packets and 300 bytes.
- After the rule was removed and the service was running, the handshake and
  HTTP exchange succeeded again.

## 6. Fix and validation

The TCP/8080 DROP rule was removed from the INPUT chain inside the server
namespace.

The INPUT-chain policy was verified as ACCEPT, with no remaining rule shown
by `iptables -S INPUT`.

The HTTP service was checked using `ss -ltnp`, and a listener on
`192.0.2.20:8080` was confirmed. A subsequent `curl` request returned HTTP
200 OK. The recovery packet captures verified the successful handshake and
HTTP exchange.

## 7. Limitations

This was a self-directed, single-host lab using Linux network namespaces,
a virtual Ethernet pair, one HTTP service and a deliberately introduced
firewall rule.

It demonstrates endpoint-level TCP troubleshooting and evidence-based fault
isolation. It does not demonstrate troubleshooting of physical switches,
VLANs, routers, WAN paths, DNS or production infrastructure.

## 8. Reproduction

The logical endpoints are:

- Client: `192.0.2.10/24`
- Server: `192.0.2.20/24`
- Service: TCP port 8080

The failure rule used was:

```bash
iptables -I INPUT 1 -p tcp --dport 8080 -j DROP
```

It was applied only inside `tcp-lab-server` and removed before the successful
recovery test.

See the repository README and supporting documentation for the topology,
Wireshark filters, screenshots and packet captures.

## 9. Evidence integrity

The findings in this report are based on the packet listings, command outputs
and tests collected during the lab. Frame numbers have not been specified
here; any frame-number references added later must be checked against the
saved captures in Wireshark rather than assumed.
