# Stirling PDF API Reference

Base URL: `https://pdf-tools.msageha.net/api/v1` (**Stirling PDF v3.0.0**;
no `/api/v2` exists). Paths below are relative to it.
All processing endpoints accept `multipart/form-data` and return the
processed file as a binary response.

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

Defaults in the tables below are the OpenAPI `default` values. Not all of them
are applied when a field is omitted (only those backed by a field initializer or
a controller fallback); where the tables say a default isn't applied, send the
field explicitly.

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
| pageNumbers        | yes      | `all`      | Pages to convert                               |
| imageFormat        | yes      | `png`      | `png` / `jpeg` / `jpg` / `gif` / `webp`        |
| singleOrMultiple   | yes      | `multiple` | `single` (all pages in one image) / `multiple` |
| colorType          | yes      | `color`    | `color` / `greyscale` / `blackwhite`           |
| dpi                | yes      | `300`      | Resolution in DPI                              |
| includeAnnotations | no       | `false`    | Include annotations                            |

**Response:** Image file or ZIP (if multiple).

### Other conversions

| Endpoint                     | Key fields                                                                                                                                                     |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /convert/pdf/word`     | `fileInput`, `outputFormat` (`doc` / `docx` / `odt`, required)                                                                                                 |
| `POST /convert/pdf/html`     | `fileInput`                                                                                                                                                    |
| `POST /convert/markdown/pdf` | `fileInput`                                                                                                                                                    |
| `POST /convert/html/pdf`     | `fileInput`, `zoom` (default `1`)                                                                                                                              |
| `POST /convert/url/pdf`      | `urlInput`                                                                                                                                                     |
| `POST /convert/img/pdf`      | `fileInput` (multiple), `fitOption` (`fillPage`/`fitDocumentToImage`/`fitDocumentToPage`/`maintainAspectRatio`, default `fillPage`), `colorType`, `autoRotate` |
| `POST /convert/file/pdf`     | `fileInput` — Office→PDF via LibreOffice (.doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .csv, etc.)                                                 |

Other conversion endpoints, not detailed here but present in the API:
`/convert/pdf/pdfa`, `/convert/pdf/presentation`, `/convert/pdf/xml`,
`/convert/ebook/pdf`, `/convert/eml/pdf`, `/convert/svg/pdf`,
`/convert/pdf/epub`, `/convert/pdf/xlsx`, `/convert/pdf/csv`,
`/convert/pdf/ua`, `/convert/pdf/vector`, `/convert/vector/pdf`,
`/convert/cbz/pdf` ↔ `/convert/pdf/cbz`, `/convert/cbr/pdf` ↔ `/convert/pdf/cbr`,
and a job-based `/convert/pdf/text-editor` family.

---

## Page Operations

| Endpoint                        | Key fields                                                                                                                                                                                                                                                                                                                   |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /general/merge-pdfs`      | `fileInput` (multiple), `sortType` (`orderProvided`/`byFileName`/`byDateModified`/`byDateCreated`/`byPDFTitle`, default `orderProvided`), `removeCertSign` (default `true`), `generateToc` (default `false`)                                                                                                                 |
| `POST /general/split-pages`     | `fileInput`, `pageNumbers` (default `all`) → ZIP                                                                                                                                                                                                                                                                             |
| `POST /general/remove-pages`    | `fileInput`, `pageNumbers` (required)                                                                                                                                                                                                                                                                                        |
| `POST /general/rotate-pdf`      | `fileInput`, `angle` (`0`/`90`/`180`/`270`, required)                                                                                                                                                                                                                                                                        |
| `POST /general/rearrange-pages` | `fileInput`, `pageNumbers` (new order, e.g. `3,1,2,4`), `customMode` (optional preset instead of an explicit order: `REVERSE_ORDER` / `DUPLEX_SORT` / `BOOKLET_SORT` / `SIDE_STITCH_BOOKLET_SORT` / `ODD_EVEN_SPLIT` / `REMOVE_FIRST` / `REMOVE_LAST` / `REMOVE_FIRST_AND_LAST` / `DUPLICATE`; `CUSTOM` = use `pageNumbers`) |

Other page-operation endpoints: `/general/split-by-size-or-count`,
`/general/split-pdf-by-chapters` (note the `pdf-` infix), `/general/pdf-to-single-page`,
`/general/scale-pages`, `/general/overlay-pdfs` (plural), `/general/crop`,
`/general/booklet-imposition`, `/general/edit-table-of-contents`,
`/general/extract-bookmarks`, `/general/multi-page-layout`,
`/general/split-for-poster-print`, `/general/edit-text`,
`/general/split-pdf-by-sections`, `/general/remove-image-pdf` (moved here from
`/misc` in 3.x), plus the async job/file API (`/general/job/{jobId}`,
`/general/files/{fileId}`).

