# Agent Instructions (Flutter app: `elecom_mobile`)

## Mobile appearance and notification work (2026-11-12)

### Working style and current paths

- User prefers guided deployment **one command at a time**, waiting for their output/screenshot. Distinguish local `PS G:\elecom_web>` / `PS G:\elecom_mobile>` from remote `root@elecom-servers:/var/www/elecom#`. Remote repository is `/var/www/elecom`, NOT `/var/www/elecom/web`.
- Current local repositories: `G:\elecom_mobile` (Flutter) and `G:\elecom_web` (Django/backend and admin frontend). Production backend `/var/www/elecom/backend`; Python `/var/www/elecom/venv/bin/python`; static destination `/var/www/elecom_static`; service `gunicorn`. Verify current Git state before changing or deploying anything. The user's older path examples are historical.
- User wants native-looking ELECOM dialogs, **not `window.confirm` browser popups**. Filing/Omnibus/top bar confirmations now use Bootstrap modals. Keep cancellation, keyboard dismissal/focus handling, and explicit save semantics. Browser-managed unsaved-page navigation warnings remain where needed.
- User wants appearance editors to fit the desktop admin frame, retain visible Save controls, and preview actual mobile proportions. Do not squeeze previews vertically to fill available space. Internal editor/list scrolling is deliberate; smaller screens retain normal page scrolling.

### Implemented appearance settings and files

- Sidebar **Mobile App Appearance** is a Bootstrap dropdown with **Filing Cards**, **Omnibus Code**, and **Top Bar Background**. Navigation is duplicated across admin HTML pages and `sidebar.html`; keep copies consistent. Files:
  - `frontend/org_elecom/elecom_admin/elecom_mobile_appearance.html`
  - `frontend/org_elecom/elecom_admin/elecom_omnibus_appearance.html`
  - `frontend/org_elecom/elecom_admin/elecom_topbar_appearance.html`
- New pages must be added to `backend/core/views.py` `_ADMIN_PAGE_ALLOWLIST` and the breadcrumb map in `admin_components/admin_js/admin_user_menu.js`. Signed admin navigation rejects unknown pages by redirecting to Dashboard. Restart old Gunicorn workers after deploying allowlist/backend changes.
- `admin_user_menu.js` must select `#candidatesSubmenu` explicitly for Candidates expansion persistence; selecting the first `.candidates-submenu` now incorrectly selects the Appearance group. Active Appearance pages expand their own group.
- Shared stylesheet: `admin_components/admin_css/election_appearance.css`. Dedicated scripts: `election_appearance.js`, `omnibus_appearance.js`, `topbar_appearance.js`, and shared `appearance_image_crop.js`. Bump asset query versions after changes so cached JS/CSS do not conflict with new HTML.
- All three settings are **per election**. Admin defaults to current election but can edit another independently. Mobile reads the same election ID returned by `election_window_api`; do not pick a different election for appearance or change turnout scoping.

### Filing cards

- Backend `core/election_appearance.py`; admin GET/POST/DELETE `/api/admin/elections/<id>/appearance/`; mobile election-window fields `filing_card_background` (legacy) and `filing_card_slides`.
- Migrations `0018_election_mobile_appearance` creates the table; `0019_election_filing_slideshow` adds JSONB `slides`. Migration reverse operations intentionally do not drop data. Legacy single-image settings convert to one editable Ready to Serve slide; preserve compatibility.
- Editor supports 1–10 ordered slides: add, remove, reorder, per-slide image, provided design/text preset, default-image restore, provided/custom title and description. Limits: title 60, description 160 characters. `use_default_text` is authoritative server-side. Save publishes the complete draft; Restore all defaults immediately resets the selected election after confirmation.
- Five defaults match Flutter assets in `assets/candidates_model/` and web `frontend/assets/filing-slides/0.png` through `4.png`: Lead the Change; Your Voice, Your Run; Ready to Serve?; Be on the Ballot; Make It Official. Their original descriptions are in backend `DEFAULT_SLIDES` and Flutter widget. Do not replace filing button behavior when changing copy.
- Flutter `widgets/candidate_application_promo.dart` accepts remote `slides` plus legacy `backgroundImageUrl`; falls back to bundled images and uses centered cover. Preserve original 4-second auto-slide, dots/swipe, and File now action. **Compare list content, not identity**, in `didUpdateWidget`: dashboard foreground polling creates new lists every ~3 seconds; identity comparison resets the carousel before its 4-second advance.
- Real mobile filing aspect ratio is **2.22:1**. Admin preview uses up to 358px width, the corresponding unsquashed height, 15px title / 10px description, 32px button and matching left-copy area/gradient. Desktop list sits beside the preview; editor fields scroll separately. Do not restore the previous full-width, compressed-height preview.

### Omnibus Code

- Backend `core/omnibus_appearance.py`; migration `0020_election_omnibus_pages`; table `election_omnibus_pages`; admin GET/POST/DELETE `/api/admin/elections/<id>/omnibus/`; mobile field `omnibus_pages`.
- Ordered page entries: `id`, `default_index` (0–13 or null for new uploads), `image_url`. Defaults are the 14 original `assets/omnibus/page01.jpg` through `page14.jpg`; web copies under `frontend/assets/omnibus/`.
- Admin supports adding multiple files in numeric filename order, replacing selected image, reorder, remove, restore originals, and explicit Save Omnibus pages. Keep 1–30 pages; each new page needs a validated upload. No arbitrary external image URLs.
- Flutter `widgets/omnibus_code_carousel.dart`: `pages` resolves trusted Cloudinary images or bundled defaults; custom images are used by **both carousel and full-screen zoom reader**. Missing/invalid configuration falls back to original pages. Actual changed page paths reset carousel position; identical refreshes must not reset it.
- Real mobile carousel shows **two pages side by side, 200px high**, with centered `BoxFit.cover`, 8px gap and paired-page dots. Admin preview now matches this at a 358px reference width, highlights selected page and displays its paired neighbor. An odd final page is centered. Do not use a single enlarged `object-fit:contain` image as the mobile carousel preview; full-screen reader is a separate presentation.

### Top Bar Background (latest feature)

- Backend `core/topbar_appearance.py`; migration **`0021_election_topbar_appearance`**; table `election_topbar_appearance`; admin GET/POST/DELETE `/api/admin/elections/<id>/topbar/`; mobile field `topbar_background`.
- Admin page offers election selection, upload/crop, phone-sized preview with sample greeting/icons, Save background and styled Restore default confirmation. Selected images remain drafts until saved. Restore immediately resets selected election.
- Flutter `widgets/home_header_background.dart` is used inside `_buildHomeHeader` in `student_dashboard.dart`. Header remains **170 logical pixels high**, centered `BoxFit.cover`, with existing greeting/avatar/search/notification controls and dark gradient. Reference admin preview is 390 × 170; crop exports 1560 × 680.
- Default is `assets/USTP PICS/USTP_FRONT.png`, web copy `frontend/assets/mobile-topbar-default.png`. Network loading/errors and untrusted URLs fall back to the bundled campus image. Only background changes; do not redesign existing Home header controls.
- `student_dashboard.dart` refreshes `_topbarBackground`, `_omnibusPages`, and filing configuration through its existing election-window refresh/resume flow. Failed requests retain last successful in-memory configuration. Custom remote images have no guaranteed persistent offline cache.

### Crop dialog, upload security and publication

- `appearance_image_crop.js` opens a styled modal after selecting local files: drag positioning, arrow-key positioning on focused canvas, zoom slider, Reset crop, Cancel and Use cropped image. Exports JPEG locally before upload. Local object URLs are revoked; canceled crops do not enter the draft. Guards prevent late canceled exports from affecting another dialog.
- Filing crop 1600 × 720; Omnibus portrait crop 1131 × 1600 with **Keep full image** to avoid clipping document edges; top bar crop 1560 × 680. Multiple Omnibus uploads are processed one crop dialog at a time; Cancel skips that file. Cropping alone does not publish anything.
- Image pipeline validates actual Pillow image bytes (JPG/PNG/WebP), maximum 5MB per image, dimensions 100–4096 each side, EXIF orientation, stripped metadata and JPEG re-encoding within 1600 × 1600. Filing/Omnibus saves limit new uploads to 15MB total. Cloudinary credentials remain backend-only.
- APIs require an administrator session, an existing election and CSRF for writes; private/no-store responses. Saved image URLs may be retained only for the selected election; new URLs must come from upload. Mobile accepts only HTTPS `res.cloudinary.com` URLs. Avoid introducing credentials or arbitrary remote URL fields.
- Validate all files before uploads; publish database settings only after all uploads succeed. Upload failure preserves the saved setting, though orphaned newly uploaded Cloudinary assets can remain. Replacement/removal/reset does not delete remote assets that might still be referenced.

### Deployment evidence, known fixes and next verification

- User screenshots confirmed web pushes/pulls, migrations **0018 OK**, static collection, and Gunicorn restarts. Slideshow and Omnibus editors subsequently loaded and displayed saved/default/custom images in production screenshots. This is evidence of those displayed screens, not comprehensive device/upload verification.
- Do **not** infer migrations 0019/0020/0021 applied from Git pull alone; request/check output or `showmigrations` when relevant. The latest Top Bar Background implementation passed local tests; **its production deployment, migration0021, real upload and phone rendering were not verified in this session**. Check Git status/log before assuming anything is still uncommitted or already pushed; user often commits between turns.
- A new sidebar item redirecting to Dashboard previously occurred with old Gunicorn allowlist code; restart after deploying backend changes. “Loading elections…” or huge unstyled previews occurred when new HTML loaded old collected JS/CSS; run collectstatic and hard refresh. Do not blame all loading failures on cache without checking response/logs.
- Appearance page originally inherited `<html class="election-viewport">` and `elecom_elections.css`, which set `overflow:hidden` for the Election Management viewport. Removed both from Appearance pages to restore scrolling; later added scoped desktop workspace scrolling. Do not reintroduce that class/stylesheet.
- Remote steps (guide separately, one at a time after local commit/push): `git -C /var/www/elecom pull origin main`; `/var/www/elecom/venv/bin/python /var/www/elecom/backend/manage.py migrate`; same Python/manage.py `collectstatic --noinput`; `sudo systemctl restart gunicorn`; `sudo systemctl is-active gunicorn`; browser Ctrl+Shift+R. Leave untracked `venv-python310/` alone. No need to reinstall dependencies or modify .env for CSS/JS changes.
- Initial mobile support for remote slideshow/Omnibus/top bar requires an updated app build/run. Once supported, later admin image/text edits need no APK rebuild. Editor-only layout/crop/dialog changes need neither database migration nor APK rebuild. Do not claim a release APK was built; none was built by this appearance work.
- Final local checks: **39 backend tests passed** across `core.test_topbar_appearance`, `core.test_omnibus_appearance`, `core.test_election_appearance`, `core.test_filing_slideshow`, `core.test_mobile_turnout`; Django system check passed. Node suites `topbar_appearance.test.cjs`, `appearance_image_crop.test.cjs`, `omnibus_appearance.test.cjs`, `filing_slideshow.test.cjs` passed. **9 Flutter tests passed** across header, Omnibus and filing tests. New header widget analyzer clean. Earlier full Flutter analysis had existing unrelated findings; do not call whole repo analysis clean.
- Docs: `docs/mobile-filing-card-appearance.md`, `docs/mobile-omnibus-appearance.md`, `docs/mobile-topbar-appearance.md` in web repo. Tests use mocked uploads; actual production crop/upload/phone rendering still need end-to-end checks.

