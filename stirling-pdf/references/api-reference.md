# Stirling PDF API Reference

Base URL: `https://pdf-tools.msageha.net/api/v1` (**Stirling PDF v3.5.0**;
no `/api/v2` exists). Paths below are relative to it.
All processing endpoints accept `multipart/form-data` and return the
processed file as a binary response. Uploads are limited to 2000 MB per
request (reverse proxy and server limit).

---

## Authentication

Auth is **deployment-dependent**, controlled by `security.enableLogin` /
`SECURITY_ENABLELOGIN`. Requests to this instance don't need an `X-API-KEY`
header. If login is ever enabled, unauthenticated requests get `401` with
`"Authentication required. Please provide valid credentials or X-API-KEY
header."` — pass the key via the `X-API-KEY` header in that case.

---

## Common Parameters

| Field     | Type   | Description                                            |
| --------- | ------ | ------------------------------------------------------ |
| fileInput | binary | The input file (upload via `-F "fileInput=@file.pdf"`) |
| fileId    | string | Server-side file ID (alternative to fileInput)         |

Defaults in the tables below are applied when the field is omitted, unless
the table says otherwise.

### Page Selection (`pageNumbers`)

- `all` — all pages
- `1,3,5` — specific pages
- `1-5` — range
- `1,3,5-9` — mixed
- `2n+1` / `2n` — expression (odd / even pages)

---

## Conversion Endpoints

### POST /convert/pdf/markdown

Convert PDF to Markdown. Field: `fileInput` (required). No extra params.

### POST /convert/pdf/text

Convert PDF to plain text or RTF.

| Field        | Required | Description    |
| ------------ | -------- | -------------- |
| fileInput    | yes      | Input PDF      |
| outputFormat | yes      | `txt` or `rtf` |

### POST /convert/pdf/img

Convert PDF pages to images.

| Field              | Required | Default    | Description                                    |
| ------------------ | -------- | ---------- | ---------------------------------------------- |
| fileInput          | yes      | —          | Input PDF                                      |
| pageNumbers        | no       | `all`      | Pages to convert                               |
| imageFormat        | no       | `png`      | `png` / `jpeg` / `jpg` / `gif` / `webp`        |
| singleOrMultiple   | no       | `multiple` | `single` (all pages in one image) / `multiple` |
| colorType          | no       | `color`    | `color` / `greyscale` / `blackwhite`           |
| dpi                | no       | `300`      | Resolution in DPI                              |
| includeAnnotations | no       | `false`    | Include annotations                            |

**Response:** Image file or ZIP (if multiple).

### Other conversions

