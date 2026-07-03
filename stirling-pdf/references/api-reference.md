# Stirling PDF API Reference

Base URL: `http://172.16.1.101:18085`
**Stirling PDF v2.14.0**. Base path is `/api/v1` — no `/api/v2` exists.
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

| Field | Type | Description |
|-------|------|-------------|
| fileInput | binary | The input file (upload via `-F "fileInput=@file.pdf"`) |
| fileId | string | Server-side file ID (alternative to fileInput) |

### Page Selection (`pageNumbers`)

- `all` — all pages
- `1,3,5` — specific pages
- `1-5` — range
- `1,3,5-9` — mixed
- `2n+1` / `2n` — expression (odd / even pages)

---

## Conversion Endpoints

### POST /api/v1/convert/pdf/markdown

Convert PDF to Markdown. Field: `fileInput` (required). No extra params.

### POST /api/v1/convert/pdf/text

Convert PDF to plain text or RTF.

| Field | Required | Description |
|-------|----------|-------------|
| fileInput | yes | Input PDF |
| outputFormat | yes | `txt` or `rtf` |

### POST /api/v1/convert/pdf/img

Convert PDF pages to images.

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| fileInput | yes | — | Input PDF |
| pageNumbers | yes | `all` | Pages to convert |
| imageFormat | yes | `png` | `png` / `jpeg` / `jpg` / `gif` / `webp` |
| singleOrMultiple | yes | `multiple` | `single` (all pages in one image) / `multiple` |
| colorType | yes | `color` | `color` / `greyscale` / `blackwhite` |
| dpi | yes | `300` | Resolution in DPI |
| includeAnnotations | no | `false` | Include annotations |

**Response:** Image file or ZIP (if multiple).

### Other conversions

| Endpoint | Key fields |
|---|---|
| `POST /convert/pdf/word` | `fileInput` |
| `POST /convert/pdf/html` | `fileInput` |
| `POST /convert/markdown/pdf` | `fileInput` |
| `POST /convert/html/pdf` | `fileInput`, `zoom` (default `1`) |
| `POST /convert/url/pdf` | `urlInput` |
| `POST /convert/img/pdf` | `fileInput` (multiple), `fitOption` (`fillPage`/`fitDocumentToImage`/`maintainAspectRatio`, default `fillPage`), `colorType`, `autoRotate` |
| `POST /convert/file/pdf` | `fileInput` — Office→PDF via LibreOffice (.doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .csv, etc.) |

Other conversion endpoints, not detailed here but present in the API:
`/convert/pdf/pdfa`, `/convert/pdf/presentation`, `/convert/pdf/xml`,
`/convert/ebook/pdf`, `/convert/eml/pdf`, `/convert/svg/pdf`,
`/convert/pdf/epub`, `/convert/pdf/xlsx`, `/convert/pdf/csv`,
`/convert/pdf/video`, `/convert/pdf/vector`, `/convert/vector/pdf`,
`/convert/cbz/pdf` ↔ `/convert/pdf/cbz`, `/convert/cbr/pdf` ↔ `/convert/pdf/cbr`,
and a job-based `/convert/pdf/text-editor` family.

---

## Page Operations

| Endpoint | Key fields |
|---|---|
| `POST /general/merge-pdfs` | `fileInput` (multiple), `sortType` (`orderProvided`/`byFileName`/`byDateModified`/`byDateCreated`/`byPDFTitle`, default `orderProvided`), `removeCertSign` (default `true`), `generateToc` (default `false`) |
| `POST /general/split-pages` | `fileInput`, `pageNumbers` (default `all`) → ZIP |
| `POST /general/remove-pages` | `fileInput`, `pageNumbers` (required) |
| `POST /general/rotate-pdf` | `fileInput`, `angle` (`0`/`90`/`180`/`270`, default `90`) |
| `POST /general/rearrange-pages` | `fileInput`, `pageNumbers` (new order, e.g. `3,1,2,4`) |