### Related notification context (do not confuse with appearance)

- Mobile push was repaired using ignored `android/app/google-services.json` for Firebase project `elecom-359a2`, Android ID `com.elecom.mobile`. Server SDK key configured privately at `/etc/elecom/firebase-admin.json`. Never commit/bundle service-account files; accidental exposed key rotation was advised but not verified. Public Firebase web configuration/VAPID key are different from server private keys; avoid repeating their values in memory files.
- Background mobile notification was shown on the phone Home screen. Swiped-away/reboot cases were not conclusively verified. Android Settings Force stop blocks delivery until reopen; permission/internet/OEM battery restrictions matter.
- Admin notifications implemented via `core/admin_browser_push.py`, `deliver_admin_push` management command and shared `admin_notifications.js`; opt-in browser push plus in-app bell/toasts. `deploy/elecom-admin-push.service` / `.timer` were installed/enabled; journal showed successful worker execution with 0 batches. That does not prove a browser subscribed or received a real filing alert.
- Admin feed covers submitted pending candidacies, supporting documents requiring review, and existing operational alerts (backup/transparency/network). Opening the filing form alone is not a submission. Background timer checks about once a minute; visible in-app feed polls about every 10 seconds. Desktop push is generic to avoid disclosing student details.
- Use existing private environment setup and authorized tests; do not send test SMS/messages without explicit authorization. Process `active`, API queue acceptance and screenshot UI visibility are not equivalent to end-to-end notification delivery.


## Replacement Kamatera server and CloudBeaver recovery (2026-11-03)

### Verified deployment and user preferences

- User requested guided setup one screen/command at a time. Continue that style; distinguish the remote `root@elecom-servers` Linux terminal from local `PS G:\...` PowerShell. Wait for the prompt before the next command. In nano: Ctrl+O, Enter, Ctrl+X; `*` indicates unsaved changes. Do not paste prompts into commands.
- Replacement Kamatera server label: `elecom-servers`; Singapore (AS-SG), B General, 1 CPU, 1GB RAM, 20GB NVMe, public networking on, private networking/management/daily backup off. Displayed monthly base price was $9; this is a historical quote, not a current price guarantee. Old server specs were NOT established. The earlier 2 CPU/4GB/40GB suggestion was $42/month and exceeded the user's under-$10 budget.
- Public IPv4 at setup: `74.113.234.239`. Confirm the current address before future work. DuckDNS `el3com.duckdns.org` (website/mobile API) and `elecom-db.duckdns.org` (CloudBeaver) were pointed at it. Do not confuse `el3com` with `elecom-db`.
- The new account displayed a 30-day promotional offer, but eligibility/remaining credit was NOT independently confirmed. A new account does not establish a new trial for a previous customer. Check current Kamatera terms and account billing; do not promise free hosting. Saved-card billing can be automatic.
- Verified: database SQL import screenshot reached COMMIT; subsequent migration `elecom_auth.0011_coc_text_formatting` applied OK. Actual import command, backup filename/freshness and all preparatory restore steps were not visible in this session. Do not infer these from COMMIT alone. Web login and admin dashboard with restored records worked over HTTPS. CloudBeaver connected and displayed database tables. Mobile login, OTP delivery, uploads, face verification, load behavior, and all application flows were NOT verified.

### Runtime, packages and repository

- Ubuntu 22.04.5 was installed. IMPORTANT: choosing it for presumed older face dependency compatibility happened before checking requirements and caused a Python mismatch. The cloned requirements specify `django>=6.0`, requiring Python >=3.12; Ubuntu 22.04 default Python 3.10 cannot install them. Inspect current requirements before selecting an OS/runtime next time. Do not downgrade Django just to fit Python 3.10.
- Setup used `apt update`, `apt upgrade -y`, accepted default needrestart selections, then rebooted and reconnected with `ssh root@74.113.234.239`. Kernel update notices are normal; finish apt before rebooting.
- Installed system packages: `git nginx python3-venv python3-dev build-essential libpq-dev libgl1 libglib2.0-0 curl ca-certificates gnupg`. Added `postgresql-common`, ran `/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh`, then installed `postgresql-16 postgresql-client-16`. `pg_lsclusters` confirmed 16/main online at 5432. Check official PostgreSQL Ubuntu instructions for changes.
- Repository: `https://github.com/RedjanVisitacion/elecom_web.git`, cloned into `/var/www/elecom`; backend `/var/www/elecom/backend`. Local source is `G:\elecom_web`. Git does not restore the private `.env`.
- To fix Python: installed `software-properties-common`, added third-party `ppa:deadsnakes/ppa`, installed `python3.12 python3.12-venv python3.12-dev`. Kept system Python unchanged. Renamed initial environment with `mv -T -n /var/www/elecom/venv /var/www/elecom/venv-python310`, then created `python3.12 -m venv /var/www/elecom/venv`. Verify destination state before repeating any rename. The old environment is preserved, not a usable relocated venv guarantee.
- Updated pip/setuptools/wheel in the new venv, installed with `/var/www/elecom/venv/bin/python -m pip install --no-cache-dir -r /var/www/elecom/backend/requirements.txt`. Install succeeded; `pip check` reported no broken requirements. Broad minimum constraints resolved newer packages (including Django 6.1.2) at that time; this is not a pinned, fully regression-tested environment.
- Memory preparation: `free -h` showed ~956Mi RAM and no swap. Checked `/swapfile` absent, then ran separately: `fallocate -l 2G /swapfile`, `chmod 600 /swapfile`, `mkswap /swapfile`, `swapon /swapfile`; `free -h` confirmed 2Gi swap. Persisted using `grep -qE '^/swapfile[[:space:]]' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab`. Swap does not establish adequate face-verification capacity. Check disk/memory before installing more services; ~9.9GB free was seen before pulling CloudBeaver.

### Database and Django settings

- Created dedicated PostgreSQL login with `sudo -u postgres createuser --pwprompt elecom_user`, then `sudo -u postgres createdb --owner=elecom_user elecom_db`. Password entered interactively and never recorded. Verified TCP authentication using `psql -h 127.0.0.1 -U elecom_user -d elecom_db -W -c "SELECT current_database(), current_user;"`.
- Created private `/var/www/elecom/backend/.env` with mode 600. Only use `install -m 600 /dev/null ...` when the file is confirmed absent: it would overwrite an existing file. User copied local environment values, adapting server settings. Recheck Windows paths, Firebase credential file availability, and provider settings rather than assuming the copy is production-ready.
- Actual supported names found: `DJANGO_DEBUG`, `DJANGO_SECRET_KEY`, `DJANGO_ALLOWED_HOSTS`. `DJANGO_DEBUG` defaulted to True when absent. Set `DJANGO_DEBUG=False`; allowed-host value used `el3com.duckdns.org,74.113.234.239,localhost,127.0.0.1`. Hosts are comma-separated names/IPs, not URLs.
- Earlier active database settings still selected `postgres`/`localhost` despite `.env` edits. Backed up settings to `/root/elecom-settings-before-db-fix.py`; instructed replacing the active DATABASES block with PostgreSQL ENGINE and `os.getenv` for DB_NAME, DB_USER, DB_PASSWORD, DB_HOST, DB_PORT (defaults `elecom_db`, `elecom_user`, empty password, `127.0.0.1`, `5432`). A later settings check still showed postgres/localhost; final migration and application success do NOT prove this specific user/config discrepancy was resolved. Reverify effective sanitized settings before assuming the app uses elecom_user. Server settings changes must be reconciled with Git before future pulls; do not discard them blindly.
- Run settings checks from `/var/www/elecom/backend`; running from repository root caused `ModuleNotFoundError: core`. Print only ENGINE/NAME/USER/HOST/PORT, DEBUG and other nonsecret settings; never print DATABASES wholesale or `.env`.
- `manage.py check --deploy` initially warned about weak SECRET_KEY, SSL redirect, HSTS, session secure cookies and CSRF secure cookies. Generated a new random `DJANGO_SECRET_KEY` directly into `.env` without printing it. Secret replacement invalidates signed sessions. Remaining HTTPS/cookie/HSTS/proxy warnings were NOT subsequently resolved or rechecked; setup is not fully hardened just because login works. Configure proxy SSL handling correctly before enabling Django HTTPS redirects to avoid loops.
- `collectstatic --noinput` copied 259 files to `/var/www/elecom_static`. Created system account `adduser --system --group --no-create-home elecom`; changed `.env` owner to elecom:elecom while retaining mode 600. Basic `sudo -u elecom ... manage.py check` passed; this is not comprehensive flow or database validation.

### Gunicorn, Nginx and certificates

- `/etc/systemd/system/gunicorn.service` created with the following configuration. Do not replace an existing service without inspecting it first:

```ini
[Unit]
Description=ELECOM Gunicorn
After=network.target postgresql.service

[Service]
User=elecom
Group=elecom
WorkingDirectory=/var/www/elecom/backend
StateDirectory=elecom
Environment=HOME=/var/lib/elecom
Environment=OMP_NUM_THREADS=1
Environment=OPENBLAS_NUM_THREADS=1
ExecStart=/var/www/elecom/venv/bin/gunicorn core.wsgi:application --bind 127.0.0.1:8000 --workers 1 --threads 2 --timeout 120 --access-logfile - --error-logfile -
Restart=on-failure
RestartSec=5
UMask=0027

[Install]
WantedBy=multi-user.target
```