| Endpoint                     | Key fields                                                                                                                                                        |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /convert/pdf/word`     | `fileInput`, `outputFormat` (`docx` / `odt`, required; `doc` → 400 since 3.5)                                                                                     |
| `POST /convert/pdf/html`     | `fileInput` → ZIP (HTML and assets)                                                                                                                               |
| `POST /convert/markdown/pdf` | `fileInput`                                                                                                                                                       |
| `POST /convert/html/pdf`     | `fileInput`, `zoom` (default `1`)                                                                                                                                 |
| `POST /convert/url/pdf`      | `urlInput` — internet URLs only: private network, loopback and `.local` hosts are rejected on this instance with a `303` redirect (not a 4xx), so check for `200` |
| `POST /convert/img/pdf`      | `fileInput` (multiple), `fitOption` (`fillPage`/`fitDocumentToImage`/`fitDocumentToPage`/`maintainAspectRatio`, default `fillPage`), `colorType`, `autoRotate`    |
| `POST /convert/file/pdf`     | `fileInput` — Word, Excel, PowerPoint, OpenDocument, RTF, CSV and text files → PDF (Stirling Office Convert). For web pages use `/convert/html/pdf`               |

Other conversion endpoints, not detailed here but present in the API:
`/convert/pdf/pdfa`, `/convert/pdf/presentation`, `/convert/pdf/xml`,
`/convert/ebook/pdf`, `/convert/eml/pdf`, `/convert/svg/pdf`,
`/convert/pdf/epub`, `/convert/pdf/xlsx`, `/convert/pdf/csv`,
`/convert/pdf/ua`, `/convert/cbz/pdf` ↔ `/convert/pdf/cbz`,
`/convert/cbr/pdf` ↔ `/convert/pdf/cbr`.

---

## Page Operations

| Endpoint                        | Key fields                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /general/merge-pdfs`      | `fileInput` (multiple), `sortType` (`orderProvided`/`byFileName`/`byDateModified`/`byDateCreated`/`byPDFTitle`, default `orderProvided`), `removeCertSign` (default `true`), `generateToc` (default `false`)                                                                                                                                                                                                                                                                                                |
| `POST /general/split-pages`     | `fileInput`, `pageNumbers` (default `all`) = split points: the PDF is cut after each listed page (`2` → pages 1-2 and 3-end; `all` = one file per page) → ZIP                                                                                                                                                                                                                                                                                                                                               |
| `POST /general/remove-pages`    | `fileInput`, `pageNumbers` (required in practice: the pages to remove; omitted, or removing every page → 400)                                                                                                                                                                                                                                                                                                                                                                                               |
| `POST /general/rotate-pdf`      | `fileInput`, `angle` (`0`/`90`/`180`/`270`, required)                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `POST /general/rearrange-pages` | `fileInput`, `pageNumbers` (the output in that order: pages not listed are dropped, a page listed twice is kept once — list every page to keep them all), `customMode` (optional preset instead of an explicit order: `REVERSE_ORDER` / `DUPLEX_SORT` / `BOOKLET_SORT` / `SIDE_STITCH_BOOKLET_SORT` / `ODD_EVEN_SPLIT` / `ODD_EVEN_MERGE` / `REMOVE_FIRST` / `REMOVE_LAST` / `REMOVE_FIRST_AND_LAST` / `DUPLICATE` (then `pageNumbers` is the number of copies of each page); `CUSTOM` = use `pageNumbers`) |

Other page-operation endpoints: `/general/split-by-size-or-count`,
`/general/split-pdf-by-chapters` (note the `pdf-` infix), `/general/pdf-to-single-page`,
`/general/scale-pages`, `/general/overlay-pdfs` (plural), `/general/crop`,
`/general/booklet-imposition`, `/general/edit-table-of-contents`,
`/general/extract-bookmarks`, `/general/multi-page-layout`,
`/general/split-for-poster-print`,
`/general/split-pdf-by-sections`, `/general/remove-image-pdf` (moved here from
`/misc` in 3.x), plus the async job/file API (`/general/job/{jobId}`,
`/general/files/{fileId}`).

---

## Optimization & Repair

### POST /misc/compress-pdf

| Field                                         | Required | Default              | Description                                                                                                                                                                                                                                                            |
| --------------------------------------------- | -------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| fileInput                                     | yes      | —                    | Input PDF                                                                                                                                                                                                                                                              |
| optimizeLevel                                 | no       | `5`                  | 1-9 (higher = more compression, lower quality)                                                                                                                                                                                                                         |
| expectedOutputSize                            | no       | —                    | Target size (e.g. `500KB`, `2MB`); when set, the server picks the starting level itself (overriding `optimizeLevel`) and raises it toward the target. Not a guarantee — at level 9 the result can still be larger (or the original is returned); check the output size |
| linearize                                     | no       | `false`              | Optimize for web viewing                                                                                                                                                                                                                                               |
| normalize                                     | no       | `false`              | Normalize content                                                                                                                                                                                                                                                      |
| grayscale                                     | no       | `false`              | Convert to grayscale                                                                                                                                                                                                                                                   |
| lineArt / lineArtThreshold / lineArtEdgeLevel | no       | `false` / `55` / `1` | Line-art-aware compression tuning (`lineArtEdgeLevel` 1-3)                                                                                                                                                                                                             |

