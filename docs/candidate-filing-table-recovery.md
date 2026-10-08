# Recover manually deleted filing tables

Deploy the backend changes from `F:\elecom_web` first, then run on the server:

```bash
cd /var/www/elecom
git pull origin main
/var/www/elecom/venv/bin/python backend/manage.py repair_candidate_filing_schema
/var/www/elecom/venv/bin/python backend/manage.py migrate
/var/www/elecom/venv/bin/python backend/manage.py collectstatic --noinput
sudo systemctl restart gunicorn
sudo systemctl is-active gunicorn
```

The repair command works even when old migrations are already recorded as applied.
It recreates missing application and COC tables, adds the chairperson signature
column if missing, and restores COC foreign keys removed by `DROP ... CASCADE`.
COC settings, previews, and archive access also check this schema automatically.

Deleted application records, settings, signatures, and PDFs cannot be reconstructed
from table definitions. Restore a database backup to recover those records. If
settings were deleted, open COC Management, enter the academic year and ELECOM
chairperson, draw/upload the signature, and save for both forms.

Surviving PDF archives remain untouched. Recovered foreign keys use `NOT VALID`
when restored over surviving orphan rows: new writes are checked, while old
archives remain available for backup recovery. The application sequence advances
past retained archive IDs so a new candidate cannot inherit another filing's PDF.

If another deleted table still causes errors, reproduce the failure and inspect:

```bash
sudo journalctl -u gunicorn --since "5 minutes ago" --no-pager
```

For future test resets, use a deliberate record cleanup instead of dropping tables.
