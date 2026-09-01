# Publishing this repo publicly

The design of this repo is that **the reusable engineering is public and the
values are not**. Modules, routing logic, IAM policy shapes and documentation
all go to GitHub. Account IDs, real bucket names, Panorama addresses, auth
keys and backend config stay on your disk.

That split is enforced three ways: file naming, `.gitignore`, and an audit
script that fails the commit.

---

## What is tracked, and what is not

| Tracked | Local only |
|---|---|
| `terraform.tfvars.example` | `terraform.tfvars` |
| `backend.hcl.example` | `backend.hcl` |
| `iam/*.json` with `<ACCOUNT_ID>` | `iam/generated/*.json` |
| everything under `modules/` | `*.tfstate`, `*.tfplan`, `.terraform/` |
| `README.md`, `docs/` | `bootstrap.xml`, `*.pem`, `*.key` |

First thing after cloning:

```bash
./scripts/install-hooks.sh
cd envs/prod/us-east-1
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# fill in the real values - both files are gitignored
```

---

## Before the first push

```bash
./scripts/install-hooks.sh     # pre-commit runs the audit on staged changes
./scripts/audit-public.sh      # full check: working tree AND history
```

The audit covers six things:

1. Files that must never be tracked, including anything force-added past
   `.gitignore`.
2. 12-digit strings that look like AWS account IDs, minus an allowlist of
   AWS-owned service accounts.
3. Credential shapes - access keys, private key blocks, Slack tokens.
4. `vm_auth_key`, `vm_series_auth_codes`, `panorama_server` and
   `certificate_arn` assigned a literal value in any tracked file.
5. The same patterns anywhere in **commit history**.
6. `gitleaks`, if installed, with the repo's `.gitleaks.toml`.

### History is the part people get wrong

`.gitignore` has no effect on what is already committed. A secret added in
commit 3 and removed in commit 4 is still published when you push, and GitHub
serves it forever at that commit SHA.

This repo has no real values in it, but it does carry commits from before the
`.example` split. The cheapest fix, and the right one for a repo that has
never been pushed, is to collapse to a single initial commit:

```bash
git checkout --orphan public-main
git add -A
git commit -m "Initial public release"
git branch -D main            # or master
git branch -m main
./scripts/audit-public.sh     # history check should now pass
```

If the repo has already been pushed somewhere, squashing is not enough -
the old objects live on the remote. Use `git filter-repo`, then rotate
anything that was exposed. Treat any credential that reached a public remote
as burned regardless of how fast you deleted it.

---

## GitHub-side settings

On a public repo these are free; turn them on before the first push if you
can, since they only block what arrives after they are enabled:

- **Settings → Code security → Secret scanning**: on.
- **Push protection**: on. This rejects a push containing a recognised
  credential rather than accepting it and emailing you afterwards.
- **Branch protection on `main`**: require a PR, so a stray local commit
  cannot go straight up.
- **Actions → General**: if you add CI, set workflow permissions to
  read-only and never put AWS keys in repo secrets - use OIDC with the deploy
  role from `docs/iam.md`.

A CI job that runs the same audit on every PR:

```yaml
name: audit
on: [pull_request]
jobs:
  secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0        # history checks need the full clone
      - run: ./scripts/audit-public.sh
```

---

## Judgment calls the script cannot make for you

**Your address plan.** `10.101.0.0/16` and `10.102.0.0/16` are in the README,
the module defaults and the examples. RFC1918 space is not a credential, but
it is a map of your network, and combined with a public repo it tells a
reader how your environment is laid out. If that bothers you, sed the
examples to `10.0.0.0/16` / `10.1.0.0/16` before publishing and keep the real
plan in your private `terraform.tfvars`. Nothing in the modules depends on
the specific numbers.

**Spoke names.** `spoke-01` through `spoke-06` reveal nothing. If you rename
them after what they host, that naming is now public. Keep business-meaningful
names in the private tfvars and leave the examples generic.

**Private ASNs.** 64512 and 64513 are from the private range and are not
sensitive on their own.

**Your employer's context.** Commit messages, branch names and the author
email on every commit are all public. Check `git log --format='%an %ae'`
before pushing if you have been committing with a work address and would
rather not.

---

## If something does get out

1. Rotate the credential first. Deleting the commit does not un-publish it -
   forks, clones, GitHub's cached views and third-party scrapers all still
   have it. Scrapers hit new public repos within minutes.
2. Then clean history with `git filter-repo` and force-push.
3. For an AWS key specifically: deactivate it in IAM, then check CloudTrail
   for use between the push and the rotation.
