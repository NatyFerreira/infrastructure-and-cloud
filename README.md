# Infrastructure & Cloud — Docker, Networking & Remote Deployment

![Docker](https://img.shields.io/badge/Docker-29.4-2496ED?logo=docker)
![Docker Compose](https://img.shields.io/badge/Docker_Compose-multi--container-2496ED?logo=docker)
![Ubuntu](https://img.shields.io/badge/Ubuntu-25.10-E95420?logo=ubuntu)
![SSH](https://img.shields.io/badge/SSH-ed25519-black?logo=gnubash)
![WordPress](https://img.shields.io/badge/WordPress-latest-21759B?logo=wordpress)
![NGINX](https://img.shields.io/badge/NGINX_Proxy_Manager-2.11.3-269539?logo=nginx)
![Node.js](https://img.shields.io/badge/Node.js-18--alpine-339933?logo=node.js)
![License](https://img.shields.io/badge/License-MIT-green)

Three-day module covering Docker fundamentals and multi-container orchestration, Linux networking and remote access, and cloud computing concepts validated through a real deployment to a remote VM.
Built as part of the Infrastructure & Cloud iteration (RNCP 37624 — Data Engineer & AI, Campus Numérique in the Alps, 2026).

---

## Architecture

```
infrastructure-cloud/
├── carburoam-docker/
│   ├── docker-compose.yml      # Streamlit service, completed config (volumes/entrypoint/command)
│   ├── Dockerfile
│   ├── .env                    # LOAD_MODE=local
│   ├── config.yaml             # Streamlit authenticator config
│   └── home.py
├── wordpress/
│   ├── docker-compose.yml      # 3-service stack: db, wordpress, npm
│   └── (no Dockerfile — official images only)
├── devops-training-nodejs/
│   ├── Dockerfile              # written from scratch, from the project README
│   ├── docker-compose.yml
│   ├── app.js
│   └── package.json
├── docker-wordpress-network-EN.drawio   # network flow diagram
└── README.md
```

Multi-container network flow (WordPress stack):

```
Internet
   │
   ▼
┌─────────────────────────────┐
│   NGINX Proxy Manager        │   networks: external + internal
│   ports: 80 · 81 · 443        │
└──────────────┬───────────────┘
               │ proxy → :80
               ▼
┌─────────────────────────────┐
│   WordPress (wordpress_app)  │   network: internal only
│   no exposed port             │
└──────────────┬───────────────┘
               │ db:3306
               ▼
┌─────────────────────────────┐
│   MariaDB (wordpress_db)     │   network: internal only
│   no exposed port             │
└──────────────┬───────────────┘
               │
               ▼
       volume: db_data (persistence)
```

Remote deployment flow (Day 3):

```
Mac (local)                          OrbStack VM (Ubuntu 25.10, ARM64)
┌──────────────────┐    rsync -av    ┌──────────────────────────┐
│ carburoam-docker/ │ ──────────────▶│ ~/carburoam-docker/       │
└──────────────────┘                 │                          │
                                      │ docker compose up --build│
                                      │ → carburoam:8501          │
                                      └──────────────────────────┘
        curl http://192.168.139.40:8501  confirms identical behaviour
```

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| Container engine | Docker Desktop 29.4.0 |
| Local VM | OrbStack — Ubuntu 25.10 (linux_arm64) |
| Orchestration | Docker Compose v2 |
| Reverse proxy | NGINX Proxy Manager 2.11.3 |
| CMS stack | WordPress (latest) + MariaDB 10.6.4-focal |
| App runtime | Node.js 18-alpine |
| Data app | Streamlit (Carburoam) |
| Remote access | SSH (ed25519 key pair) |
| File transfer | scp, rsync |
| Public tunneling | ngrok, Cloudflare Tunnel |
| Dynamic DNS | DuckDNS |
| Diagramming | draw.io |

---

## Day 1 — Docker & Docker Compose

### Project: Carburoam (Streamlit data visualization)

Public open-source fuel price dashboard. Completed missing configuration to get it running:

```yaml
volumes:
  - ./save:/app/save
  - ./outputs:/app/outputs
  - ./config.yaml:/app/config.yaml
entrypoint: ["/app/entrypoint.sh"]
command: ["streamlit", "run", "home.py"]
```

```bash
docker compose up --build
# http://localhost:8501
```

> Debugged: missing `pytz` dependency (added to `pyproject.toml`) and missing `config.yaml` mount for the Streamlit authenticator.

### Project: WordPress + MariaDB + NGINX Proxy Manager

Three-service stack demonstrating network isolation and reverse proxy design.

| Service | Image | Exposed ports | Network |
|---------|-------|----------------|---------|
| `db` | mariadb:10.6.4-focal | none | internal |
| `wordpress` | wordpress:latest | none | internal |
| `npm` | jc21/nginx-proxy-manager:2.11.3 | 80, 81, 443 | internal + external |

```bash
docker compose up -d
# WordPress reachable only via NPM proxy host (localhost:80)
# NPM admin panel: localhost:81
```

> **Bug fixed:** NPM 2.11.3 on ARM64 ships with an empty `user` table after first boot. Direct SQL `UPDATE` on the `auth.secret` column failed silently because the Objection.js `Auth` model's `$beforeUpdate` hook re-hashes `secret` on every update — double-hashing the password. Fixed by inserting through `Auth.query().insert()`, which correctly triggers `$beforeInsert` instead.

### Project: Node.js app — Dockerfile written from scratch

No existing Docker setup. Read the project's README and wrote the Dockerfile and compose file from the documented setup steps.

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package.json .
COPY app.js .
COPY .env .
RUN npm install
ENV PORT=3000
EXPOSE 3000
CMD ["npm", "start"]
```

```bash
docker compose up --build
curl http://localhost:3000
# {"message":"Hello from Docker!","hostname":"<container_id>","github_status":200}
```

### Public exposure

- `cloudflared` installed on the OrbStack VM, tunnel `wordpress-demo` connected and **Healthy**
- `ngrok http 80` on the Mac exposed the local WordPress instance with a public HTTPS URL
- DuckDNS account created (`natyferreira.duckdns.org`) to demonstrate dynamic DNS; full Let's Encrypt issuance requires a publicly routable IP, not available on this local/school network

---

## Day 2 — Networking & SSH

### SSH access

```bash
ssh natyferreira@ubuntu.orb.local
```

ed25519 key pair reused from the existing GitHub configuration.

### Network fundamentals

| Address type | Example observed | Tool |
|--------------|-------------------|------|
| Loopback | `127.0.0.1` | `ping 127.0.0.1` → ~0.05 ms |
| Private | `192.168.139.40` (VM) / `192.168.2.28` (Mac) | `ip addr` / `ifconfig` |
| Public | `2.7.148.73` | `curl ifconfig.me` |

```bash
ss -tulpen        # listening ports: 22 (SSH), 80/81/443 (Docker/NPM), cloudflared sockets
```

### Minimal network service (netcat)

```bash
nc -l 8080          # terminal A: listens
nc localhost 8080   # terminal B: connects
ss -tulpen | grep 8080   # confirms the listening socket
```

### Minimal REST API (Python standard library only)

```python
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())
        else:
            self.send_response(404)
            self.end_headers()

HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
```

| Request | Result |
|---------|--------|
| `curl http://localhost:8080/status` | `200 OK` — `{"status": "ok"}` |
| `curl -i http://localhost:8080/unknown` | `404 Not Found` |

> **Key distinction:** a service can be *listening* (visible in `ss`) without being *exposed* (reachable from the public internet). Services bound to a private IP are only reachable from the local network unless explicitly tunneled.

---

## Day 3 — Cloud Computing

### Service model classification

| Service | Model |
|---------|-------|
| Campus Skills | SaaS |
| Scaleway DB service | PaaS |
| Discord | SaaS |
| Google Drive | SaaS |
| AWS EC2 | IaaS |
| Google Translate API | PaaS |
| ChatGPT | SaaS |

### File transfer: scp and rsync

```bash
# single file, Mac -> VM
scp ~/Desktop/file.txt natyferreira@ubuntu.orb.local:~/

# single file, VM -> Mac
scp natyferreira@ubuntu.orb.local:~/file.txt ~/Desktop/

# full project sync, incremental
rsync -av ~/Desktop/carburoam-docker/ natyferreira@ubuntu.orb.local:~/carburoam-docker/
```

> Verified incremental behaviour: after adding a third file to an already-synced folder, a repeat `rsync` only transferred the new file, leaving the two already-synced files untouched.

### Cloud deployment of an existing app

Synced the full Carburoam project to the OrbStack VM and ran the same `docker-compose.yml` used locally:

```bash
ssh natyferreira@ubuntu.orb.local
cd ~/carburoam-docker
docker compose up -d --build
```

Validated from the Mac that the app behaves identically on the remote VM:

```bash
curl http://192.168.139.40:8501
```

### Background processes

| Method | Behaviour |
|--------|-----------|
| `command &` | Runs in background, lost if the SSH session disconnects |
| `jobs` / `fg` | Lists / brings background jobs back to the foreground |
| `screen -S name` | Creates a detachable virtual terminal |
| `Ctrl+A` then `D` | Detaches without killing the process inside |
| `screen -r name` | Reattaches to a running session |

### Performance measurement

```bash
time sleep 2
# real 0m2.023s | user 0m0.003s | sys 0m0.016s   -> CPU idle, just waiting

time python3 -c "sum(i*i for i in range(10000000))"
# real 0m0.281s | user 0m0.266s | sys 0m0.014s    -> CPU actively working
```

```bash
free -h
#               total   used   free   shared  buff/cache  available
# Mem:           11Gi   6.1Gi  3.1Gi    69Mi       2.8Gi       5.6Gi
# Swap:          12Gi      0B   12Gi
```

> When `real` time is much larger than `user + sys`, the process is waiting on something external (network, disk, sleep) rather than being CPU-bound.

---

## Network Diagram

Full network flow diagram (WordPress + NPM + MariaDB) available at [`docker-wordpress-network-EN.drawio`](docker-wordpress-network-EN.drawio) — open with [draw.io](https://app.diagrams.net/) or the draw.io desktop app.

---

## Author

**Natália Helen Ferreira**
PhD in Biological Chemistry | Data Engineer & AI (RNCP Level 7, in progress)
[LinkedIn](https://linkedin.com/in/ferreiranh) · [GitHub](https://github.com/NatyFerreira)

---

## License

MIT License — see [LICENSE](LICENSE) for details.