- Ran `systemctl daemon-reload`, `systemctl enable --now gunicorn`; status confirmed active. HOME under /var/lib/elecom provides writable runtime/model cache location, but model download/face flow was not tested. Check any other writable media/log/Firebase paths before broad ownership changes.
- Gunicorn GET `/` with Host el3com.duckdns.org returned 302 to `/login/`; GET `/login/` returned 200. Later Nginx/domain HTTP test resolved 74.113.234.239 and returned 200. Browser IP first returned Django 400; added current IP to DJANGO_ALLOWED_HOSTS and restarted Gunicorn.
- Nginx site `/etc/nginx/sites-available/elecom`, enabled by symlink under sites-enabled. Initial block: listen 80; server_name el3com.duckdns.org 74.113.234.239; client_max_body_size 20M; `/static/` alias `/var/www/elecom_static/`; `/` proxy_pass `http://127.0.0.1:8000`, headers Host `$host`, X-Real-IP `$remote_addr`, X-Forwarded-For `$proxy_add_x_forwarded_for`, X-Forwarded-Proto `$scheme`, proxy_read_timeout 130s. Always `nginx -t` before reload. Default site remained enabled.
- Installed `certbot python3-certbot-nginx`, ran `certbot --nginx -d el3com.duckdns.org --redirect`. Certificate issued and deployed, automatic renewal scheduled. Browser HTTPS login and dashboard verified. Renewal dry-run, firewall/SSH hardening and automated database backups remain unverified. Certificate expiry shown was 2027-02-01; use current `certbot certificates` rather than relying on that historical date.
- Production mobile API base is `https://el3com.duckdns.org`, without `/login/` or `/api/mobile/` suffix. Existing production APK should reconnect at same HTTPS address; builds with local override need production configuration again. User had api_config.dart edits visible; no mobile code change or rebuild was performed by this recovery workflow.

### CloudBeaver: online HTTPS database browser

- User explicitly wants direct online browser access, like their previous server, without requiring a PC SSH tunnel. Final address: `https://elecom-db.duckdns.org`. Initial localhost SSH tunnel worked but is optional now. PostgreSQL port 5432 and CloudBeaver port 8978 were NOT opened publicly.
- Installed Ubuntu `docker.io`; `systemctl is-active docker` returned active. Pulled `dbeaver/cloudbeaver:latest`, created named volume `cloudbeaver_workspace`. Verify current image documentation before future deployment; latest is mutable.
- Started container using:

```bash
docker run -d --name cloudbeaver --restart unless-stopped --memory=512m --memory-swap=1g -p 127.0.0.1:8978:8978 -e JAVA_TOOL_OPTIONS="-Xms64m -Xmx256m" -e CLOUDBEAVER_APP_ANONYMOUS_ACCESS_ENABLED=false -v cloudbeaver_workspace:/opt/cloudbeaver/workspace dbeaver/cloudbeaver:latest
```

- Container stayed Up; localhost UI loaded. Memory limits/JVM options were supplied, but effective heap and sustained concurrent app/CloudBeaver memory performance were not measured. Do not run a duplicate named container. Named volume preserves settings, not an independent database backup.
- Nginx `/etc/nginx/sites-available/cloudbeaver` enabled with symlink. server_name elecom-db.duckdns.org; client_max_body_size 20M; location `/` proxies to `http://127.0.0.1:8978`, HTTP/1.1, same Host/client/proto headers as above, Upgrade `$http_upgrade`, Connection `"upgrade"`, proxy_read_timeout 300s. Initially restricted with `allow 127.0.0.1; deny all;` to protect the unclaimed setup wizard. Obtained certificate with `certbot --nginx -d elecom-db.duckdns.org --redirect` successfully.
- Installed `apache2-utils`, created browser Basic Auth login `dbadmin` using `htpasswd -cB /etc/nginx/cloudbeaver.htpasswd dbadmin` with interactive private password. `-c` overwrites the file: omit it for subsequent user/password updates. Replaced temporary allow/deny with `auth_basic "CloudBeaver Administration";` and `auth_basic_user_file /etc/nginx/cloudbeaver.htpasswd;`. A typo `Aauth_basic_user_file` failed nginx -t; corrected it. A 403 persisted until Nginx was actually reloaded: file edits plus a passing test do not apply changes. Final HTTPS browser password prompt worked. Verify htpasswd file ownership/readability if future auth errors occur; never print hashes.
- Completed setup online. Recommended server label ELECOM Database, allowed server URL elecom-db.duckdns.org, session lifetime 30min, anonymous access off, local authentication on. CloudBeaver administrator login `cbadmin`, private separate password. Force HTTPS mode left off pending proxy verification; Nginx already redirects HTTP to HTTPS. UI setup completed; do not assume every recommended toggle was independently inspected afterward.
- Three distinct credentials: Nginx browser `dbadmin`; CloudBeaver application `cbadmin`; PostgreSQL `elecom_user`. Never confuse their passwords or include any in docs/screenshots.
- Docker bridge inspection showed container `172.17.0.2`, gateway `172.17.0.1`. Container localhost is NOT host PostgreSQL. Added private host listener via `sudo -u postgres psql -c "ALTER SYSTEM SET listen_addresses = 'localhost,172.17.0.1';"`.
- Backed up `/etc/postgresql/16/main/pg_hba.conf` to `/root/pg_hba-before-cloudbeaver.conf`; appended `host elecom_db elecom_user 172.17.0.2/32 scram-sha-256`. Checked `pg_hba_file_rules WHERE error IS NOT NULL` returned zero rows; restarted `postgresql@16-main`. `ss -ltnp 'sport = :5432'` confirmed only 127.0.0.1 and 172.17.0.1 listeners.
- CloudBeaver PostgreSQL connection: host 172.17.0.1, port 5432, database elecom_db, username elecom_user, private database password. TEST succeeded against PostgreSQL 16.15; created connection and user displayed `users` table data. Schema navigation: connection -> Schemas -> public -> Tables. This is LIVE production data; edits/deletions affect the app.
- The /32 HBA rule depends on the container IP. Recheck after recreation/network changes; do not broaden to public ranges to fix it. PostgreSQL binding to a Docker interface also needs boot-order/reboot verification (Docker must provide that interface); no reboot test was performed after this change. Consider a stable dedicated Docker network and explicit service ordering when making persistence robust.

### Outstanding recovery work and confidentiality

- Do not call the system bug-free: verified web login/dashboard and CloudBeaver reads only. Finish Django HTTPS secure-cookie/proxy configuration and rerun deploy checks, test certificate renewal, configure fresh automated off-server backups, review firewall/SSH access, verify app DB role, server Git diff and runtime write paths. Test mobile/API, face models, uploads, Firebase and OTP separately with user authorization for any test SMS.
- TextBee key and DuckDNS token appeared in user screenshots. Rotation was advised but NOT verified. Never reproduce their values. User table screenshots included student identifiers/password hashes: do not transcribe or store them. Ask for sanitized screenshots and avoid displaying `.env`, credential files, SQL backup rows or password hashes.
- Official references: https://www.postgresql.org/download/linux/ubuntu/ ; https://docs.djangoproject.com/en/dev/releases/6.0/ ; https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa ; https://github.com/dbeaver/cloudbeaver/wiki/CloudBeaver-Community-deployment-from-docker-image . Verify current docs when repeating setup.

## Local PostgreSQL recovery after server termination (2026-11-02)

- User reported the Kamatera server was terminated and set up a temporary local backend. Current backend checkout is `G:\elecom_web\backend`; PostgreSQL 16 is reachable at `localhost:5432`, database `elecom_db`, local administrator `postgres`. Never record the actual password. PostgreSQL 18 also appeared as an older pgAdmin registration; select the intended server explicitly.
- Backend settings inspected during recovery had an active hardcoded DATABASES block, so `.env` edits alone did not change the connection. User was instructed to use `os.getenv` for `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, and `DB_PORT`. Verify the current settings before future changes; keep credentials in the untracked local `.env`.
- Backup used: `E:\elecom_postgres_2026_20261027_022717.sql` (about 27.7 MB), PostgreSQL 16.15 dump. This particular backup contains data INSERTs and sequence resets, not CREATE TABLE definitions. It begins a transaction and TRUNCATEs application tables, so it replaces target data; do not import into a populated database without confirming the intended target. Do not print backup row contents: it contains personal/account data.
- Confirmed recovery sequence on the user's local database:
  1. Run Django migrations to create managed tables.
  2. Run the existing system-table setup below. Migrations alone omitted `admin_candidate_documents`; the first import stopped at the initial TRUNCATE with that missing relation and did not restore data.
  3. Import the SQL with psql and `ON_ERROR_STOP=1`; user screenshot confirmed final COMMIT.
  4. Run migrations again after import because the backup also restores `django_migrations`. In this recovery `elecom_auth.0011_coc_text_formatting` applied successfully afterward.

```powershell
# Run one command at a time from G:\elecom_web\backend.
.\venv\Scripts\python.exe manage.py migrate
.\venv\Scripts\python.exe manage.py shell -c "from core.views import _ensure_all_system_tables; _ensure_all_system_tables(); print('Table setup complete')"
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -h localhost -p 5432 -U postgres -d elecom_db -W -v ON_ERROR_STOP=1 -f "E:\elecom_postgres_2026_20261027_022717.sql"
.\venv\Scripts\python.exe manage.py migrate
.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

- Local venv was missing `numpy` (blocked manage.py check through local_face_service) and `whitenoise` (blocked WSGI middleware loading despite check passing). User installed each with `.\venv\Scripts\python.exe -m pip install <package>`. Screenshots then confirmed system checks passed and Django started at `http://0.0.0.0:8000/`. This does not verify face-recognition dependencies or all application flows. A successful plain manage.py check alone does not confirm database connectivity; showmigrations subsequently connected successfully.
- Open `http://127.0.0.1:8000/` on the PC; `0.0.0.0` is the bind address. At handoff, server startup was confirmed, but browser login and Flutter-to-local connectivity were not yet verified. Keep the server terminal running.
- Phone connection requires a reachable PC LAN IPv4 address, the phone on the same reachable network, suitable Django ALLOWED_HOSTS, private-network firewall access to port 8000, and Flutter launched/built with `--dart-define=API_BASE_URL=http://<PC-LAN-IP>:8000`. The normal APK defaults to production and will not automatically use localhost. Do not expose the development server as public production hosting.
- Returning online: provision PostgreSQL/backend dependencies, deploy Django, restore the database, configure server-only `.env`, Gunicorn/Nginx/HTTPS, and point `el3com.duckdns.org` at the replacement server. If local records changed, take a fresh local backup for the move rather than reusing the October 27 backup. Existing production-configured APKs should reconnect when the same HTTPS API address works; local-configured builds need the production URL again. No replacement-server deployment was performed or verified in this recovery session.

> Current-machine path correction (2026-11-01): this checkout is `G:\elecom_mobile`; the sibling web/backend checkout is `G:\elecom_web\backend`. Older `F:` examples below are historical; verify paths before using them. Production remains `/var/www/elecom/backend`.

> Intended for any AI coding agent working in this workspace. If you maintain `CLAUDE.md` or `GEMINI.md` elsewhere, keep them aligned with this file.

This repository is a **Flutter** client for the ELECOM voting app. Optimize for **fast, safe iteration**: small changes, `flutter analyze` clean, and runnable builds.

## What this repo is (and is not)

