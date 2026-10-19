# Evidence Checklist

## Lab results

- [x] Client and server namespaces created.
- [x] Virtual Ethernet link configured.
- [x] Client and server IP addresses configured.
- [x] Baseline ping test succeeded.
- [x] Baseline HTTP request returned `HTTP/1.0 200 OK`.
- [x] Client and server baseline captures saved.
- [x] Controlled TCP/8080 DROP rule introduced inside the server namespace.
- [x] Client and server failure captures saved.
- [x] Five SYN attempts observed in each failure capture.
- [x] Firewall counter recorded as 5 packets and 300 bytes.
- [x] DROP rule removed from the server namespace.
- [x] HTTP server restarted and listening socket verified.
- [x] Recovery HTTP request returned `HTTP/1.0 200 OK`.
- [x] Client and server recovery captures saved.

## Screenshots and documentation

- [x] `screenshots/baseline-handshake.png`
- [x] `screenshots/failure-syn-retries.png`
- [x] `screenshots/recovery-handshake.png`
- [x] `docs/topology.svg`
- [x] `docs/incident-report.md`
- [x] `docs/filters.md`
- [x] `README.md`

## Before publishing to GitHub

- [ ] Create and test the lab setup script.
- [ ] Create and test the controlled fault script.
- [ ] Create and test the cleanup script.
- [ ] Review screenshot readability.
- [ ] Verify README image and file links.
- [ ] Check report claims against the actual packet captures.
- [ ] Review files for credentials or unrelated personal information.
- [ ] Review the files staged for Git.
- [ ] Push the repository to GitHub and verify it in a browser.

## Evidence integrity

The completed lab results are based on actual commands, packet captures,
firewall counters and HTTP tests. Do not add invented frame numbers or
claim that tests were performed if they were not.