---

## Optimization & Repair

### POST /misc/compress-pdf

| Field                                         | Required | Default              | Description                                                |
| --------------------------------------------- | -------- | -------------------- | ---------------------------------------------------------- |
| fileInput                                     | yes      | —                    | Input PDF                                                  |
| optimizeLevel                                 | yes      | `5`                  | 1-9 (higher = more compression, lower quality)             |
| expectedOutputSize                            | yes      | `25KB`               | Target size (e.g. `100MB`, `500KB`)                        |
| linearize                                     | yes      | `false`              | Optimize for web viewing                                   |
| normalize                                     | yes      | `false`              | Normalize content                                          |
| grayscale                                     | yes      | `false`              | Convert to grayscale                                       |
| lineArt / lineArtThreshold / lineArtEdgeLevel | no       | `false` / `55` / `1` | Line-art-aware compression tuning (`lineArtEdgeLevel` 1-3) |

### POST /misc/ocr-pdf

| Field             | Required | Default   | Description                                                                                                                                                                        |
| ----------------- | -------- | --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| fileInput         | yes      | —         | Input PDF                                                                                                                                                                          |
| languages         | yes      | `["eng"]` | Language codes — **not a fixed list**: derived at runtime from whichever Tesseract `.traineddata` files are present in the deployed image (varies by full/lite/ultra-lite variant) |
| ocrType           | yes      | —         | `skip-text` (skip existing text) / `force-ocr` (redo all) / `Normal`                                                                                                               |
| ocrRenderType     | yes      | `hocr`    | `hocr` (overlay text) / `sandwich` (hidden text layer) — server rejects any other value                                                                                            |
| sidecar           | no       | `false`   | Output text as sidecar file                                                                                                                                                        |
| rotatePages       | no       | `false`   | Auto-correct page orientation (90/180/270) with Tesseract OSD                                                                                                                      |
| deskew            | no       | `false`   | Deskew skewed pages                                                                                                                                                                |
| clean             | no       | `false`   | Clean input before OCR                                                                                                                                                             |
| cleanFinal        | no       | `false`   | Clean final output                                                                                                                                                                 |
| removeImagesAfter | no       | `false`   | Remove images from output                                                                                                                                                          |

### POST /misc/repair / POST /misc/flatten

`repair`: `fileInput` only. `flatten`: `fileInput`, `flattenOnlyForms` (`true`
= forms only, `false` = full page rasterize, default `false`), `renderDpi`
(optional DPI for the full-page rasterize).

Other misc endpoints: `/misc/remove-blanks`, `/misc/auto-rename`,
`/misc/add-comments`, `/misc/add-attachments`, `/misc/extract-attachments`,
`/misc/list-attachments`, `/misc/rename-attachment`, `/misc/delete-attachment`,
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

`allowDuplicates` **removed** — it's commented-out dead code in the current
source (`PDFExtractImagesRequest.java`), do not send it.

### POST /misc/add-page-numbers

| Field          | Required | Default   | Description                                                        |
| -------------- | -------- | --------- | ------------------------------------------------------------------ |
| fileInput      | yes      | —         | Input PDF                                                          |
| pageNumbers    | yes      | `all`     | Pages to number                                                    |
| position       | yes      | `8`       | 1-9 grid position (8 = bottom-center)                              |
| fontSize       | yes      | —         | Font size (OpenAPI shows `12`, not applied when omitted)           |
| fontType       | yes      | —         | `helvetica` / `courier` / `times`                                  |
| fontColor      | no       | `#000000` | Hex color                                                          |
| zeroPad        | no       | `0`       | Zero-padding width (Bates stamping); `0` disables                  |
| startingNumber | yes      | —         | Starting page number (OpenAPI shows `1`, not applied when omitted) |
| customText     | no       | `{n}`     | `{n}` = page, `{total}` = total pages, `{filename}` = filename     |
| customMargin   | no       | `medium`  | `small` / `medium` / `large` / `x-large`                           |
| pagesToNumber  | no       | `all`     | Which pages get numbers                                            |

Position grid: `1=top-left 2=top-center 3=top-right / 4=mid-left 5=mid-center 6=mid-right / 7=bot-left 8=bot-center 9=bot-right`.

### POST /misc/add-stamp