- **This repo (`elecom_mobile`)**: Flutter UI, local config, and HTTP calls to the backend. There is **no Django/Python API code here**.
- **Backend (Django)**: Lives in a **separate** tree, typically next to this project, e.g. `F:\elecom_web\backend` (contains `manage.py`, `core/settings.py`, `core/urls.py`, `core/views.py`, `elecom_auth/`, `.env`). If the user mentions "the backend," **open or reference that path explicitly**; it is not under `lib/backend/` unless they added a stub folder.

Agents fixing **404/500 on API routes**, **email/OTP**, or **DB behavior** must edit the **Django backend** project, not only this Flutter repo.

## Repo map (where to put code)

- **App entrypoint**: `lib/main.dart` boots notifications/services then runs `ElecomApp`.
- **App shell / routing / top-level widgets**: `lib/app/`
- **Reusable "core" concerns** (config, networking, session, notifications, ledger, etc.): `lib/core/`
- **Feature modules** (screens, controllers, feature-specific widgets/services): `lib/features/`
- **Assets**: `assets/` and `pubspec.yaml` `flutter/assets`

## API base URL (Flutter)

- **Preferred**: `flutter run --dart-define=API_BASE_URL=http://<host>:8000`
- **Implementation**: `lib/core/config/api_config.dart` reads `String.fromEnvironment('API_BASE_URL')`. The current fallback on all platforms is `https://el3com.duckdns.org` (production). Local development requires an explicit override; do not assume the default points to a local server.
- **Rule**: Do not scatter hardcoded base URLs; use `ApiConfig.baseUrl` (or the same pattern) for new HTTP code.

## Mobile HTTP API shape (contract hints)

The app calls Django under **`{baseUrl}/api/mobile/...`** for most mobile flows. Examples:

- Forgot password: `POST /api/mobile/auth/forgot-password/`, `POST /api/mobile/auth/verify-otp/`, `POST /api/mobile/auth/reset-password/` (see `lib/features/auth/data/forgot_password_api.dart`). Step 1 returns **404** with `ok: false` when no account matches the Student ID or email (no OTP is sent).
- Responses are usually JSON with an **`ok`** boolean; clients may throw if the body is not JSON (e.g. Django HTML error pages).

If the client gets **404**, check **`core/urls.py`** on the backend for the path. If **500** with "unexpected" in the app, the server may have returned **non-JSON**; check Django logs and the matching view in **`core/views.py`**.

## Backend configuration (high level)

The Django server reads **`backend/.env`** (loaded in `core/settings.py`). Relevant knobs agents often touch:

- **Database**: `DATABASES` / `DB_*` as used in that project's settings.
- **Email (forgot-password OTP)**: `EMAIL_BACKEND`, `EMAIL_HOST*`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL`. Default backend may be **console** (no real inbox) unless SMTP is set in `.env`.

Restart **`runserver`** (or the production process) after changing `.env` or URL routes.

## SMS OTP — TextBee gateway (confirmed working 2026-10-10)

TextBee is the current SMS provider. SMS Chef is retained only for explicit rollback;
do not restart diagnosis by switching SIM indexes or returning to SMS Chef.

### Ownership and configuration

- Flutter requests OTP through `POST /api/mobile/auth/forgot-password/` with `method: "sms"`. Django owns SMS dispatch; never put gateway credentials in Flutter.
- Backend source: `F:\elecom_web\backend`. Production: `/var/www/elecom/backend`. Local and server `.env` files are separate; Git does not deploy `.env`.
- `_send_otp_sms` in `backend/core/views.py` selects `SMS_PROVIDER`. TextBee dispatch is in `backend/core/textbee_sms.py`; configuration is in `backend/core/settings.py`; tests are in `backend/core/test_textbee_sms.py`.
- Configure the server with the following (never document actual API keys):

```dotenv
SMS_PROVIDER=textbee
TEXTBEE_API_KEY=<private TextBee key>
TEXTBEE_DEVICE_ID=<registered TextBee device ID>
TEXTBEE_SIM_SUBSCRIPTION_ID=
```

- Known gateway: Realme RMX3261. The TextBee device ID is different from the old SMS Chef device ID; copy it from TextBee, never reuse the SMS Chef ID.
- In the TextBee Android app: Gateway Enabled ON; Default SIM **TM (SIM 2), Android subscription ID 2**. TNT is subscription ID 1. TM has the user's active text plan; earlier failed attempts used TNT.
- Leave `TEXTBEE_SIM_SUBSCRIPTION_ID` **blank** for this deployment. The backend omits `simSubscriptionId`, matching successful website sends and using the app's TM default. An explicit override is supported if deliberately required elsewhere.
- Android subscription IDs are not SIM slot indexes and can change after SIM swaps. Never infer provider numbering from Android slot indexes. Older SMS Chef 0/1 instructions were inconsistent and must not be reused as facts.
- Grant SMS/phone permissions, keep gateway internet connected, and allow background operation. A gateway enabled flag does not prove current connectivity; inspect heartbeat and message timestamps. Current configured send delay was 5 seconds.
- TextBee's free plan screenshot showed 50 daily / 300 monthly usage limits; verify current plan before relying on those values. Unused quota was available during this incident; upgrading was not needed.

### Verified API and message behavior

- POST `https://api.textbee.dev/api/v1/gateway/send-sms`, JSON body with `deviceId`, `recipients: ["+639XXXXXXXXX"]`, and `message`. Optional `simSubscriptionId` must be numeric if present.
- Headers: `x-api-key`, `Content-Type: application/json`, `Accept: application/json`, and **`User-Agent: ELECOM-Backend/1.0`**.
- Python urllib's default User-Agent produced HTTP 403. A read-only `/gateway/stats` comparison using the same key returned 403 with the default identity and 200 with the explicit ELECOM identity. Preserve the explicit User-Agent; do not diagnose every 403 as an invalid key.
- Philippine recipient normalization: `09XXXXXXXXX`, `9XXXXXXXXX`, or `639XXXXXXXXX` becomes `+639XXXXXXXXX`. A website test using `639...` without `+` failed; local `09...` and `+639...` worked. Keep the plus sign.
- **Current successful OTP text:** `ELECOM code: {otp}. Valid for {expiry_minutes} minutes. Do not share.` Keep the code and actual expiry in the message; preserve leading zeroes in OTP strings.
- The previous `Your ELECOM OTP is: ... Valid for ... Do not share this code.` repeatedly failed to appear on the target phone even when TextBee marked it delivered. A user-authorized API test (`ELECOM test code: 123456. This is a delivery test.`) arrived. After shortening the real OTP message and deploying it, the user confirmed **it works**.
- Content-dependent delivery/filtering is plausible, but the exact carrier/handset cause was **not proven**. Do not claim a specific spam filter or carrier rule was established. Preserve the working wording unless a controlled test justifies a change.
- Manual success alone does not establish the API failure's cause. Compare the same recipient, sender SIM, exact message text, and actual inbox receipt; a short generic manual test differs from an OTP.

### Status interpretation and diagnostics

- Require JSON `data.success == true` and a non-empty `data.smsBatchId` before accepting the queue request. No automatic SMS resend/fallback: it can create duplicates and invalidate older codes.
- API acceptance means **queued**, not received. `dispatched` means pushed toward the gateway, not an Android send attempt. `sent` means carrier acceptance; `delivered` is the provider's carrier delivery report, not proof the user saw the message. The incident included delivered reports without visible inbox messages.
- Read-only endpoints: `GET /gateway/stats`, `/gateway/devices/{deviceId}`, `/gateway/messages`, and `/gateway/devices/{deviceId}/sms-batch/{smsBatchId}` under the same API base.
- Compare `requestedAt`, `dispatchedAt`, `pushReceivedAt`, `sendAttemptedAt`, `sentAt`, `deliveredAt`, `errorCode`, and gateway `lastHeartbeat`. Convert UTC to Asia/Singapore/Philippine time (UTC+8). Do not invent a delay from screenshots or mix different OTP attempts.
- One authorized test stalled at `dispatched` with no phone acknowledgement and a heartbeat about 17 minutes old; the user subsequently confirmed receipt. This is evidence of intermittent gateway availability, not proof it caused all earlier missing OTPs.
- Logs: `TextBee OTP queued | sim_subscription=default | batch_id=...`; rejection logs include HTTP status. Use `journalctl -u gunicorn --since "5 minutes ago" --no-pager | grep -i textbee` after a fresh request.
- Read-only ADB inbox checks can distinguish Android receipt from Messages display; inspect only metadata or sanitized classification. Never print SMS bodies, OTPs, full recipient numbers, or API credentials into tool output.
- Ask explicit permission before tools send any test SMS; use exactly the authorized recipient/count/content. Read-only status checks do not send messages. Do not silently resend a test because it is still pending.
- Resend generates a new code and supersedes the prior code. Tell the user to use the newest code; delayed older SMS may arrive later.
- Credentials were exposed in screenshots. Never copy their values into source, AGENTS.md, patches, or commits. Rotate exposed keys privately.

### Deployment lessons

- Backend-only changes need deployment and Gunicorn restart; no APK rebuild or database migration is required for this provider/message change. `systemctl is-active` returning `active` proves process health, not delivery.
- Run terminal commands **one at a time**. Pasted commands repeatedly merged with shell prompts. In nano, `*` means unsaved: Ctrl+O, Enter, Ctrl+X.
- After backend changes are committed and pushed, run on the server:

```bash
cd /var/www/elecom
git pull origin main
sudo systemctl restart gunicorn
sudo systemctl is-active gunicorn
```

- A local patch is not automatically on the server. Upload with `scp` from Windows, then `git apply --check` and `git apply` on the server. Apply a patch **once**. If the committed Git pull already contains it, skip patch application. Reapplying a successful patch produces `patch does not apply`.
- If a server patch blocks a Git pull, preserve only the changed gateway files with `git stash push -m "TextBee server patch backup" -- backend/core/textbee_sms.py backend/core/test_textbee_sms.py`, then pull. Do not restore the stash over equivalent committed fixes or discard unrelated work. `.env` is untouched by that scoped stash.
- After SSH disconnects, a prompt such as `F:\elecom_web>` is Windows, not the server. Reconnect before running Linux deployment commands.
- Confirm deployed wording with `grep -n 'ELECOM code:' /var/www/elecom/backend/core/textbee_sms.py`, then request one fresh OTP and verify actual target-phone receipt.

### Validation and references

- Focused tests: from `F:\elecom_web\backend`, run `.\venv\Scripts\python.exe -m unittest core.test_textbee_sms`. Six tests passed during this work, including explicit/default SIM payload, normalization, ASCII single-segment message, queue confirmation, config errors, and no retry on failure. Check current test count/output; this is a historical snapshot.
- Local `manage.py check` was blocked by missing `numpy` imported by the face service, not a TextBee test failure. Do not report full Django checks as passed.
- Setup document: `F:\elecom_web\docs\textbee-otp.md`.
- Official API: https://textbee.dev/docs/sending-sms/sending-sms
- SIM IDs: https://textbee.dev/docs/sending-sms/choosing-a-sim
- Delivery states: https://textbee.dev/docs/sending-sms/delivery-status

