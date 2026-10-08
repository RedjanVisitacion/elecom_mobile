# Certificate of Candidacy settings

The web admin sidebar has **Certificate of Candidacy** after **Candidate Files**.
For the current election, the academic year and COMELEC chairperson are shared
by USG and the department form (SITE, PAFE, and AFPROTECHS). Editing either side
updates both previews. Either Save button stores both forms atomically. Existing
USG settings take precedence when loading older separate settings; department
settings are the fallback if USG settings have never been saved. Drag the academic-year
slider to choose the start year; the end year is automatically the next year.
Inline previews update while editing, before saving, with the name above the
chairperson label. The sworn date remains blank
until initial filing approval.

Initial approval creates a separate approved PDF with that day's date in Philippine
time and USTP Oroquieta Campus. Final approval and later settings changes do not change it.
Mobile and web certificate downloads return this approved edition. The original
signed submission stays in `candidate_application_certificates`.

The new database tables are `candidate_certificate_settings` and
`candidate_certificate_issuances`. Full database backups include these tables and
the PDFs. Settings belong to the election and must be configured again for a new
election. Older approvals do not have a recorded initial approval date and are
not retroactively dated.

Before approving an archived COC, configure the settings for its form. Filings
from older clients without an archived PDF retain their existing review flow.

Commit and push changes from both repositories. On the production server:

```bash
cd /var/www/elecom
git pull origin main
/var/www/elecom/venv/bin/pip install 'pypdf>=6.19,<7' 'reportlab>=5.0,<6'
/var/www/elecom/venv/bin/python backend/manage.py migrate
/var/www/elecom/venv/bin/python backend/manage.py collectstatic --noinput
sudo systemctl restart gunicorn
```

Then rebuild and install the mobile APK using `bump_and_build.ps1`. Deploy the
backend first: updated mobile previews fetch the admin settings, and viewing a
filed COC downloads the server edition rather than the older device copy.

Verify using a new filing: save both forms' settings, preview the mobile COC,
submit it, approve the initial filing, and open it from Candidate Files and mobile.
Confirm the academic year, chairperson name, and initial approval date. Changing
the settings afterward must not change this already issued certificate.

The PDF overlay uses [pypdf page merging](https://pypdf.readthedocs.io/en/latest/user/add-watermark.html)
and [ReportLab canvas text](https://docs.reportlab.com/reportlab/userguide/ch2_graphics/).
