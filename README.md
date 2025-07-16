
# RPM Snapshot Server

A lightweight Elixir-based server to manage RPM repository snapshots using symbolic links and `createrepo_c`. Supports dynamic tagging (e.g. monthly, half-monthly), automatic diff generation, and a simple browser interface.

## 🧰 Features

- API to create RPM snapshots and generate diffs
- YAML-based dynamic config (`repo_config.yaml`)
- Custom themes with light/dark mode
- Zero-downtime hot config reloading
- Lightweight, runs as a system service
- WASM-friendly design (for future layout engine)

---

## 📦 Requirements

- Elixir 1.15+
- Erlang/OTP 26+
- `createrepo_c`
- RPM folders with `.rpm` files organized in subfolders

---

## 📁 Project Structure

```
.
├── assets/                  # Static files like style.css
├── lib/rpm_server/         # Main application modules
│   ├── config.ex           # Loads and validates repo_config.yaml
│   ├── api.ex              # REST API handlers
│   ├── auth.ex             # API token authentication
│   ├── helpers.ex          # JSON response helpers
├── priv/static/style.css   # Custom frontend stylesheet
├── repo/                   # RPM data and tags
│   └── tags/               # Generated snapshot folders
├── repo_config.yaml        # Your repo definitions
├── mix.exs                 # Project file
├── rel/                    # Release config (mix release)
```

---

## ⚙️ Environment Variables

Set the following before running or releasing:

```bash
export REPO_CONFIG_PATH=/etc/rpm_server/repo_config.yaml
export RPM_API_TOKEN=your_secret_token
```

---

## 📝 `repo_config.yaml` Example

```yaml
base_path: /mnt/repos
repos:
  - id: base
    paths:
      - base/x86_64
      - base/noarch
  - id: appstream
    paths:
      - appstream/x86_64
```

---

## 🏗️ Build & Run

### Development

```bash
mix deps.get
mix run --no-halt
```

### Production Release

```bash
MIX_ENV=prod mix release
_build/prod/rel/rpm_server/bin/rpm_server start
```

---

## 🔐 API Usage

All API requests must include a bearer token:

```http
Authorization: Bearer your_secret_token
```

### Create Tag

```bash
curl -X POST "http://localhost:8080/api/create-tag?folder=base&type=half-monthly"   -H "Authorization: Bearer your_secret_token"
```

### List Tags

```bash
curl http://localhost:8080/api/list-tags?folder=base
```

### List Packages in Tag

```bash
curl http://localhost:8080/api/list-packages?folder=base&tag=half-monthly
```

---

## 🌐 Web UI

Access the browser interface at:

```
http://localhost:8080
```

To modify UI:

- Edit `priv/static/style.css`
- Rebuild if running a production release

---

## 🔥 Behavior When Config Is Missing or Invalid

- Server startup will **abort with an error**.
- API requests will **gracefully reject** with a warning if config is missing or invalid.
- Dynamic config reloading is supported per request — no server restart required.

---

## 🚀 Deployment Notes

1. Set environment variables using a systemd unit or `.env` file.
2. Place `repo_config.yaml` in a stable path like `/etc/rpm_server/`.
3. Use `mix release` to generate an executable for production.
4. The `priv/static/style.css` file is bundled in the release under:
   ```
   _build/prod/rel/rpm_server/lib/rpm_server-0.1.0/priv/static/style.css
   ```
---

## 🙏 Credits

This tools built with guidance from OpenAI’s ChatGPT.