| Field                 | Required  | Default | Description                                                                                                                                                                                                                                          |
| --------------------- | --------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| fileInput             | yes       | —       | Input PDF                                                                                                                                                                                                                                            |
| pageNumbers           | yes       | `all`   | Target pages                                                                                                                                                                                                                                         |
| stampType             | yes       | —       | `text` or `image`                                                                                                                                                                                                                                    |
| stampText             | no        | —       | Stamp text (for type=text). Omitted → empty stamp; the OpenAPI default `Stirling Software` is not applied                                                                                                                                            |
| stampImage            | no        | —       | Stamp image (for type=image)                                                                                                                                                                                                                         |
| alphabet              | no        | `roman` | `roman` / `arabic` / `japanese` / `korean` / `chinese` / `thai`                                                                                                                                                                                      |
| fontSize              | yes       | —       | Font size (text) / image height. Text stamps fall back to 40 when omitted or `0`; image stamps get height 0 — always send it for images                                                                                                              |
| rotation              | yes       | —       | Rotation in degrees (OpenAPI shows `0`, not applied when omitted)                                                                                                                                                                                    |
| opacity               | yes       | —       | Opacity (0.0-1.0) (OpenAPI shows `0.5`, not applied when omitted)                                                                                                                                                                                    |
| position              | yes       | —       | 1-9 grid (OpenAPI shows `8`, not applied when omitted), same as add-page-numbers (1 = top-left, 8 = bottom-center; the OpenAPI description says the reverse, but the 2.x StampController placed 1-3 at the top — verify on 3.x if placement matters) |
| overrideX / overrideY | yes       | —       | Explicit coordinates. Both `>= 0` → they replace `position`; omitted fields are `0`, i.e. the stamp lands at the bottom-left corner — send `-1` for both to use `position`                                                                           |
| customMargin          | yes       | —       | `small` / `medium` / `large` / `x-large`. Omitted → server error (the controller lower-cases it without a null check); the OpenAPI default `medium` is not applied                                                                                   |
| customColor           | text: yes | —       | Hex color for text stamps, e.g. `#d3d3d3`. OpenAPI marks it optional with default `#d3d3d3`, but a text stamp without it fails with a server error; image stamps ignore it                                                                           |

### POST /misc/update-metadata

| Field                                                    | Required | Default | Description                                                                                                                |
| -------------------------------------------------------- | -------- | ------- | -------------------------------------------------------------------------------------------------------------------------- |
| fileInput                                                | yes      | —       | Input PDF                                                                                                                  |
| deleteAll                                                | yes      | `false` | Delete all metadata first                                                                                                  |
| title / author / subject / keywords / creator / producer | no       | —       | Metadata fields                                                                                                            |
| creationDate / modificationDate                          | no       | —       | Format: `yyyy/MM/dd HH:mm:ss`                                                                                              |
| trapped                                                  | no       | —       | `True` / `False` / `Unknown`. Omitted → the existing Trapped entry is removed (the OpenAPI default `False` is not applied) |

The controller writes every standard field from the request, so a standard
field you omit is **removed** from the document (PDFBox drops entries set to
`null`) even with `deleteAll=false`. To keep existing values, resend them:
`POST /analysis/document-properties` returns title / author / subject /
keywords / creator / producer, but its dates are not in the
`yyyy/MM/dd HH:mm:ss` form this endpoint requires (convert them first, or they
are dropped), and it doesn't return Trapped at all — pass `trapped` yourself
if the document has one.

---

## Security

| Endpoint                         | Key fields                                                                                                                                                                                                                                                                            |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /security/add-password`    | `fileInput`, `password`, `ownerPassword`, `keyLength` (`40`/`128`/`256`, default `256`), `preventPrinting`, `preventPrintingFaithful`, `preventModify`, `preventExtractContent`, `preventExtractForAccessibility`, `preventFillInForm`, `preventAssembly`, `preventModifyAnnotations` |
| `POST /security/remove-password` | `fileInput`, `password` (required)                                                                                                                                                                                                                                                    |
| `POST /security/add-watermark`   | `fileInput`, `watermarkType` (`text`/`image`), `watermarkText`/`watermarkImage`, `alphabet`, `fontSize`, `rotation`, `opacity`, `widthSpacer`, `heightSpacer`, `customColor`, `convertPDFToImage`                                                                                     |

Other security endpoints: `/security/cert-sign` (certificate signing),
`/security/redact` + `/security/auto-redact` + `/security/redact-execute`
(manual/automatic redaction), `/security/sanitize-pdf` (JS removal),
`/security/remove-cert-sign`, `/security/timestamp-pdf`,
`/security/validate-signature`, `/security/verify-pdf`,
`/security/get-info-on-pdf`, `/security/accessibility-report`,
`/security/validate-compliance`, and a hardware-token / multi-party signing
family under `/security/cert-sign/…` (`hardware/capabilities`,
`hardware/pkcs11-certificates`, `hardware/windows-certificates`, `sessions`,
`sign-requests`, `validate-certificate`). There is no PDF-compare feature.

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
{ "version": "3.0.0", "status": "UP" }
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