## Building a release APK

### App identity
- **Application ID**: `com.elecom.mobile`
- **Namespace**: `com.elecom.mobile`
- **MainActivity**: `android/app/src/main/kotlin/com/elecom/mobile/MainActivity.kt`

### Signing
- The APK is signed with the **Android debug keystore** to match the existing Mediafire distribution.
- Keystore path (local machine): `C:\Users\Redjan Phil\.android\debug.keystore`
- Config: `android/key.properties` (not committed — gitignored)
  ```properties
  storePassword=android
  keyPassword=android
  keyAlias=androiddebugkey
  storeFile=C:\\Users\\Redjan Phil\\.android\\debug.keystore
  ```
- `android/app/build.gradle.kts` loads `key.properties` and applies it to the release build type.
- **Do not switch to a new release keystore** unless intentionally re-distributing — changing the signing key breaks updates for existing installs and triggers Google Play Protect "unknown developer" warnings.

### Version bumping
Use the helper script `bump_and_build.ps1` at the repo root:
```powershell
.\bump_and_build.ps1           # bump build number only, then build
.\bump_and_build.ps1 -patch    # bump patch version (1.0.0 -> 1.0.1)
.\bump_and_build.ps1 -minor    # bump minor version (1.0.0 -> 1.1.0)
.\bump_and_build.ps1 -major    # bump major version (1.0.0 -> 2.0.0)
.\bump_and_build.ps1 -nobuild  # bump version only, skip flutter build
```
The build number (`+N` in `pubspec.yaml`) always increments on every run — Android uses this as `versionCode` to detect updates.

### Output
```
build\app\outputs\flutter-apk\app-release.apk
```

### Google Play Protect warning
Sideloaded APKs (distributed outside the Play Store) will show a Play Protect warning on first install. This is normal and unavoidable for sideloaded apps. Users tap **"Install anyway"** to proceed. Using the same debug keystore as previous releases minimizes this — devices that already have the app won't see the "unknown developer" warning on updates.

## Running the app (local)

- **Install deps**: `flutter pub get`
- **Run**: `flutter run`
- **Optional**: `flutter run --dart-define=API_BASE_URL=http://<host>:8000`

## Quality gates (before handing back)

- **Analyze**: `flutter analyze`
- **Format**: `dart format .`
- **Tests**: `flutter test` (when tests exist/are relevant to the change)

## Engineering conventions (for changes in this repo)

- **Prefer feature-first placement**: UI/state for a feature goes under `lib/features/<feature>/...`. Shared utilities go in `lib/core/...`.
- **Avoid mixing state management styles** within one flow; follow existing patterns in the closest feature/module.
- **Networking**: keep API base URL decisions centralized in `ApiConfig`; do not hardcode new base URLs in random services/widgets.
- **Keep diffs tight**: avoid drive-by refactors unless necessary to complete the task.

## Git hygiene (important)

Do **not** commit build outputs or IDE caches. These paths should remain untracked/ignored:

- `.dart_tool/`
- `build/`
- `android/.gradle/` (and similar Gradle caches)
- Platform build folders under `android/app/` (`debug`, `profile`, `release`)
- `android/key.properties` (contains signing passwords)
- `android/app/*.jks` and `android/app/*.keystore`

If they show up as untracked changes, they should be removed from git tracking (if accidentally added) and kept ignored.

## When things break

- Start from the actual error output (compile/runtime/logcat / Django traceback) and fix the *root cause*.
- For **API** issues, confirm **which host** the device hits (`ApiConfig`) and **which repo** owns the route (Flutter vs `elecom_web/backend`).
- For **SMS OTP** issues, always check the **server's** `.env` (not local) and gunicorn logs (`journalctl -u gunicorn -n 100 --no-pager`).
- Prefer deterministic reproduction (minimal steps) and add/adjust tests where feasible.

## EleVote Live Chat — Architecture & Lessons Learned

### How the chat works (mobile ↔ backend ↔ web admin)

- **Table**: `elevote_chat_messages` — columns: `id (BIGSERIAL)`, `student_id`, `role` (`user` / `assistant` / `admin`), `content`, `model`, `created_at`
- **Table**: `elevote_chat_takeover` — columns: `student_id (PK)`, `active (bool)`, `taken_at`, `taken_by (admin student_id)`
- **Mobile endpoint**: `GET/POST/DELETE /api/mobile/elevote/chat/`
  - `GET ?since_id=<n>` returns only messages with `id > n` (up to 50, oldest-first) + `takeover_active` bool
  - `POST { "message": "..." }` saves user message, calls Groq AI unless admin takeover is active
  - POST response includes `message` (user row with real `id`), `assistant_message` (AI row), `takeover_active`
- **Admin endpoints** (web only): `/api/admin/chat/reply/`, `/api/admin/chat/takeover/`, `/api/admin/chat/thread/?since_id=`

### Polling approach (no WebSocket)

The backend has **no Django Channels / WebSocket infrastructure** — it runs Gunicorn (WSGI). Real-time is achieved via **3-second interval polling** on the mobile:

- `_pollTimer` fires `_poll()` every 3 s
- `_poll()` calls `GET /api/mobile/elevote/chat/?since_id=_lastMessageId`
- Only appends messages with `id > 0 && !existingIds.contains(id)` — **de-duplicates by server id**
- Skips if `_sending == true` (avoids race with optimistic send)
- `_isLive` green dot in appbar fades in for 2 s when a new message arrives

### Optimistic send & de-duplication

- When user sends, an optimistic bubble is added with `id: -1` (sentinel)
- After POST response, the `-1` bubble is **replaced in-place** with the real server message (real id)
- The poll filter `m.id > 0` skips any `-1` bubble, preventing duplicates
- `_lastMessageId` is updated from POST response, not from poll — avoids race conditions

### Admin photo in chat bubbles

- `admin_chat_reply_api` saves the admin's own `student_id` into the `model` field of the message row
- `_elevote_message_json` enriches admin messages with `sender_photo_url` + `sender_name` by joining `users` table on `row.model`
- Fallback for old messages (where `model` is null): queries `elevote_chat_takeover.taken_by` for the same `student_id`
- Mobile `_ChatBubble` renders `Image.network(senderPhotoUrl)` inside `ClipOval` with `support_agent` icon fallback
- Admin name is shown above the bubble (like Messenger group chat sender label)

### ListView blinking fix

- Use `ListView.builder` (not `ListView` with `children:`) — only builds visible items, no full rebuild on setState
- Use `ClampingScrollPhysics()` — prevents bounce/overscroll that triggers layout loops
- Initial load uses `jumpTo` (instant, no animation frame loop); user actions use `animateTo`
- `_onScroll` listener drives `_showScrollDown` bool — shows Messenger-style floating down-arrow FAB when user scrolls up

### Dark mode color palette

- In **dark mode**, use `Color(0xFF60A5FA)` (Tailwind blue-400) instead of `Color(0xFF2563EB)` (blue-600) for all blue UI elements — blue-600 is too dark to read on dark backgrounds
- Section headers ("Candidates", "Omnibus Code", "Election Transparency") use `isDark ? Color(0xFF60A5FA) : Color(0xFF2563EB)`
- Info card stat tiles, arc painters, and bottom nav inactive items follow the same rule

### AppBar icons (Results / Election / Receipt / Me tabs)

- Use plain `Icons.search` and `Icons.notifications_none` at 24px — **no Container wrapper, no circle decoration**
- The circle/pill decoration caused large grey blobs in the appbar on non-home tabs
- Padding: search icon `EdgeInsets.fromLTRB(8, 8, 4, 8)`, bell icon `EdgeInsets.fromLTRB(4, 8, 8, 8)` — keeps them visually close together
- Notification badge: red circle at `right: -2, top: -2`, size 16, font 9px w900

### Deploy sequence (production server)

After changing `F:\elecom_web\backend\core\views.py` or any backend file:
```bash
cd /var/www/elecom
git pull origin main
sudo systemctl restart gunicorn
sudo systemctl status gunicorn --no-pager | tail -5
```

After changing Flutter mobile code, rebuild APK:
```powershell
.\bump_and_build.ps1
```

## Face Verification — Local InsightFace (No Face++ API)

### Why
Face++ free plan has daily quota limits and `CONCURRENCY_LIMIT_EXCEEDED` errors under load.
The system now uses **InsightFace (ArcFace)** running entirely on the server — no external API, no cost, no rate limits.

### How it works
- **Enrollment**: captures a selfie → InsightFace computes a 512-d ArcFace embedding → stored as JSON in `FaceEnrollment.face_encoding`
- **Duplicate check**: on every enrollment, the new embedding is compared (cosine similarity ≥ 0.40) against all other active enrollments — blocks same-face registration under two accounts
- **Verification before voting**: live selfie embedding compared against stored enrollment embedding — must score ≥ 0.40 to pass
- Face++ is kept as a last-resort fallback only if both insightface and face_recognition are unavailable

### Key files
- `backend/core/local_face_service.py` — all face encoding/comparison logic
- `backend/core/views.py` — `_save_face_enrollment_facepp()` and `_face_verification_vote_handler()` call `local_face_service` first
- `elecom_voting/migrations/0016_face_enrollment_local_encoding.py` — adds `face_encoding` TextField to `FaceEnrollment` model

### Fresh server setup (run once)
```bash
# 1. System library required by OpenCV (insightface dependency)
apt-get install -y libgl1

# 2. Install Python packages (insightface, onnxruntime, opencv-python are in requirements.txt)
/var/www/elecom/venv/bin/pip install -r /var/www/elecom/backend/requirements.txt

# 3. Run migrations (creates face_encoding column)
/var/www/elecom/venv/bin/python /var/www/elecom/backend/manage.py migrate

# 4. Restart gunicorn
sudo systemctl restart gunicorn
```

### Troubleshooting
- `ImportError: libGL.so.1` → run `apt-get install -y libgl1` then restart gunicorn
- `InsightFace initialisation failed` → check gunicorn logs: `journalctl -u gunicorn -n 30 --no-pager | grep -i insightface`
- First enrollment after deploy takes a few extra seconds — InsightFace downloads `buffalo_sc` model weights (~30MB) on first use and caches them in `~/.insightface/models/`
- Legacy enrollments (before this migration) auto-backfill their `face_encoding` on first verification attempt by downloading the Cloudinary photo and re-encoding it

## Calendar of Activities — Automatic Updates

