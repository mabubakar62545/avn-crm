# AVN CRM

A Rails 8 CRM for AVN Secure Limited. The current release covers the
authentication and account-security foundation: sign-up with email
verification, sign-in with optional two-factor authentication, role-based
access control, session management and a tamper-resistant audit log.

## Tech stack

| Area            | Choice                                                      |
| --------------- | ----------------------------------------------------------- |
| Language        | Ruby 3.4.2 (`.ruby-version`)                                |
| Framework       | Rails 8.1                                                   |
| Database        | SQLite 3 (separate DBs for cache, queue and cable in prod)  |
| Frontend        | Hotwire (Turbo + Stimulus), import maps, Propshaft          |
| Background jobs | Solid Queue (runs inside Puma in production)                |
| Cache / sockets | Solid Cache, Solid Cable                                    |
| Auth            | `has_secure_password` (bcrypt), `rotp` + `rqrcode` for TOTP |
| Authorization   | Pundit                                                      |
| Rate limiting   | Rack::Attack                                                |
| Deployment      | Docker + Kamal, Thruster in front of Puma                   |

## Features

### Authentication
- **Registration** with email verification (links expire after 2 days).
- **Sign-in** with email and password. Passwords need at least 12 characters
  and must not contain the local part of the email address.
- **Password reset** by email. Changing a password signs out every other
  session.
- **Account lockout** after 10 failed sign-ins, lasting 30 minutes. The user
  is notified by email.

### Two-factor authentication
- TOTP via any authenticator app (QR code shown during setup).
- 10 single-use recovery codes, stored only as hashes.
- Replayed codes are rejected; the OTP secret is encrypted at rest with
  Active Record encryption.

### Sessions
- Database-backed sessions in a signed, `HttpOnly`, `SameSite=Lax` cookie.
- 2-hour idle timeout and 2-week absolute timeout.
- Users can view their active sessions and revoke one or all others
  (`/account/sessions`).

### Roles and permissions

Roles are ordered `member` → `manager` → `admin`.

| Capability                         | member | manager | admin |
| ---------------------------------- | :----: | :-----: | :---: |
| Manage own account, 2FA, sessions  |   ✓    |    ✓    |   ✓   |
| View user list and user details    |        |    ✓    |   ✓   |
| Change another user's role         |        |         |   ✓   |
| Unlock accounts, revoke sessions   |        |         |   ✓   |
| View audit log                     |        |         |   ✓   |

Admins cannot change their own role. Rules live in `app/policies/`.

### Audit log
Security-relevant events are written to the `audit_events` table and to the
Rails log as JSON, with actor, target user, IP, user agent and request ID.
Records are read-only once saved. Events include `user.registered`,
`email.verified`, `login.succeeded`, `logout`, `password.changed`,
`account.locked`, `role.changed`, `mfa.enabled` and `mfa.disabled`.

Admins can browse it at `/admin/audit_events`.

### Rate limiting (`config/initializers/rack_attack.rb`)

| Rule            | Limit                                                    |
| --------------- | -------------------------------------------------------- |
| All requests    | 300 per IP per 5 min (assets excluded)                   |
| Sign-in         | 20 per IP per 5 min, 10 per email address per 15 min     |
| Email-sending   | 5 per IP per 15 min on password reset, sign-up, verify   |

Throttled requests get `429` with a `Retry-After` header.

## Getting started

### Prerequisites
- Ruby 3.4.2 (via rbenv, asdf or mise)
- SQLite 3
- libvips (for Active Storage image variants): `brew install vips`

### Setup

```sh
git clone <repo-url> avn-crm
cd avn-crm
bin/setup          # installs gems, prepares the DB and starts the server
```

To set up without starting the server, run `bin/setup --skip-server`, then
start it later with `bin/dev`. The app runs at <http://localhost:3000>.

### Credentials

Secrets live in `config/credentials.yml.enc`, decrypted by
`config/master.key`. The key is git-ignored, so get it from a team member
(or set `RAILS_MASTER_KEY`). Edit credentials with:

```sh
bin/rails credentials:edit
```

### Demo accounts

`bin/rails db:seed` (run by `bin/setup`) creates these accounts in
development and test. The password for all of them is `TestPassword123!`.

| Email                  | Role    | Notes                      |
| ---------------------- | ------- | -------------------------- |
| `admin@avn-crm.test`   | admin   | Full access                |
| `manager@avn-crm.test` | manager | Read-only user list        |
| `member@avn-crm.test`  | member  | Own account only           |
| `locked@avn-crm.test`  | member  | Locked out, to test unlock |
| `pending@avn-crm.test` | member  | Email not yet verified     |

### Email in development

Mail is written to `tmp/mails/` instead of being sent. You can also preview
templates at <http://localhost:3000/rails/mailers>.

## Testing and code quality

```sh
bin/rails test     # unit, controller, mailer and policy tests
bin/rubocop        # style (rubocop-rails-omakase)
bin/brakeman       # static security analysis
bin/bundler-audit  # known-vulnerable gems
bin/importmap audit
bin/ci             # all of the above, plus a seed check
```

GitHub Actions (`.github/workflows/ci.yml`) runs Brakeman, bundler-audit,
the importmap audit, RuboCop and the test suite on every pull request and on
pushes to `main`.

## Deployment

The app ships as a Docker image and is deployed with
[Kamal](https://kamal-deploy.org). Configuration is in `config/deploy.yml`;
secrets are read from `.kamal/secrets`.

Before the first production deploy:
1. Set the real server IP(s), registry and image name in `config/deploy.yml`.
2. Make sure `RAILS_MASTER_KEY` is available to `.kamal/secrets`.
3. Set the mailer host and SMTP settings in `config/environments/production.rb`
   (they are still placeholders) and add SMTP credentials.

```sh
bin/kamal setup    # first deploy
bin/kamal deploy   # later deploys
bin/kamal console  # Rails console on the server
bin/kamal logs     # follow logs
```

SQLite databases are stored on the `avn_crm_storage` volume, mounted at
`/rails/storage`. A health check is served at `/up`.

## Project layout

```
app/
  controllers/
    concerns/authentication.rb   # session cookie, sign-in helpers
    account/                     # 2FA and session management for the current user
    admin/                       # user admin and audit log
  models/                        # User, Session, RecoveryCode, AuditEvent, Current
  policies/                      # Pundit authorization rules
  mailers/                       # password reset, verification, lockout emails
config/
  initializers/rack_attack.rb    # rate limits
  deploy.yml                     # Kamal deployment
db/seeds.rb                      # demo accounts
test/                            # Minitest suite
```

## Branching

Work happens on `dev`, and pull requests go into `main`.
