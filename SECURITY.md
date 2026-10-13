# Security

This repository contains SQL, documentation, a spreadsheet model and a Power BI report built on public EBA data. It holds no credentials, personal data or production systems.

## Reporting a concern

If you find something that should not be public (for example a credential, personal information or a licensing problem with included data), please report it privately through **Security → Report a vulnerability** on this repository's GitHub page, rather than opening a public issue.

## Practices

- No secrets are stored in the repository; `.gitignore` excludes common credential files.
- Raw EBA files are not committed; they are downloaded from the EBA (see `data/README.md`).
- GitHub Actions workflows use read-only permissions by default and pin each action to a full commit SHA (release tag noted beside it). The web page loads one third-party script, DuckDB-WASM, at a pinned version from jsDelivr, and sets a Content Security Policy that allows scripts only from the page itself and that host.
