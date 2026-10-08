# Candidate certificate on mobile

The filing screen collects the additional Certificate of Candidacy details and a
handwritten signature. The supplied blank PDF is included in `assets/forms`;
the PNG preserves its layout for PDF generation. USG filings use the supplied
updated USG form on legal-size paper (8.5 x 14 inches). SITE, PAFE and AFPROTECHS
filings use `department_certificate_of_candidacy.pdf` and its PNG on letter-size
paper (8.5 x 11 inches), with separate coordinates for the filled fields. The filled sample is a layout
reference only and is not shipped with the app.

Candidates can preview, print, or save/share their completed certificate before
submission. After a successful filing, an account- and application-specific copy
is retained on this device for the status screen. Clearing app data or using a
different device removes access to that local copy.

The template says **Contact No.**, rather than bank/account number. Membership
positions are distinct from the election position. Up to three membership rows
are supported, matching the form; unused rows may be blank. Age is calculated
from the birth date. Academic year and COMELEC's sworn/chairperson section remain
blank for the appropriate election/official to complete.

## Server archive

This mobile change sends these extra multipart string fields to the existing
`POST /api/mobile/candidate-applications/submit/` endpoint:

- `curriculum_program`, `major`, `gender`, `date_of_birth` (YYYY-MM-DD), `age`
- `contact_number`, `email`, `address`
- `affiliation_0_organization`, `affiliation_0_years`, `affiliation_0_position`
  (also index 1 and 2)
- `signature_base64` (PNG bytes encoded as base64)

The app now also sends `certificate_pdf` in the filing multipart request. Django
saves the application and certificate together in one transaction. The existing
PostgreSQL database holds a new `candidate_application_certificates` table:

- `application_id`: unique link to `candidate_applications`
- `pdf_bytes`: completed PDF, including the form layout, photo and signature
- `signature_bytes`: original PNG signature for new filings
- `filing_fields`: JSONB snapshot of personal details and memberships, excluding party secrets
- `sha256`, `template_version`, `created_at`: integrity and archival metadata

Archives are immutable. Removing a candidate's published registration does not
remove their filing archive. The foreign key prevents deleting an archived
application. Full PostgreSQL/full-system backups include the archive bytes;
JSON values are handled by the Python SQL backup fallback as well.

Authenticated downloads use
`GET /api/mobile/candidate-applications/<application_id>/certificate/` or the
corresponding `/api/admin/` route. Only the owner and session-authenticated admins
can read a PDF. There is no publicly accessible certificate URL. Status responses
include `certificate_available` and `certificate_sha256`, allowing a newly
installed app to display **View / Save Certificate** without a device copy.

Older device-only PDFs are backfilled to the same mobile route using `POST`
when the candidate opens their filing status. The existing server copy is never
overwritten. Legacy PDFs preserve the full document, but their separately stored
signature and metadata may be absent because the old app only retained the PDF.

Deploy the backend before using the updated mobile submission flow. It checks
`certificate_storage_ready` before submitting, to avoid silently filing without
a server archive. Older clients remain compatible with the submission endpoint.

After pushing the backend changes, run on the production server:

```bash
cd /var/www/elecom
git pull origin main
/var/www/elecom/venv/bin/python backend/manage.py migrate elecom_auth 0008
sudo systemctl restart gunicorn
sudo systemctl status gunicorn --no-pager
```

The blank PDF/PNG templates remain versioned app assets. Each archived completed
PDF preserves the exact form used at filing time. Updating either form only
requires an updated mobile build; the existing archive endpoint accepts both.
Previously archived certificates keep their original form.