Other page-operation endpoints: `/general/split-by-size-or-count`,
`/general/split-pdf-by-chapters` (note the `pdf-` infix), `/general/pdf-to-single-page`,
`/general/scale-pages`, `/general/overlay-pdfs` (plural), `/general/crop`,
`/general/booklet-imposition`, `/general/edit-table-of-contents`,
`/general/extract-bookmarks`, `/general/multi-page-layout`,
`/general/split-for-poster-print`, `/general/edit-text`,
`/general/split-pdf-by-sections`.

---

## Optimization & Repair

### POST /api/v1/misc/compress-pdf

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| fileInput | yes | — | Input PDF |
| optimizeLevel | yes | `5` | 1-9 (higher = more compression, lower quality) |
| expectedOutputSize | yes | `25KB` | Target size (e.g. `100MB`, `500KB`) |
| linearize | yes | `false` | Optimize for web viewing |
| normalize | yes | `false` | Normalize content |
| grayscale | yes | `false` | Convert to grayscale |
| lineArt / lineArtThreshold / lineArtEdgeLevel | no | — | Line-art-aware compression tuning (added in v2.x) |

### POST /api/v1/misc/ocr-pdf

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| fileInput | yes | — | Input PDF |
| languages | yes | `["eng"]` | Language codes — **not a fixed list**: derived at runtime from whichever Tesseract `.traineddata` files are present in the deployed image (varies by full/lite/ultra-lite variant) |
| ocrType | yes | — | `skip-text` (skip existing text) / `force-ocr` (redo all) / `Normal` |
| ocrRenderType | yes | `hocr` | `hocr` (overlay text) / `sandwich` (hidden text layer) — server rejects any other value |
| sidecar | no | `false` | Output text as sidecar file |
| deskew | no | `false` | Deskew skewed pages |
| clean | no | `false` | Clean input before OCR |
| cleanFinal | no | `false` | Clean final output |
| removeImagesAfter | no | `false` | Remove images from output |

### POST /api/v1/misc/repair / POST /api/v1/misc/flatten

`repair`: `fileInput` only. `flatten`: `fileInput`, `flattenOnlyForms` (`true`
= forms only, `false` = full page rasterize, default `false`).

Other misc endpoints: `/misc/remove-blanks`, `/misc/auto-rename`,
`/misc/add-comments`, `/misc/add-attachments`, `/misc/extract-attachments`,
`/misc/list-attachments`, `/misc/rename-attachment`, `/misc/delete-attachment`,
`/misc/auto-split-pdf`, `/misc/decompress-pdf`, `/misc/extract-image-scans`,
`/misc/add-image`, `/misc/remove-image-pdf`, `/misc/replace-invert-pdf`,
`/misc/scanner-effect`, `/misc/unlock-pdf-forms`, `/misc/show-javascript`.

---

## Annotations & Metadata

### POST /api/v1/misc/extract-images

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| fileInput | yes | — | Input PDF |
| format | yes | `png` | `png` / `jpeg` / `gif` |

`allowDuplicates` **removed** — it's commented-out dead code in the current
source (`PDFExtractImagesRequest.java`), do not send it.

### POST /api/v1/misc/add-page-numbers

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| fileInput | yes | — | Input PDF |
| pageNumbers | yes | `all` | Pages to number |
| position | yes | `8` | 1-9 grid position (8 = bottom-center) |
| fontSize | yes | `12` | Font size |
| fontType | yes | — | `helvetica` / `courier` / `times` |
| fontColor | no | `#000000` | Hex color |
| startingNumber | yes | `1` | Starting page number |
| customText | no | `{n}` | `{n}` = page, `{total}` = total pages, `{filename}` = filename |
| customMargin | no | `medium` | `small` / `medium` / `large` / `x-large` |
| pagesToNumber | no | `all` | Which pages get numbers |