If no candidate comes out smaller than the input, the original file is
returned unchanged (so `linearize` / `normalize` / `lineArt` aren't applied
either) — except with `grayscale=true`. Compare the sizes to tell.

### POST /misc/ocr-pdf

| Field             | Required | Default     | Description                                                                                                                                                                                                                                                                                    |
| ----------------- | -------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| fileInput         | yes      | —           | Input PDF                                                                                                                                                                                                                                                                                      |
| languages         | no       | `["eng"]`   | Language codes; which ones work depends on the `.traineddata` files installed on the server. `GET /ui-data/ocr-pdf` lists the installed ones (`{"languages": [...]}`). Codes that aren't installed are dropped silently; if none is installed → 400 `none of the selected languages are valid` |
| ocrType           | no       | `skip-text` | `skip-text` (OCR only pages without text) / `force-ocr` (rasterize and OCR every page) / `Normal` (as `skip-text` with OCRmyPDF; the Tesseract fallback OCRs every page)                                                                                                                       |
| ocrRenderType     | no       | `hocr`      | `hocr` (overlay text) / `sandwich` (hidden text layer) — server rejects any other value                                                                                                                                                                                                        |
| sidecar           | no       | `false`     | `true` returns a ZIP with the PDF and a text file                                                                                                                                                                                                                                              |
| rotatePages       | no       | `false`     | Auto-correct page orientation (90/180/270) with Tesseract OSD                                                                                                                                                                                                                                  |
| deskew            | no       | `false`     | Deskew skewed pages                                                                                                                                                                                                                                                                            |
| clean             | no       | `false`     | Clean input before OCR                                                                                                                                                                                                                                                                         |
| cleanFinal        | no       | `false`     | Clean final output                                                                                                                                                                                                                                                                             |
| removeImagesAfter | no       | `false`     | Remove images from output                                                                                                                                                                                                                                                                      |

### POST /misc/repair / POST /misc/flatten

`repair`: `fileInput` only. `flatten`: `fileInput`, `flattenOnlyForms` (`true`
= forms only, `false` = full page rasterize, default `false`), `renderDpi`
(optional DPI for the full-page rasterize).

Other misc endpoints: `/misc/remove-blanks`, `/misc/auto-rename`,
`/misc/add-comments`, `/misc/add-attachments`, `/misc/extract-attachments`,
`/misc/list-attachments`, `/misc/extract-single-attachment`,
`/misc/batch-process-attachments`, `/misc/rename-attachment`, `/misc/delete-attachment`,
`/misc/auto-split-pdf`, `/misc/decompress-pdf`, `/misc/extract-image-scans`,
`/misc/add-image`, `/misc/replace-invert-pdf`, `/misc/scanner-effect`,
`/misc/unlock-pdf-forms`, `/misc/show-javascript`, `/misc/auto-rotate-pdf`,
`/misc/create-portfolio`, `/misc/flatten-portfolio`.

---

## Annotations & Metadata

### POST /misc/extract-images

| Field     | Required | Default | Description            |
| --------- | -------- | ------- | ---------------------- |
| fileInput | yes      | —       | Input PDF              |
| format    | yes      | `png`   | `png` / `jpeg` / `gif` |

There is no `allowDuplicates` field; don't send it.

### POST /misc/add-page-numbers

| Field          | Required | Default     | Description                                                                                                                    |
| -------------- | -------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------ |
| fileInput      | yes      | —           | Input PDF                                                                                                                      |
| fontType       | no       | `helvetica` | `helvetica` / `courier` / `times` (OpenAPI marks it required, but omitting it works)                                           |
| position       | no       | `8`         | 1-9 grid position (8 = bottom-center)                                                                                          |
| pagesToNumber  | no       | `all`       | Which pages get numbers (`pageNumbers` is ignored here)                                                                        |
| startingNumber | no       | `1`         | Number on the first numbered page                                                                                              |
| fontSize       | no       | `12`        | Font size                                                                                                                      |
| fontColor      | no       | `#000000`   | Hex color                                                                                                                      |
| zeroPad        | no       | `0`         | Zero-padding width (Bates stamping); `0` disables                                                                              |
| customText     | no       | `{n}`       | `{n}` = running number (from `startingNumber`, counting numbered pages only), `{total}` = total pages, `{filename}` = filename |
| customMargin   | no       | `medium`    | `small` / `medium` / `large` / `x-large`                                                                                       |

