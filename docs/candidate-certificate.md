# Candidate certificate on mobile

The filing screen collects the additional Certificate of Candidacy details and a
handwritten signature. The supplied blank PDF is included in `assets/forms`;
the PNG preserves its layout for PDF generation. The filled sample is a layout
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

## Backend integration still required

This mobile change sends these extra multipart string fields to the existing
`POST /api/mobile/candidate-applications/submit/` endpoint:

- `curriculum_program`, `major`, `gender`, `date_of_birth` (YYYY-MM-DD), `age`
- `contact_number`, `email`, `address`
- `affiliation_0_organization`, `affiliation_0_years`, `affiliation_0_position`
  (also index 1 and 2)
- `signature_base64` (PNG bytes encoded as base64)

The current Django handler in `F:/elecom_web/backend/core/views.py` ignores these
new fields. It still saves the original filing fields and candidate photo.
The completed PDF is generated and retained locally, not uploaded to Django.
To make these details and the certificate available to web admins or on other
devices, extend that separate backend to validate/store the additional metadata,
store the signature and certificate, expose them through authenticated status
and admin endpoints, and render them in the admin filing review. The mobile
screen alone cannot provide server persistence. Deploy that integration before
relying on the new fields for official admin review.
