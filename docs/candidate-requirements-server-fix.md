# Candidate requirements upload deployment

The mobile app submits three PDFs in one multipart request: enrollment,
grades for the last two consecutive semesters, and good moral certificate.
The photo is already in the initial COC. Each file can be up to 8 MiB.
Keep the existing 40 MiB request limit for compatibility with older clients;
Django continues to enforce the 8 MiB per-file limit.

On the production server, inspect the effective configuration:

```sh
sudo nginx -T
```

In `/etc/nginx/sites-available/elecom`, add or update this directive inside
the HTTPS `server` block serving `el3com.duckdns.org`:

```nginx
client_max_body_size 40m;
```

Check that the location handling `/api/mobile/candidate-applications/requirements/`
does not override it with a smaller value. Preserve existing proxy and TLS settings.
Validate and reload:

```sh
sudo nginx -t && sudo systemctl reload nginx
```

Deploy the accompanying `backend/core/views.py` fix from the web repository;
the requirements SELECT query needs `FROM candidate_applications`:

```sh
cd /var/www/elecom
git pull origin main
sudo systemctl restart gunicorn
```

Only pull after the backend fix has been committed and pushed. Install the
updated mobile APK for the size validation and readable upload errors.

Verify with an authenticated candidate whose status is `requirements_pending`:
submit three valid PDFs (including a combined upload over 1 MiB),
confirm HTTP 200, confirm all three PDFs are available to the admin, and confirm
the application moves to `requirements_review`. A file over 8 MiB must be rejected
by the app before upload. A proxy HTTP 413 must show an upload-size message.

Reference: https://nginx.org/en/docs/http/ngx_http_core_module.html#client_max_body_size