Position grid: `7=top-left 8=top-center 9=top-right / 4=mid-left 5=mid-center 6=mid-right / 1=bot-left 2=bot-center 3=bot-right`.

### POST /api/v1/misc/add-stamp

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| fileInput | yes | — | Input PDF |
| pageNumbers | yes | `all` | Target pages |
| stampType | yes | — | `text` or `image` |
| stampText | no | — | Stamp text (for type=text) |
| stampImage | no | — | Stamp image (for type=image) |
| alphabet | no | `roman` | `roman` / `arabic` / `japanese` / `korean` / `chinese` |
| fontSize | yes | `30` | Font/image size |
| rotation | yes | `0` | Rotation in degrees |
| opacity | yes | `0.5` | Opacity (0.0-1.0) |
| position | yes | `5` | 1-9 grid position |
| customColor | no | `#d3d3d3` | Stamp color |

### POST /api/v1/misc/update-metadata

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| fileInput | yes | — | Input PDF |
| deleteAll | yes | `false` | Delete all metadata first |
| title / author / subject / keywords / creator / producer | no | — | Metadata fields |
| creationDate / modificationDate | no | — | Format: `yyyy/MM/dd HH:mm:ss` |

---

## Security

| Endpoint | Key fields |
|---|---|
| `POST /security/add-password` | `fileInput`, `password`, `ownerPassword`, `keyLength` (`40`/`128`/`256`, default `256`), `preventPrinting`, `preventModify`, `preventExtractContent`, `preventFillInForm`, `preventAssembly`, `preventModifyAnnotations` |
| `POST /security/remove-password` | `fileInput`, `password` (required) |
| `POST /security/add-watermark` | `fileInput`, `watermarkType` (`text`/`image`), `watermarkText`/`watermarkImage`, `alphabet`, `fontSize`, `rotation`, `opacity`, `widthSpacer`, `heightSpacer`, `customColor`, `convertPDFToImage` |

Other security endpoints: `/security/cert-sign` (certificate signing),
`/security/redact` + `/security/auto-redact` + `/security/redact-execute`
(manual/automatic redaction), `/security/sanitize-pdf` (JS removal),
`/security/remove-cert-sign`, `/security/timestamp-pdf`,
`/security/validate-signature`, `/security/verify-pdf`,
`/security/get-info-on-pdf`, and a hardware-token signing family:
`/security/capabilities`, `/security/windows-certificates`. There is no
PDF-compare feature.

---

## Analysis

| Endpoint | Response |
|---|---|
| `POST /analysis/page-count` | `{ "pageCount": 1 }` — a JSON object, **not** a bare integer |
| `POST /analysis/basic-info` | `{ "pageCount": 1, "pdfVersion": 1.4, "fileSize": 254 }` |
| `POST /analysis/document-properties` | Title, author, creator, dates, etc. |
| `POST /analysis/security-info` | Security/encryption information |
| `POST /analysis/font-info` | Embedded font information |
| `POST /analysis/form-fields` | Form field information |
| `POST /analysis/page-dimensions` | Per-page dimensions |
| `POST /analysis/annotation-info` | Annotation details |

---

## System

```json
{ "version": "2.14.0", "status": "UP" }
```

`GET /api/v1/info/status` and `GET /api/v1/info/health` (mirrors `/status`)
return the JSON above. **`GET /api/v1/info/uptime` returns plain text, not
JSON** (e.g. `0d 8h 56m 18s`). Metrics endpoints (`/load`, `/requests`,
`/wau`, etc.) exist but aren't documented here.

---

## Source of truth

Stirling-PDF does not check an OpenAPI/Swagger file into the repo — it's
generated via `./gradlew :stirling-pdf:generateOpenApiDocs` and published to
SwaggerHub (org "Frooodle", API "Stirling-PDF") on every push to `main`. That
listing, or a live instance's own `/swagger-ui/index.html`, is more current
than this hand-maintained doc if anything drifts again.