- Implemented in `lib/features/elecom/student_dashboard/student_dashboard.dart`. Fetches `/api/mobile/calendar-events/` every **3 seconds**, following the chat polling approach; this is polling, not a WebSocket connection.
- Poll only while the app is resumed, the dashboard route is visible, and Home is the selected tab. Refresh immediately when returning to the visible Home route or resuming the app.
- `_loadingCalendarEvents` prevents overlapping requests. Compare the new event list with the previous list before calling `setState`; retain the last successful list on failures and retry on the next poll.
- Fetch the full list so additions, edits, and deletions are reflected. Preserve the calendar widget's selected month, expansion state, and scroll position during updates.
- Cancel `_calendarPollTimer` and unregister `WidgetsBindingObserver` in `dispose`.
- The backend admin and mobile calendar endpoints read the same `election_calendar_events` table. No backend change was needed for automatic mobile updates.

## Candidate Filing — Follow-up Documents and Rejection Rules

### COC administration

- Web page: `F:\elecom_web\frontend\org_elecom\elecom_admin\elecom_certificate_of_candidacy.html`; its link follows Candidate Files in all admin sidebars.
- `candidate_certificate_settings` stores per-election USG/department academic year and chairperson settings. `candidate_certificate_issuances` stores the approved PDF, frozen settings, and initial approval timestamp. Migration `elecom_auth.0009` creates both tables; install `pypdf` and `reportlab` from the backend requirements.
- Initial approval dates the COC in Philippine time and saves the issued edition while retaining the original archive. Final approval and later settings changes must not modify the issued PDF. Do not infer older initial approval dates from `reviewed_at`, which may have been overwritten by final review.
- Mobile previews load settings from `/api/mobile/certificate-of-candidacy/settings/`; filed certificate views download the server edition to avoid displaying an outdated local copy. Deployment steps: `docs/coc-admin-settings.md`.
- Chairperson signatures are drawn/uploaded once on COC Management and saved for both forms in `candidate_certificate_settings.chairperson_signature_bytes` (migration `elecom_auth.0010`). Admin placement previews may show the signature, but initial candidate COCs must not contain it. Final approval saves an immutable additional PDF in `candidate_certificate_finalizations`; certificate downloads select it only for status `approved`. Original and initial editions remain unchanged. Do not expose reusable signature bytes through mobile settings responses.

### Shared COC management and templates

