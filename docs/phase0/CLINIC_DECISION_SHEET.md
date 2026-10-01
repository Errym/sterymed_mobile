# Clinic decision sheet (one page)

**For:** the clinic owner or product owner. **Purpose:** the answers below unblock Phases 3–5. Each item has a recommended default, so "agreed" is a valid answer. Until an item is answered, engineering uses the default and records it as *unapproved*. Full context for D-numbers is in [CONTRACT_MATRIX.md](CONTRACT_MATRIX.md); backend work is in [BACKEND_DEPENDENCIES.md](BACKEND_DEPENDENCIES.md).

Fill in the **Decision** and **Name / date** columns. A named person must own each decision.

| # | Question | Recommended default | Decision | Name / date |
|---|---|---|---|---|
| D03 | Which controls must pass before a cycle can be released? Who may override a failed or missing control, and with what written reason? | Release blocked unless every required control for that device/program is recorded and passed. Override only by the named release approver, with a mandatory reason that is kept in the audit trail. | | |
| D04 | How do staff get alerts (low stock, expiring lot, failed cycle) in the pilot? Who is the responsible person? | In-app alert list plus a daily email digest to one named responsible person. Push notifications after the pilot. | | |
| D05 | Who can be chosen as the practitioner on a usage or prosthetic case? | Any active member of this clinic with the practitioner, admin or owner role. The app preselects the logged-in user when eligible. | | |
| D06 | May a stock manager edit label-expiry (DLU) rules, or only the owner? | Owner and admin only. | | |
| D07 | May an admin invite or remove an owner? What if the last owner is disabled? | Only an owner may add or remove owners, and the last active owner cannot be disabled. | | |
| D08 | May a practitioner record a label use while offline? Can a label be used twice? May a label be reprinted? | Offline use is queued with the original time and flagged for review. A label cannot be used twice. Reprint needs a reason and never revives a used or expired label. | | |
| D09 | Is there a practice-management software to connect to? If not, is a clearly labelled demo connector acceptable for the pilot? | No real connector for the pilot, with a documented demo connector. | | |
| D10 | Are cycle notes personal drafts or an official record? | Personal drafts for the pilot, clearly labelled. Official audited notes are a later feature. | | |
| X01 | **Inventory counts (inventaire)** are listed in the specification for the stock manager. Required for the pilot? | Not for the pilot. Record the exclusion in the written acceptance. Build it afterwards. | | |
| X02 | Which phones and tablets will staff use, and who owns the store accounts? | At least one Android phone and one tablet. iPhone only if the clinic needs it, because iOS needs extra setup. Accounts belong to the clinic, never a developer's personal account. | | |
| X03 | **Legal (GDPR / HDS):** who confirms hosting location, data-processing agreement and retention before any real patient reference is entered? | The clinic owner names a person. The pilot runs on test data until they sign off. | | |
| X04 | Should the app lock itself after inactivity on shared devices? How many minutes? | Yes. Require the device PIN or biometrics after 5 minutes in the background. | | |
| X05 | Support: who answers when something fails during clinic hours, and how fast? | One named person plus a phone number. Response within 1 working hour. | | |

## What stays out of the pilot unless you say otherwise

French only, no dark mode, no AI features, no advanced billing, no analytics dashboards, no push notifications for prosthetic reminders, one practice and one site.

## How answers are used

1. Answered items are copied into the decision ledger in `CONTRACT_MATRIX.md` as **approved**, with the name and date.
2. Unanswered items keep the default above and are recorded as **unapproved default**.
3. Nothing here authorizes real patient data. That needs X03 signed off first.
