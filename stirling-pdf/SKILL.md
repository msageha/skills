---
name: stirling-pdf
description: "Stirling PDF document processing. Use when: user asks to convert, merge, split, compress, OCR, or manipulate PDF files. Also for converting between PDF and Markdown/images/Word/HTML. Useful alongside Obsidian for PDF-to-Markdown conversion."
metadata:
  openclaw:
    emoji: "📄"
    requires:
      bins:
        - curl
---

# Stirling PDF

Base URL: `https://pdf-tools.msageha.net/api/v1` (Stirling PDF v2.14.0). All
endpoints accept `multipart/form-data` and return the processed file directly.

## Key facts

- Auth is deployment-dependent: requests to this instance don't need an
  `X-API-KEY` header, but if login is ever enabled, add one or requests get a
  401.
- Response is the processed file (binary); save with `-o output.ext`.
- `pageNumbers` supports ranges: `1,3,5-9`, `all`, or expressions like `2n+1`.
- Large files may take time; inform the user before starting.
- Confirm before destructive operations (removing pages, adding passwords).

## Core operations

| Task | Endpoint |
|---|---|
| PDF → Markdown/Text/Word/HTML | `POST /convert/pdf/{markdown,text,word,html}` |
| PDF → Images | `POST /convert/pdf/img` |
| Markdown/HTML/URL/Office → PDF | `POST /convert/{markdown,html,url,file}/pdf` |
| Images → PDF | `POST /convert/img/pdf` |
| Merge / Split / Remove / Rotate / Rearrange pages | `POST /general/{merge-pdfs,split-pages,remove-pages,rotate-pdf,rearrange-pages}` |
| Compress | `POST /misc/compress-pdf` |
| OCR | `POST /misc/ocr-pdf` |
| Repair / Flatten | `POST /misc/{repair,flatten}` |
| Extract images / Add page numbers / Add stamp / Update metadata | `POST /misc/{extract-images,add-page-numbers,add-stamp,update-metadata}` |
| Add/remove password, watermark | `POST /security/{add-password,remove-password,add-watermark}` |
| Page count / basic info / properties | `POST /analysis/{page-count,basic-info,document-properties}` |
| Server status | `GET /info/status` |

Full field lists, defaults, and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).

## Obsidian Integration

To add a PDF to the Obsidian vault as a note: convert PDF → Markdown, then
`obsidian-cli create "Notes/<name>" --content "$(cat output.md)"`. See
references/commands.md for the full recipe.