Position grid: `1=top-left 2=top-center 3=top-right / 4=mid-left 5=center 6=mid-right / 7=bot-left 8=bot-center 9=bot-right`.

### POST /misc/add-stamp

| Field                 | Required       | Default   | Description                                                                                                                                                                                                                                                  |
| --------------------- | -------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| fileInput             | yes            | —         | Input PDF                                                                                                                                                                                                                                                    |
| pageNumbers           | no             | `all`     | Target pages                                                                                                                                                                                                                                                 |
| stampType             | no             | see right | `text` / `image` / `qr`. Omitted → `image` if `stampImage` is sent, else `text`                                                                                                                                                                              |
| stampText             | text / qr: yes | —         | Stamp text, or the QR content (≤ 1000 UTF-8 bytes). Missing for `text` → 400. Supports `@page`, `@total_pages`, `@date`, `@date{dd/MM/yyyy}`, `@time`, `@filename`, `@title`, `@author`, `@uuid` (`@@` = literal `@`); `\n` starts a new line in text stamps |
| stampImage            | image: yes     | —         | Stamp image                                                                                                                                                                                                                                                  |
| alphabet              | no             | `roman`   | Font script of `stampText`: `roman` / `arabic` / `japanese` / `korean` / `chinese` / `thai`                                                                                                                                                                  |
| fontSize              | no             | `40`      | Text size in points; for an image stamp, the image height (width keeps the aspect ratio)                                                                                                                                                                     |
| rotation              | no             | `0`       | Rotation in degrees                                                                                                                                                                                                                                          |
| opacity               | no             | `0.5`     | 0.0-1.0                                                                                                                                                                                                                                                      |
| position              | no             | `5`       | 1-9 grid, same as add-page-numbers (1 = top-left, 5 = center, 9 = bottom-right)                                                                                                                                                                              |
| overrideX / overrideY | no             | `-1`      | Explicit coordinates, used only when both are `>= 0`; otherwise `position` decides                                                                                                                                                                           |
| customMargin          | no             | `medium`  | `small` / `medium` / `large` / `x-large`                                                                                                                                                                                                                     |
| customColor           | no             | `#d3d3d3` | Hex color of text stamps                                                                                                                                                                                                                                     |

### POST /misc/update-metadata

| Field                                                    | Required | Default | Description                                                                                                                                                                                                                        |
| -------------------------------------------------------- | -------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| fileInput                                                | yes      | —       | Input PDF                                                                                                                                                                                                                          |
| keepOmitted                                              | no       | `false` | `true` keeps the standard fields you don't send; `false` removes them (see below)                                                                                                                                                  |
| deleteAll                                                | no       | `false` | `true` clears the entries of the document info dictionary (the dictionary itself stays) and removes the document-level XMP (catalog `/Metadata`, `/PieceInfo`), ignoring the other fields. XMP attached to pages or images remains |
| title / author / subject / keywords / creator / producer | no       | —       | Metadata fields                                                                                                                                                                                                                    |
| creationDate / modificationDate                          | no       | —       | Format: `yyyy/MM/dd HH:mm:ss`                                                                                                                                                                                                      |
| trapped                                                  | no       | —       | `True` / `False` / `Unknown`                                                                                                                                                                                                       |

Field updates are written to the document info dictionary only; existing
document-level XMP keeps its old values unless `deleteAll=true`. Send
`keepOmitted=true` to change only some fields. With the default
`keepOmitted=false`, every standard field you omit (dates and Trapped
included) is removed from the document even with `deleteAll=false`.

---

## Security