- The web screen heading is **Certificate of Candidacy Management**; the sidebar label stays **Certificate of Candidacy**. COC chairperson labels and current templates use **ELECOM**, replacing COMELEC. Keep historical legal references outside this feature unchanged unless requested.
- Academic year and chairperson settings are shared by USG and department forms. Editing either card mirrors the other, and **Save for both forms** saves both rows. The canonical settings lookup prefers the USG row, with the department row as fallback.
- Academic year uses a start-year slider; end year is automatically start + 1. Admin live previews update after a short debounce without saving settings. Explicit save applies changes to future issuances. Abort stale preview requests and revoke replaced PDF blob URLs.
- The sworn date comes from **initial filing approval**, in Philippine time, rather than submission or final approval. The sworn location is **USTP Oroquieta Campus**. Final approval adds the chairperson signature without changing the initial date.
- Admin settings/template endpoints: `/api/admin/certificate-of-candidacy/settings/` and `/api/admin/certificate-of-candidacy/template/<usg|department>/`. Draft previews with signatures use CSRF-protected POST bodies; do not put reusable signature data in query strings.
- The shared chairperson signature can be drawn or uploaded as PNG. Backend normalization removes white background, crops visible ink, and rejects blank/invalid/oversized images. Final approval requires a saved signature belonging to the chairperson frozen on the initial COC. Changing the name must not silently sign an earlier edition with someone else's signature.
- Main backend modules: `F:\elecom_web\backend\core\candidate_certificates.py` (original archive/download), `coc_management.py` (settings, templates, initial issuance), and `coc_chairperson_signatures.py` (signature normalization and final edition).
- Mobile source templates are `assets/forms/certificate_of_candidacy.pdf` and `.png` (USG, 612 x 1008 points), and `assets/forms/department_certificate_of_candidacy.pdf` and `.png` (department, 612 x 792 points). Backend PDF copies are under `F:\elecom_web\backend\core\forms\`. Update PDF and rendered PNG together, plus the matching backend PDF. Flutter uses the PNG background; admin previews use the PDF.
- The department template is selected for SITE, PAFE, and AFPROTECHS. The backend also accepts the historical AFPRO alias. Check existing organization mappings before extending this list.
- Inspect replacement PDFs for filled sample names, IDs, personal details, signatures, layout changes, and branding before installing them. The USG PDF supplied on 2026-10-09 contained sample candidate details and still said COMELEC; the user explicitly chose to update the existing blank USG form to ELECOM instead. Do not install that filled sample as a reusable template.
- PDF field positions are fixed coordinates in `candidate_certificate.dart`; backend year/date/name and chairperson signature overlays have their own coordinates. Check both form sizes after a template change. Never overwrite previously archived original, initial, or final editions just to apply a new format.
- Initial admin filing review and Candidate Files expose the candidate's COC through the protected certificate endpoint. COC archives are read-only in Candidate Files. Mobile filed COCs load the authoritative server edition, not an older local original.

### Mobile filing fields, theme, PDF download, and printing

- Memberships start with one optional row. Add further rows only when requested, up to the three rows available on the COC. No membership is required. Club/organization choices use spelled-out names with **Others** for manual entry. Membership positions use organization-specific choices with **Others**; membership years use a start/end `RangeSlider`.
- Curriculum program is selected from the campus program dropdown rather than manually typed. Current choices cover BSIT, BTLED, and BFPT; verify against the handbook before changing the list. Program and year/section account restrictions remain in place.
- Profile email and phone prefill the candidate contact fields but remain editable. Preserve candidate corrections when a delayed profile refresh returns.
- `lib/features/elecom/candidates/candidate_filing_theme.dart` provides `candidateFilingTheme` and `CandidateFilingStyle`. Use dashboard blue `0xFF2563EB` in light mode and `0xFF60A5FA` in dark mode, inherited app typography, and consistent app bar titles. Do not reintroduce brown controls.
- A `Theme` inside the filing form does not automatically style callbacks using the State's outer context or separately pushed routes. Apply filing style explicitly to the membership sheet, date picker, signature screen, and certificate/print routes. Preserve a white signature canvas with black ink even in dark mode.
- `printing`'s toolbar reads `ThemeData.primaryColor` and `primaryIconTheme`, not only `colorScheme.primary`. Set both in the filing theme to keep the toolbar blue with readable icons.
- `candidate_certificate_preview_screen.dart` owns certificate display, downloading, loading/retry UI, and print navigation. Set `PdfPreview.canDebug: false`: the unwanted bottom switch was the package's debug switch.
- Download uses the existing **file_picker 13.x static API**: `FilePicker.saveFile(fileName: ..., bytes: ..., mimeType: 'application/pdf')`. It opens the native save dialog and writes the actual displayed PDF to the selected location. Cancel is not a failure. Avoid old `FilePicker.platform` examples or app-private storage presented as a user download.
- `candidateCertificateFileName` produces names such as `SITE_Certificate_of_Candidacy_Von_Joshua_Peje.pdf`, including organization and full candidate name. It removes unsafe path characters and normalizes whitespace. Print and share use the same filename. For filed applications, use the application record's candidate name and organization.
- The print action opens an in-app **Print Certificate** preview with an explicit back arrow and **Open device print options** button. Printing uses the same PDF bytes with `Printing.layoutPdf(..., dynamicLayout: false)`. Android owns its printer dialog: return using the device's Back or Cancel control. Do not promise an app-managed back arrow inside that native dialog.

### Filing and certificate loading

- `_hydrateProfileAndStatus` starts filing status and profile requests in parallel; status must not wait for the profile response. Preserve edits to name and contact fields made while the profile refresh is pending.
- Profile, filing status, and certificate settings requests in this flow have 15-second waits; server PDF downloads have a 20-second wait. These limit UI waiting and do not guarantee network speed. Keep server-side duplicate/rejection enforcement intact.
- Opening **View / Save Certificate** pushes the certificate route immediately, before awaiting PDF generation/download. Its app bar Back button remains usable during loading, and failures show **Try again**. Ignore async completions after disposal.
- `buildCandidateCertificate` loads the PNG asset on the main isolate, then calls `compute` with fields/photo/signature/template bytes. `_buildCandidateCertificate` builds/compresses the PDF on a worker isolate. Keep `rootBundle` and UI context out of that worker.
- Certificate and print previews render at 96 DPI to reduce rasterization work on the RMX3261. Printing, sharing, and downloading still use the original PDF bytes; changing preview DPI does not change the saved PDF.
- Application status continues to poll every 3 seconds only while resumed and the filing route is visible, with an in-flight guard. Preserve the authoritative server-edition rule when optimizing preview loading; an approved signed edition must not be replaced with a cached pre-approval copy.

### Repair after manually deleted database tables

- `DROP TABLE ... CASCADE` can remove the application table and its COC foreign-key constraints while leaving orphaned COC rows. Prefer deliberate test-record cleanup to dropping tables. Normal `migrate` does not recreate deleted tables when their migrations are already recorded as applied.
- `F:\elecom_web\backend\core\candidate_filing_schema.py` provides `ensure_candidate_filing_schema`. COC settings/template endpoints and `ensure_certificate_table` check and repair the five filing/COC tables: `candidate_applications`, `candidate_application_certificates`, `candidate_certificate_settings`, `candidate_certificate_issuances`, and `candidate_certificate_finalizations`.
- The repair uses an atomic transaction and PostgreSQL advisory lock, creates missing tables/indexes and the chairperson signature column, and restores missing COC foreign keys. It avoids repeated DDL when the expected tables, signature column, and references already exist.
- Restored foreign keys use `NOT VALID` to retain old orphaned archives for backup recovery while checking future writes. Do not silently delete those archives. The application sequence advances beyond all surviving archive IDs so a new application cannot inherit a deleted candidate's PDF; never lower an existing sequence.
- Recovery restores schema, not deleted records, PDFs, signatures, or settings. Recover deleted data from a backup. If settings were deleted, re-enter the year, chairperson, and signature in COC Management and save for both forms. The repair is scoped to these five tables; inspect logs if other deleted tables still cause errors.
- Management command: `backend/elecom_auth/management/commands/repair_candidate_filing_schema.py`. It skips unrelated Django system checks so face-service dependencies do not prevent this repair. Instructions: `docs/candidate-filing-table-recovery.md`.
- After committing/pushing the backend changes, run on the server:

```bash
cd /var/www/elecom
git pull origin main
/var/www/elecom/venv/bin/python backend/manage.py repair_candidate_filing_schema
/var/www/elecom/venv/bin/python backend/manage.py migrate
/var/www/elecom/venv/bin/python backend/manage.py collectstatic --noinput
sudo systemctl restart gunicorn
sudo systemctl is-active gunicorn
```

- Run commands on separate lines; screenshots showed pasted commands merged with prompts and missing visible status output. Expect `active` from `is-active`, then refresh COC Management with Ctrl + Shift + R and retry mobile filing.
- An HTML `<!DOCTYPE ...>` response causes the web's JSON parsing error, but is not the underlying database diagnosis. The COC script now reports a readable server error for non-JSON settings responses. Reproduce the failure, then inspect `journalctl -u gunicorn --since "5 minutes ago" --no-pager`.
- A warning that `elecom_voting` models have unapplied changes is separate from successful COC schema repair. Investigate the model/migration difference locally instead of blindly generating migrations on production.
- Backend recovery needs deployment/restart, not an APK rebuild. Mobile code or bundled form changes require a rebuilt and installed APK. Pulling mobile source alone does not update an installed app.

### COC verification and resource limits (2026-10-09)

- Latest focused mobile verification: 16 tests passed across certificate loading/back/retry, filenames, PDF generation/signature drawing, and API archival/download/settings. Changed certificate/filing files analyzed cleanly. This is a verification snapshot, not a claim that the production device or all app tests were checked.
- Focused Flutter command:

```powershell
flutter test --no-pub --concurrency=1 test/candidate_certificate_preview_loading_test.dart test/candidate_certificate_filename_test.dart test/candidate_certificate_test.dart test/candidate_certificate_storage_test.dart
```

- Backend recovery verification: 45 tests passed including `core.test_candidate_filing_schema`, `core.test_coc_management`, `core.test_coc_chairperson_signatures`, `core.test_candidate_certificates`, and `core.test_candidate_application_policy`. The recovery tests mock PostgreSQL cursor behavior; they do not replace live database verification. The user later reported the server's successful **Filing/COC schema repaired** output.
- Run those backend tests from `F:\elecom_web\backend` using its venv Python and `-m unittest`. No new migration was necessary for the recovery command or ELECOM template update; settings and signature migrations remain 0009 and 0010.
- This machine can run out of memory when Flutter analysis and PDF tests overlap. Do not start duplicate analyzers because the first is quiet. Wait for completion and run verification sequentially; `--concurrency=1` reduces test-process overlap. A run hit OOM, but later focused tests including PDF generation passed.
- If verification processes must be stopped, identify the exact process trees launched by the current task. Do not terminate the user's IDE Dart language server, devtools, or unrelated app sessions. Avoid restarting a slow build or analysis without evidence it is stuck.

### Filing stages

- Initial filing: `pending`. Initial approval changes it to `requirements_pending`; the candidate is not yet published.
- Follow-up submission: Certificate of Enrollment, grades for the last two consecutive semesters, and Good Moral Certificate. Once all three PDFs are saved, the status becomes `requirements_review` and `requirements_submitted_at` is recorded. The 2x2 photo is already included in the initial COC; no duplicate photo upload is required.
- Final approval publishes the candidate and changes the status to `approved`.
- Both rejection stages use `rejected`, but their refiling rules differ:
  - **Initial filing rejected:** corrections and **File Again** are allowed.
  - **Follow-up documents rejected:** no new filing is allowed for that election, including a different position. Show **Requirements Rejected**, retain the reason, and hide **File Again**.
- Do not treat every `rejected` application as eligible to refile. A non-empty `requirements_submitted_at` or any of the four saved requirement URLs identifies the follow-up stage, including older records.

### Enforcement and files

- Mobile rule: `lib/features/elecom/data/candidate_application_policy.dart`, function `canFileCandidateApplicationAgain`. Also honors a server `can_file_again: false` restriction. Used by `candidate_filing_screen.dart` for the button, callback guard, and rejection message.
- Backend: `F:\elecom_web\backend\core\views.py`, helper `_candidate_application_can_file_again`. `_candidate_application_json` exposes the `can_file_again` boolean.
- `candidate_application_submit_api` must fetch the requirement metadata for the student's existing filing in the current election and return **409**, code `requirements_rejected`, after a follow-up rejection. Hiding a button alone is insufficient.
- No database migration is needed for this rule; the timestamp and requirement URL columns already exist. Do not delete the rejected filing or its documents to enable another filing.

### Upload failures: 413 and SQL errors

- Mobile `submitCandidateRequirements` sends the three PDFs in **one multipart POST** to `/api/mobile/candidate-applications/requirements/`. Older clients may still send a separate photo, which remains accepted for compatibility.
- Each file must be non-empty and at most **8 MiB**. The combined request can approach **24 MiB**, plus multipart overhead (32 MiB for older clients). The app validates sizes before sending; Django retains per-file validation.
- An HTML **413** response means an upload-size rejection, not invalid document JSON. Preserve the specific upload error and backend validation errors; do not relabel response-decoding errors as network failures.
- Nginx configuration is separate from the Git repository. In `/etc/nginx/sites-available/elecom`, set `client_max_body_size 40m;` inside the **HTTPS server block with `listen 443 ssl`**. Putting it only in the port 80 redirect block does not affect HTTPS uploads. Check for smaller location-level overrides.
- Validate and apply with `sudo nginx -t && sudo systemctl reload nginx`. Full steps are in `docs/candidate-requirements-server-fix.md`.
- The requirements SELECT in `candidate_application_requirements_api` must include `FROM candidate_applications`. A prior missing FROM caused `column "id" does not exist`, even though the table had an `id` column. Inspect the query and running code before altering the schema.
- `git pull` does not reload Gunicorn workers. After pushing and pulling backend fixes, run `sudo systemctl restart gunicorn`.
- Use absolute paths in diagnostic commands to avoid confusion when already inside `backend`:

```bash
grep -n -A 5 'SELECT id, status, requirements_photo_url' /var/www/elecom/backend/core/views.py
sudo journalctl -u gunicorn --since "2 minutes ago" --no-pager
```

Reproduce the submission before inspecting logs. Successful GET polling entries alone do not prove a requirements POST succeeded. SQL displayed by `grep` is code to inspect, not a shell command to execute.

### Focused regression checks

```powershell
flutter test test/candidate_requirements_upload_test.dart test/candidate_application_policy_test.dart
python F:/elecom_web/backend/core/test_candidate_application_policy.py
```

The backend tests extract the relevant view functions to test policy and the submit guard without importing unrelated face-service dependencies. They do not replace a full Django system check or live upload verification.

## Windows Release Builds — Disk Space and Gradle Cache Recovery

- Check free space on **both C: and F:**. Even with outputs on F:, Gradle normally uses `C:\Users\Redjan Phil\.gradle` and Windows temporary storage on C:. An APK build previously failed at `mergeReleaseNativeLibs` / `ExtractJniTransform` with **There is not enough space on the disk**.
- A working alternative is the ignored workspace cache at `F:\elecom_mobile\.dart_tool\gradle-user-home` and temporary directory at `.dart_tool\build-temp`. These are disposable build artifacts; never commit them.
- For a new alternate cache, copy only the original `.gradle\caches\modules-2` dependency cache and `.gradle\wrapper` distributions if needed. Avoid copying interrupted generated caches such as version-specific caches or `jars-9`; an incomplete generated Gradle API jar caused missing `Settings` / `pluginManagement` errors despite unchanged build scripts.
- If that cache error occurs, stop the failed build and regenerate only the affected temporary generated cache. Before recursive cleanup, verify resolved absolute paths are inside the intended cache directory. Do not delete source files, signing files, or personal files.
- Set these variables **only for the build session**, creating the directories first:

```powershell
$env:GRADLE_USER_HOME = 'F:\elecom_mobile\.dart_tool\gradle-user-home'
$env:TEMP = 'F:\elecom_mobile\.dart_tool\build-temp'
$env:TMP = $env:TEMP
$env:JAVA_TOOL_OPTIONS = ($env:JAVA_TOOL_OPTIONS + ' -Djava.io.tmpdir=F:/elecom_mobile/.dart_tool/build-temp').Trim()
flutter build apk --release --no-pub
```

- Use `--no-pub` only when dependencies are already resolved. On retry, keep the version already bumped; do not repeatedly run the bump script for failed attempts.
- If PowerShell blocks `bump_and_build.ps1`, use `powershell -NoProfile -ExecutionPolicy Bypass -File .\bump_and_build.ps1` for that process rather than changing the machine's execution policy.
- The bump script can print **Build failed** while returning process exit code 0. Inspect Flutter/Gradle's final output, and verify `build/app/outputs/apk/release/output-metadata.json` for the expected `versionCode`; do not mistake an older APK for a successful new build.
- Cache regeneration and release builds were slow on this machine. Preserve completed caches and wait for the actual build result rather than repeatedly restarting an active build.

### Verification snapshot (2026-10-07)

- Release `1.0.0+7` built successfully and includes the follow-up rejection restriction. Check `pubspec.yaml` for the current version rather than treating this snapshot as the latest release forever.
- Nine targeted Flutter tests and four backend policy tests passed; the changed filing screen and policy analyzed cleanly.
- Full-app analysis had 42 existing warnings/lint findings, and the existing login widget test expected missing text `WELCOME`. Investigate current output before attributing these to a new change.
- Local `manage.py check` was blocked by missing `numpy` from the face-service import. Backend syntax and isolated policy tests passed; full Django checks still require the appropriate backend environment and dependencies.

## Developer Options ? User Gallery (2026-10-10)

- Admin Developer Options lives in `frontend/org_elecom/elecom_admin/elecom_reset.html`. The User Gallery panel loads `admin_components/admin_js/developer_gallery.js`; its styles share `elecom_reset.css`. Bump referenced asset versions after changes.
- GET `/api/admin/developer/gallery/` is implemented in `backend/core/developer_gallery.py` and registered in `core/urls.py`. It uses `_developer_admin`: existing admin authentication plus the 15-minute developer-password gate. Never expose this endpoint through mobile or remove that gate.
- Gallery groups retained profile photos, face enrollments, candidate filing/follow-up photos, registered candidate photos, and party logo uploads by account name/student ID. Search is parameterized, users are alphabetically ordered, and pages contain 20 users. Refresh fetches current records; thumbnails load lazily and open a full-size Bootstrap modal.
- Sources are a fixed table/column allowlist. Schema introspection skips optional tables/columns without creating or repairing them. URLs accept HTTP(S) only; data is rendered via textContent and private/no-store API responses. Never return embeddings, reusable chairperson signatures, OTPs, or credentials.
- This is a gallery of retained database image references, not a Cloudinary-wide asset crawler or a new upload archive. Overwritten profile/enrollment images and unsaved verification frames cannot be reconstructed. FaceVerificationLog retains match metadata, not a camera image URL. Do not claim the gallery contains every historical capture.
- Focused checks: `python -m unittest core.test_developer_gallery core.test_developer_options` (19 passing tests during implementation) and `node --check` for the two developer scripts. Tests mock the DB; production image rendering/live PostgreSQL still need deployment verification.
- Deploy web/backend changes, run collectstatic, restart Gunicorn, and refresh browser assets. No APK or migration is needed. Setup: `docs/developer-user-gallery.md` in the web repository.

### Optional production deployment after git pull

- User preference: after one-time setup, use only `git pull origin main` for normal web/backend updates.
- `deploy/enable-pull-deploy.sh` installs the repo-local `core.hooksPath=deploy/hooks` on /var/www/elecom only. It refuses to replace an existing custom hooks path or post-merge hook.
- `deploy/hooks/post-merge` collects static files, restarts Gunicorn, and checks service health after a successful merge. Deployment failures are printed; the source merge may already have completed. Do not claim success merely because Git pulled.
- Setup is not active on the user's server until the scripts are deployed and `sh deploy/enable-pull-deploy.sh` runs there once. Hooks do not run on an already-up-to-date pull. Environment edits, migrations, and local-change conflicts still need their appropriate separate handling. See docs/pull-auto-deploy.md.

## Recent mobile UI and turnout decisions (2026-11-01)

- Mobile turnout must be scoped to the current election. Archived and legacy unscoped votes must not inflate a new election's turnout. The reported mismatch was mobile 31/1,643 (1.9%) versus current-election admin 0/1,643 (0.0%). Backend ownership: `G:\elecom_web\backend\core\views.py`, `election_window_api`; regression coverage: `core.test_mobile_turnout`. Do not reset historical votes to fix a display query.
- Shared geometry is in `lib/core/theme/app_shape.dart`: cards/dialogs use 8px corners; buttons/text fields use 6px. Apply `.withCompactShapes()` after local theme customization. Keep intentional circular avatars/icons circular.
- Use dashboard blue `0xFF2563EB` in light mode and `0xFF60A5FA` in dark mode. The user explicitly rejects brown/rose controls and dialog tints for these screens.
- `account_sessions_screen.dart` applies a local theme to its device cards, buttons, and separately built confirmation dialogs: blue accents, white light surfaces, slate `0xFF1E293B` dark surfaces, transparent surface tint. A local Theme around Scaffold does not automatically reach a showDialog builder using the State's outer context; explicitly theme that dialog too.
- The Home **Already a candidate** AlertDialog in `student_dashboard.dart` explicitly uses white background, transparent surface tint, dark title/body text (`0xFF0F172A` / `0xFF334155`), and blue OK text. This was an explicit user request; do not restore the inherited brown/rose dialog tint.

### EleVote floating assistant behavior

- Implemented on the dashboard Home overlay in `student_dashboard.dart`; visible in Light, Dark, System default, and Premium appearances. Do not gate the assistant on Premium mode. Visibility still respects the user's assistant-enabled preference.
- Users can drag freely while touching; releasing snaps horizontally back to the original right side over 250ms while retaining the chosen vertical position. Keep bounds clear of system/app navigation. Do not leave it floating in the center or permanently move it to the opposite side.
- The close control has a small 18px visual within a 32px tap target and sits 20px above the mascot. Keep its subtle appearance and usable touch area.
- `lib/core/session/elevote_preferences.dart` separates the persistent enabled setting from temporary dismissal. X hides it in memory for the current foreground session; switching tabs must not restore it. Backgrounding (paused/hidden) then resuming restores it, as does a fresh process. Do not save temporary dismissal to SharedPreferences or reset a permanent disabled preference.

## Password changes and logged-in devices (2026-11-01)

- Settings -> **Where you're logged in** opens `lib/features/elecom/profile/account_sessions_screen.dart`. Lists device label, current-device marker, network IP, sign-in time, and last-active time; supports confirmed logout of one device or all devices. IP is not an exact location. Older sessions may lack sign-in metadata; show it as unavailable rather than inventing a time.
- Changing or resetting a password revokes all account sessions, including the caller. The password-change screen emits `ApiClient.endSession` after success and does not try to submit a notification using its revoked session. Backend saves the account notification.
- `lib/core/session/session_guard.dart`, installed in `lib/app/app.dart` with `sessionNavigatorKey`, masks private UI and removes all prior routes on expiry. It checks every 30 seconds while foregrounded and on resume. Network errors/404/5xx do not imply logout. Other devices are blocked on their next authenticated server request; an offline app cannot receive immediate UI logout.
- `SessionPersistence.clear()` clears in-memory identity/cookies first, then best-effort saved state/push cleanup. Restore requires a nonempty sessionid, not just a CSRF cookie. Normal profile logout also attempts server logout before local cleanup.
- `SessionHttpClient` attaches cookies, CSRF, same-origin Referer, and device metadata only to the configured API origin. Third-party upload hosts must never receive or replace ELECOM cookies. Emit expiry for authenticated mobile API 401 responses, excluding auth endpoints; bad credentials must not end an existing valid session. Ignore cookie/expiry results from a late request belonging to an older login.
- Android device label comes from `MainActivity.kt` MethodChannel `com.elecom.mobile/device_info`, method `deviceName`, using manufacturer/model. No unique hardware identifier or extra permission is required. Device labels are informational, not trusted proof of a device's identity.

### Backend session implementation and deployment

- Source: `G:\elecom_web\backend\core\account_sessions.py`; middleware registered after EnsureSystemTablesMiddleware and before RefreshAdminRole. Uses existing `django_session` rows with DB/cached-DB SessionStore deletion; no migration or new dependency required. Other session engines are not supported by the listing/revocation implementation.
- APIs: GET `/api/mobile/account/session/`, GET `/api/mobile/account/sessions/`, POST `/api/mobile/account/sessions/logout/` with `{session_id: <opaque id>}` or `{all: true}`. Existing `/api/mobile/account/logout/` ends the current session. Device revocation is CSRF-protected, ownership-checked, and private/no-store. GET establishes the CSRF cookie; HTTPS POST requires the same-origin Referer supplied by the client.
- Never return or display bearer session keys. Public session IDs are HMAC-derived opaque identifiers. Session password stamps are HMAC-derived; do not store raw password hashes in session metadata. Login flushes/rotates the old session to avoid fixation and retained privilege flags. Middleware invalidates sessions after the stored password changes; legacy sessions receive a stamp on use.
- Only trust forwarded IP headers when the immediate peer is loopback; otherwise use the direct peer. Device labels and IP are not security credentials.
- `candidate_push.py` binds registered push tokens to sessions. Per-device logout removes its token only if another same-account session does not share it; all-device logout/password change removes all account tokens. Legacy sessions without token binding cannot guarantee per-device push unlinking. Cleanup errors must not prevent session revocation.
- Session enumeration scans active session rows in chunks and filters by account; revisit indexing/storage if scale warrants it. Do not advertise this as constant-time account lookup.
- Guide: `G:\elecom_web\docs\account-sessions.md`. Local implementation does not prove production deployment; check server code and actual behavior. At implementation handoff, backend changes still required deployment. No new migration is needed for this feature.
- Focused backend verification snapshot: `python -m unittest core.test_account_sessions core.test_web_login` (26 passed), plus `python -m unittest core.test_candidate_push` (9 passed). Tests use isolated/mocked storage, not production DB. Full `manage.py check` remained blocked by existing missing numpy in the face service.
- Mobile verification: `flutter test test/session_http_client_test.dart test/account_sessions_screen_test.dart` (8 passed). Targeted session files analyzed cleanly. Full analysis retained existing findings; do not claim the whole repository was lint-clean.

## Public APK download link and release configuration

- The web login **Download the ELECOM app** link is populated from the backend's `APP_UPDATE_APK_URL` (the admin-only login denial returns `apk_url`). Files: `G:\elecom_web\backend\core\settings.py`, `core/views.py`, and `frontend/org_elecom/elecom_components/elecom_js/elecom_login.js`.
- To replace that public link, edit **production** `/var/www/elecom/backend/.env`, set `APP_UPDATE_APK_URL`, and restart Gunicorn. No website source edit, collectstatic, or APK rebuild is required for this configuration-only change. A Git pull does not update .env; even an already-up-to-date pull does not trigger post-merge deployment hooks.
- New public link supplied by the user on 2026-11-01: `https://www.mediafire.com/file/8wu8uoy87hbc2jm/ELECOM.apk/file`. This is a public distribution URL, not a credential. Do not assume the server was updated: instructions were provided, but no server edit was performed in this session.
- `APP_UPDATE_LATEST_VERSION` / `APP_UPDATE_LATEST_BUILD` drive the mobile update prompt. Set them to the actual uploaded APK's versionName/versionCode, not merely the latest local source. Build 27 is `1.0.0+27`; the contents of the MediaFire upload were not independently verified. Preserve `APP_UPDATE_FORCE` unless the user requests a force-policy change.

