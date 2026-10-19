# Wireshark Display Filters

These are Wireshark display filters, not tcpdump capture filters.

| Purpose | Display filter |
|---|---|
| Show TCP traffic involving port 8080 | `tcp.port == 8080` |
| Show packets involving the client | `ip.addr == 192.0.2.10` |
| Show packets involving the server | `ip.addr == 192.0.2.20` |
| Show initial SYN packets | `tcp.flags.syn == 1 && tcp.flags.ack == 0` |
| Show SYN-ACK packets | `tcp.flags.syn == 1 && tcp.flags.ack == 1` |
| Show TCP retransmission analysis labels | `tcp.analysis.retransmission` |
| Show TCP reset packets | `tcp.flags.reset == 1` |

## Interpreting the TCP handshake

A normal TCP three-way handshake consists of:

1. **SYN:** The client requests a TCP connection.
2. **SYN-ACK:** The server acknowledges the request and signals acceptance.
3. **ACK:** The client acknowledges the server's response.

For this lab, the handshake uses TCP port 8080 on the server.

## Analysing the failure capture

Apply the filter:

`tcp.flags.syn == 1 && tcp.flags.ack == 0`

The failure capture should show the five SYN attempts recorded during the experiment.

To investigate retransmissions, use:

`tcp.analysis.retransmission`

Wireshark may not label every repeated SYN as a retransmission. Inspect the packet sequence, timestamps and TCP sequence numbers as well.

The absence of a response alone does not prove that a firewall caused the failure. In this lab, the firewall rule counter and the successful recovery test provide additional evidence.

## Analysing the recovery capture

Use:

`tcp.port == 8080`

Confirm that the SYN, SYN-ACK and ACK are present, followed by the HTTP request and response.

A successful TCP handshake confirms that the connection was established. The HTTP response confirms that the application exchange also succeeded.