| Endpoint                         | Key fields                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /security/add-password`    | `fileInput`, `password` (opening password; empty = restrictions only), `ownerPassword` (non-empty and different from `password`; without it the `prevent*` restrictions don't hold, because the opening password — or anyone, if that is empty too — gets full permissions), `keyLength` (`40`/`128`/`256`, default `256`), `preventPrinting`, `preventPrintingFaithful`, `preventModify`, `preventExtractContent`, `preventExtractForAccessibility`, `preventFillInForm`, `preventAssembly`, `preventModifyAnnotations` (each omitted one = allowed). For an already encrypted source: `sourcePassword` (a password that opens it with owner access) and `preserveExisting=true` (keep its passwords and replace its restrictions with the `prevent*` sent — resend every restriction to keep). Omit `ownerPassword` (or send it empty) to keep the existing permissions password; sending it replaces that password, and the existing opening password must then be in `password` or `sourcePassword` |
| `POST /security/remove-password` | `fileInput`, `password`. With `password` alone, the opening password is removed, but a PDF that also had restrictions is re-protected with a new random permissions password (the original one is lost), so the restrictions stay. `removeAll=true` removes every password and restriction (needs the permissions password in `password` or `sourcePassword` when the server honors owner passwords — the default). Selective removal keeps the other password: to remove only the opening password, send it as `password` and the permissions password as `sourcePassword`; to remove only the permissions password (its restrictions go with it), send it as `ownerPassword` and the opening password to keep as `retainedOpeningPassword`                                                                                                                                                                                                                                                            |
| `POST /security/add-watermark`   | `fileInput`, `watermarkType` (`text`/`image`), `watermarkText`/`watermarkImage`, `alphabet`, `fontSize`, `rotation`, `opacity`, `widthSpacer`, `heightSpacer`, `customColor`, `convertPDFToImage`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |

Other security endpoints: `/security/cert-sign` (certificate signing),
`/security/redact` + `/security/auto-redact` + `/security/redact-execute`
(manual/automatic redaction), `/security/sanitize-pdf` (JS removal),
`/security/remove-cert-sign`, `/security/timestamp-pdf`,
`/security/validate-signature`, `/security/verify-pdf`,
`/security/get-info-on-pdf`, `/security/accessibility-report`,
`/security/validate-compliance`, and a hardware-token / multi-party signing
family under `/security/cert-sign/…` (`hardware/capabilities`,
`hardware/pkcs11-certificates`, `hardware/windows-certificates`, `sessions`,
`sign-requests`, `validate-certificate`). There is no PDF-compare endpoint in the
API (the web UI's Compare tool isn't exposed here).

---

## Analysis

| Endpoint                             | Response                                                     |
| ------------------------------------ | ------------------------------------------------------------ |
| `POST /analysis/page-count`          | `{ "pageCount": 1 }` — a JSON object, **not** a bare integer |
| `POST /analysis/basic-info`          | `{ "pageCount": 1, "pdfVersion": 1.4, "fileSize": 254 }`     |
| `POST /analysis/document-properties` | Title, author, creator, dates, etc.                          |
| `POST /analysis/security-info`       | Security/encryption information                              |
| `POST /analysis/font-info`           | Embedded font information                                    |
| `POST /analysis/form-fields`         | Form field information                                       |
| `POST /analysis/page-dimensions`     | Per-page dimensions                                          |
| `POST /analysis/annotation-info`     | Annotation details                                           |

---

## System

```json
{ "version": "3.5.0", "status": "UP" }
```

`GET /info/status` and `GET /info/health` (mirrors `/status`) return the JSON
above. **`GET /info/uptime` returns plain text, not JSON** (e.g. `0d 8h 56m 18s`).

---

## Source of truth

Stirling-PDF does not check an OpenAPI/Swagger file into the repo — it's
generated via `./gradlew :stirling-pdf:generateOpenApiDocs` and published to
SwaggerHub (org "Frooodle", API "Stirling-PDF") on every push to `main`. That
listing, or a live instance's own `/swagger-ui/index.html`, is more current
than this hand-maintained doc if anything drifts again.