### Current release/build lessons

- Successful release snapshot: build 25 introduced device sessions, build 26 changed their colors, build 27 made the candidate dialog white. Latest verified local APK in this session: `1.0.0+27`, `build/app/outputs/flutter-apk/app-release.apk`. Always check current pubspec and output metadata rather than treating this historical snapshot as permanently current.
- Limited disk/memory: use `.dart_tool/build-temp` for TEMP/TMP on G:, and run verification sequentially. Do not run duplicate analyzers because the first is quiet. Existing dashboard analysis reported 14 warnings/info notices outside the dialog change.
- Successful low-memory build configuration (session-scoped; preserve the existing signing setup):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\bump_and_build.ps1 -nobuild
New-Item -ItemType Directory -Force .dart_tool\build-temp | Out-Null
$env:TEMP = (Resolve-Path .dart_tool\build-temp).Path
$env:TMP = $env:TEMP
$env:GRADLE_OPTS = '-Djava.net.preferIPv4Stack=true -Dorg.gradle.jvmargs="-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=128m -XX:ActiveProcessorCount=2 -Djava.net.preferIPv4Stack=true -Dfile.encoding=UTF-8" -Dorg.gradle.workers.max=1'
flutter build apk --release --no-pub
```

- Bump once per intended release; retry a failed/interrupted build without bumping again. One Gradle daemon start failed with FileLockContentionHandler / `java.net.BindException: Address already in use`; an IPv4-preferred retry later succeeded. This is a local build issue, not an app/API defect.
- Release builds here took roughly 9-12 minutes and could be quiet for long stretches. Inspect exact task processes/logs before deciding one is stuck; do not kill unrelated Java/Dart/IDE processes. If an exec session disappears after interruption, inspect logs/processes and metadata before reporting completion or restarting.
- Confirm Flutter's success output AND `build/app/outputs/apk/release/output-metadata.json` versionCode. An older app-release.apk can remain after failure. Do not offer that stale file as the new release. Build outputs/logs/caches remain ignored and must not be committed.
