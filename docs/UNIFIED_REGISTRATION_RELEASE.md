# Unified account and intake — initial operational release

## Implemented

- `join.html`: email/password account creation, confirmation code/link handling, sign-in, session refresh, password recovery and sign-out. Sessions are scoped to the browser tab through sessionStorage.
- Profile storage and independent applicant, guardian, employer, instructor and institution intake drafts and submissions.
- Authenticated API derives owner and verified email from Supabase Auth; client-supplied user IDs are never trusted. No client direct table access. No secret key in frontend code.
- Applicant submission atomically creates an existing `aviation_interest_leads` application and an `am_application_auth_bindings` record. A locked request cannot create duplicate applications. Resubmission after more-information response preserves the original application reference.
- `access_review.html`: existing staff session and registration.read/manage permissions; requester-visible responses and audit events. “Reviewed” is an intake review only, never admission, employment selection or a grant of staff privileges.
- Existing activation, documents, payment and enrollment processes remain separate. The approved admission journey is displayed without moving program registration before assessment.

## Validation

- JavaScript syntax checked with Node; HTML element IDs checked for uniqueness.
- Live API checked using a disposable confirmed QA account: invalid token rejected; profile saved; draft saved; applicant submitted; one existing admission binding returned; client-supplied owner ignored; duplicate submission blocked; member denied the staff review queue. The disposable account and generated application were then removed. Initial short HTTP timeouts were rerun with sufficient response time.
- GitHub Pages deployment succeeded. Browser checked sign-in, signup and recovery screens and staff review queue. No real mailbox verification was attempted.
- Deployed `identity-access-api` with explicit server authentication despite gateway JWT checking being disabled, to support the existing custom staff token.
- Database transaction test, rolled back: draft; submit; application binding; duplicate prevention; more-information response; resubmit preserving one binding; anonymous and authenticated roles denied direct table and transaction-function access.
- Security advisors consulted; project-wide existing findings are not a clean security certification. Advisor timestamps may precede this migration.

## Release boundaries and remaining acceptance gates

- Verify actual signup confirmation delivery and password recovery delivery with a real mailbox; no mailbox test has yet been completed. Supabase SMTP configuration, templates, CAPTCHA settings and redirect allowlist must match the deployment. The app supports manual confirmation/recovery codes and link fragments; email template content determines what recipients receive.
- Initial English interface. No claim that all routes are fully provisioned service portals.
- Applicant interest uses the existing database's controlled vocabulary, not a new course catalogue. Course-specific intake, attachments and eligibility decisions remain in their established workflows and need the next integration pass.
- Guardian intake currently supports one child per account request. It is not the full multi-child learning-profile implementation. No direct child accounts or direct child contact details are collected.
- Employer and instructor requests capture intake only; organization verification, team invitations, credential evidence checks and role provisioning are not implemented in this release.
- Existing applicants are not automatically claimed by matching an email. They retain the existing application-login verification process. Submitted payload snapshots are kept in the request; event history records submissions and responses, not every draft keystroke.
- `app.aviationmatrix360.com` has not been configured by this change. No edits to DNS or the existing colors site.

## Entry points

- Member: `/join.html`
- Staff: `/access_review.html` after staff portal sign-in
- Backend: `/functions/v1/identity-access-api`

Database migration: `20261105093125_unified_account_intake_layer.sql`.
