# Stirling PDF API Reference

Base URL: `https://pdf-tools.msageha.net/api/v1` (Stirling PDF v3.5.0; no
`/api/v2` exists). All processing endpoints accept `multipart/form-data` and
return the processed file as a binary response. Uploads are limited to 2000 MB
per request (reverse proxy and server limit).

This file holds what the OpenAPI document doesn't say or says misleadingly.
Read endpoint lists and field-level schemas from the OpenAPI document.

## Endpoints and request schemas

`https://pdf-tools.msageha.net/v1/api-docs` is the server's own OpenAPI
document (about 1 MB, ~340 operations): fields, types, defaults (applied when a
field is omitted), enums and descriptions. Interactive docs:
`https://pdf-tools.msageha.net/swagger-ui/index.html`. Look up what you need
instead of reading the whole document:

```bash
# Find operations whose path or summary contains a word, e.g. "split", "watermark"
curl -sf "https://pdf-tools.msageha.net/v1/api-docs" | jq -er --arg q "<keyword>" '.paths | to_entries[]
  | .key as $p | .value | to_entries[] | select(.value | type == "object") | select(($p + " " + (.value.summary // "")) | ascii_downcase | contains($q | ascii_downcase))
  | "\(.key | ascii_upcase) \($p)  \(.value.summary // "")"'

# One operation with its $refs inlined (<skill-dir>: the directory of this skill's SKILL.md).
# Paths in the document start with /api/v1
curl -sf "https://pdf-tools.msageha.net/v1/api-docs" | jq -e -f "<skill-dir>/scripts/openapi-operation.jq" --arg method post --arg path /api/v1/misc/add-stamp
```

The operation `description` ends with `Input:<type> Output:<type>` (e.g.
`Output:ZIP` for PDF → HTML, `Output:IMAGE` for PDF → image). Operations
that can produce several files (`Type:SIMO`, e.g. split, PDF → image) return
either one file of that type or a ZIP depending on the result: check the
response `Content-Type` and save with a matching extension. Most request schemas include the common fields
`fileInput` (the upload, `-F "fileInput=@file.pdf"`) or `fileId` (a
server-side file from an async job), and, where present, `pageNumbers`
(`all`, `1,3,5-9`, or expressions like `2n+1`).

## Authentication

Requests to this instance don't need an `X-API-KEY` header. Auth depends on
the deployment (`security.enableLogin`); if login is ever enabled,
unauthenticated requests get `401` — pass the key in the `X-API-KEY` header.

## Behaviour the OpenAPI document doesn't show

Conversion

- `POST /convert/url/pdf` accepts internet URLs only: private network,
  loopback and `.local` hosts are rejected on this instance with a `303`
  redirect (not a 4xx), so check for `200`.

Pages

- `POST /general/remove-pages`: the OpenAPI default `all` doesn't apply —
  omitting `pageNumbers`, or listing every page, is `400`. Send the pages to
  remove.

Compression and OCR

- `POST /misc/compress-pdf`: if no candidate comes out smaller than the input,
  the original file is returned unchanged (so `linearize` / `normalize` /
  `lineArt` aren't applied either) — except with `grayscale=true`. With
  `expectedOutputSize` the result can still be larger than the target at
  level 9. Compare the sizes to tell.
- `POST /misc/ocr-pdf`: `languages` that aren't installed on the server are
  dropped silently; if none is installed → `400` `none of the selected
  languages are valid`. `GET /ui-data/ocr-pdf` lists the installed ones
  (`{"languages": [...]}`). `sidecar=true`
  returns a ZIP with the PDF and a text file. `ocrType=Normal` behaves as
  `skip-text` with OCRmyPDF, but the Tesseract fallback OCRs every page.

Page numbers and stamps

- `POST /misc/add-page-numbers` selects pages with `pagesToNumber`;
  `pageNumbers` is accepted but ignored. `fontType` is marked required but
  falls back to Helvetica.
- `POST /misc/add-stamp`: `stampType=image` needs `stampImage`; a QR stamp's
  content (after placeholders such as `@date` are expanded) may be at most
  1000 UTF-8 bytes. `stampText` may start with `@` (`@page`, `@date`, …), so
  send it with `--form-string`; `-F` would read it as a local file.

Metadata

- `POST /misc/update-metadata` writes the document info dictionary only:
  existing document-level XMP keeps its old values. Without
  `keepOmitted=true`, every standard field you omit (dates and Trapped
  included) is removed. `deleteAll=true` clears the info dictionary's entries
  (the dictionary itself stays) and removes the catalog's `/Metadata` and
  `/PieceInfo`; XMP attached to pages or images remains, so don't report the
  file as metadata-free from this alone.

Passwords (the user supplies them through a file; see SKILL.md)

- `POST /security/add-password`: each `prevent*` you omit is allowed. When
  protecting an unencrypted PDF, the restrictions hold only with a non-empty
  `ownerPassword` different from `password`. To edit an encrypted PDF, send
  `sourcePassword` and `preserveExisting=true`: the `prevent*` sent replace its
  restrictions (resend every restriction to keep), and omitting `ownerPassword`
  (or sending it empty) keeps its existing passwords. Sending one replaces the
  permissions password and needs the existing opening password: in
  `password`, or in `sourcePassword` when that one also opens the file.
- `POST /security/remove-password` with `password` alone removes the opening
  password, but a PDF that also had restrictions is re-protected with a new
  random permissions password (the original one is lost), so the restrictions
  stay. `removeAll=true` removes everything (needs the permissions password in
  `password` or `sourcePassword` when the server honors owner passwords — the
  default). Selective removal keeps the other password: to remove only the
  opening password, send it as `password` and the permissions password as
  `sourcePassword`; to remove only the permissions password (its restrictions
  go with it), send it as `ownerPassword` and the opening password to keep as
  `retainedOpeningPassword`.

## Responses not typed in the OpenAPI document

| Endpoint                               | Response                                                 |
| -------------------------------------- | -------------------------------------------------------- |
| `POST /analysis/page-count`            | `{ "pageCount": 1 }` — a JSON object, not a bare integer |
| `POST /analysis/basic-info`            | `{ "pageCount": 1, "pdfVersion": 1.4, "fileSize": 254 }` |
| `POST /analysis/document-properties`   | Title, author, creator, dates, etc.                      |
| `GET /info/status`, `GET /info/health` | `{ "version": "3.5.0", "status": "UP" }`                 |
| `GET /info/uptime`                     | Plain text, not JSON (e.g. `0d 8h 56m 18s`)              |

There is no PDF-compare endpoint in the API (the web UI's Compare tool isn't
exposed here).
