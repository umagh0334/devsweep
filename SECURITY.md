# Security Policy

DevSweep deletes files on your Mac and makes security judgements about your files.
That combination deserves a clear, honest security policy.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Use GitHub's private reporting instead:
[**Report a vulnerability**](https://github.com/umagh0334/devsweep/security/advisories/new)

This is a solo side project. Realistic expectations:

| | |
|---|---|
| Acknowledgement | within 7 days |
| Assessment | within 14 days |
| Fix for high-impact issues | as fast as I can, prioritised over features |
| Credit | happily given, unless you prefer otherwise |

If a report is critical and I go silent for more than 30 days, you are welcome to
disclose publicly — a stale unfixed hole in a deletion tool is worse than an
embarrassing disclosure.

## What counts as high impact here

In rough priority order:

1. **Unintended deletion** — any path where DevSweep removes something the user did
   not select, or where what the UI promised differs from what was actually deleted.
2. **Broken privacy claim** — anything showing DevSweep reads file *contents*, or
   sends file data anywhere. See the pledge in Settings → About.
3. **Update chain compromise** — bypassing Ed25519 signature verification, downgrade
   attacks, or anything that lets an unsigned build install itself.
4. **False assurance** — the security check reporting "no findings" when a secret is
   plainly exposed in the scanned scope. A cleaner that misses a cache is annoying;
   a security tool that says "you're clean" when you aren't is harmful.
5. **Privilege / permission problems** — anything that widens the app's access beyond
   what the user granted.

## Known limitations (not vulnerabilities, but you should know)

- **The app is ad-hoc signed and not notarized.** First launch requires clearing the
  quarantine attribute. This means the initial download is trusted on the basis of the
  GitHub account alone — only *updates* are protected by Ed25519 signature verification.
- **The security check is a whitelist.** It matches known filenames, git state and
  permissions. It cannot find a secret in a file it does not recognise, and it never
  reads file contents. Empty results mean "nothing found in the scanned scope", not
  "you are safe".
- **git history scanning is delegated to [gitleaks](https://github.com/gitleaks/gitleaks)**
  and only runs when you start it. DevSweep asks gitleaks to emit metadata only, so the
  secret values themselves are never passed back to DevSweep.
- **Protected folders are skipped by default.** Desktop, Documents and Downloads are
  excluded unless you opt in; Music, Pictures and Movies are always excluded.

## Scope

In scope: this repository — the `devsweep` CLI engine, the SwiftUI app, the build and
release process, and the update mechanism.

Out of scope: vulnerabilities in third-party tools DevSweep invokes (`brew`, `docker`,
`gitleaks`, …) — please report those upstream.
