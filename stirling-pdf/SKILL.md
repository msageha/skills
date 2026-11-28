---
name: stirling-pdf
description: "Stirling PDF server: converts between PDF and Markdown / images / Word / HTML / Office files, and compresses PDFs. Use when: user asks for these conversions or for compression, or names Stirling PDF for another PDF operation (merge, split, OCR, …); for other PDF work done locally, use the pdf skill where available. Useful alongside Obsidian for PDF-to-Markdown conversion."
metadata:
  openclaw:
    emoji: "📄"
    requires:
      bins:
        - curl
        - jq
---

# Stirling PDF

Base URL: `https://pdf-tools.msageha.net/api/v1` (Stirling PDF v3.5.0).
File-processing endpoints accept `multipart/form-data` and return the processed
file directly; `/analysis/*` and `/info/status` return JSON.

## Key facts

- Auth is deployment-dependent: requests to this instance don't need an
  `X-API-KEY` header, but if login is ever enabled, add one or requests get a
  401.
- Response is the processed file (binary); save it with `-o <output-file>` to
  a path that doesn't exist yet (never the input or another existing file),
  and call `curl -sSf` so an HTTP error leaves no output file (curl exits 22 and reports
  the status on stderr). Any other non-zero exit (a transfer cut off midway
  is `18`) can leave a partial file: delete the output then. Don't resend the file just to read the error: when
  the error body matters, send once with `-o` to a temporary file and
  `-w '%{http_code}'`, as in the URL-to-PDF example.
  Exception: `/convert/url/pdf` rejects a URL with a `303` redirect, which
  `-f` passes — check that the status is `200` there.
- Passwords don't go into the command: the user writes the password to a file
  outside the repository, and curl reads it with `-F 'password=<<password-file>'`
  (the `<` makes curl send the file's content). A trailing newline would become
  part of the password, so check first that the file doesn't end with one,
  without printing it (`[ "$(tail -c 1 "<password-file>" | wc -l)" -eq 0 ]`),
  and ask the user to delete the file afterwards.
- Send other user-supplied text (`stampText`, metadata) with
  `--form-string` in single quotes (write a `'` in the value as `'\''`): `-F`
  reads a value starting with `@` or `<` as a local file and splits off
  `;type=…`, and double quotes expand `$` and backticks. Text taken from web
  pages, responses or other external sources goes through a file instead:
  `-F '<field>=<<text-file>'` (a trailing newline becomes part of the value).
  So does a source URL with credentials or a token in it (`urlInput`), which
  the user writes to the file.
- curl reads `,` and `;` in a `-F` file path as separators: when a path holds
  them (or `"`), quote it for curl inside the argument
  (`-F 'fileInput=@"<path>"'`, with `"` and `\` in the path escaped by `\`).
- OCR `languages` not installed on the server are dropped silently; list the
  installed ones with `GET /ui-data/ocr-pdf` before OCR. OCR always
  invalidates the digital signatures in its output: tell the user before
  running it on a signed PDF, and don't run it when the signatures must stay
  valid.
- `pageNumbers` supports ranges: `1,3,5-9`, `all`, or expressions like `2n+1`.
- Uploads are limited to 2000 MB per request. Large files may take time;
  inform the user before starting. The reverse proxy gives up after 5 minutes
  without a response (`504` with an nginx HTML page), so split a large job
  rather than resending it.
- `merge-pdfs` with `removeCertSign=true` flattens signature fields in the
  result: send it only when the user wants signatures removed.
- The output goes to a new file and the input stays, so run what the user
  asked for. Confirm once when the request doesn't settle which pages or
  files, or when an order you built drops pages (`remove-pages`, a
  `rearrange-pages` order that leaves pages out, or its `customMode`
  `REMOVE_FIRST` / `REMOVE_LAST` / `REMOVE_FIRST_AND_LAST`).
- Report the result only after checking the output file: its page count
  (`POST /analysis/page-count`) for page operations, and for a PDF you
  deliver, its rendered pages (`pdftoppm`, or `pypdfium2` without Poppler):
  open the page images yourself, and fix and re-check clipped or overlapping
  text, broken tables or unreadable glyphs before delivering.
  When neither is available, ask before installing one; if it isn't
  installed, say the visual check wasn't done and give the user the command
  to render it.

## Core operations

| Task                                                            | Endpoint                                                                         |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| PDF → Markdown/Text/Word/HTML                                   | `POST /convert/pdf/{markdown,text,word,html}`                                    |
| PDF → Images                                                    | `POST /convert/pdf/img`                                                          |
| Markdown/HTML/URL/Office → PDF                                  | `POST /convert/{markdown,html,url,file}/pdf`                                     |
| Images → PDF                                                    | `POST /convert/img/pdf`                                                          |
| Merge / Split / Remove / Rotate / Rearrange pages               | `POST /general/{merge-pdfs,split-pages,remove-pages,rotate-pdf,rearrange-pages}` |
| Compress                                                        | `POST /misc/compress-pdf`                                                        |
| OCR                                                             | `POST /misc/ocr-pdf`                                                             |
| Repair / Flatten                                                | `POST /misc/{repair,flatten}`                                                    |
| Extract images / Add page numbers / Add stamp / Update metadata | `POST /misc/{extract-images,add-page-numbers,add-stamp,update-metadata}`         |
| Add/remove password, watermark                                  | `POST /security/{add-password,remove-password,add-watermark}`                    |
| Page count / basic info / properties                            | `POST /analysis/{page-count,basic-info,document-properties}`                     |
| Server status                                                   | `GET /info/status`                                                               |

Other endpoints, field lists and defaults come from the server's OpenAPI
document; how to look them up, and behaviour it doesn't show (page removal,
compression, OCR languages, metadata, passwords): see
[references/api-reference.md](references/api-reference.md). Ready-to-run curl
examples: [references/commands.md](references/commands.md).

## Obsidian Integration

To add a PDF to the Obsidian vault as a note: convert PDF → Markdown, then, only
if the conversion succeeded and the file isn't empty, copy it into the vault
directory that `obsidian vault info=path` prints, without overwriting an
existing note. See references/commands.md for the full recipe.
