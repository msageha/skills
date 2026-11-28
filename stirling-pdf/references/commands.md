# Stirling PDF Command Recipes

Ready-to-run `curl` examples for common tasks. For other endpoints and for
request/response schemas, see [api-reference.md](api-reference.md): how to look
them up in the server's OpenAPI document, and what the document leaves out. Base URL: `https://pdf-tools.msageha.net/api/v1`.

The examples write to `"<output-file>"` for brevity. To deliver a result,
receive it into a temporary file instead and move it into place only after
curl exited 0, without overwriting: `(set -o noclobber; cat "$tmp" >"<output-file>")`,
as in the URL-to-PDF example (never the input file). A transfer cut off midway
leaves a partial temporary file, which is then just deleted. A `303` passes `-f`
with an exit of 0; only `/convert/url/pdf` answers with one, and its example
checks the status.

## PDF to Markdown (for Obsidian)

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/pdf/markdown" \
  -F "fileInput=@<input-file>" \
  -o "<output-file>"
```

## PDF to Text

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/pdf/text" \
  -F "fileInput=@<input-file>" \
  -F "outputFormat=txt" \
  -o "<output-file>"
```

## PDF to Images

```bash
# All pages as separate PNG files (returned as ZIP)
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/pdf/img" \
  -F "fileInput=@<input-file>" \
  -F "imageFormat=png" \
  -F "singleOrMultiple=multiple" \
  -F "colorType=color" \
  -F "dpi=300" \
  -F "pageNumbers=all" \
  -o "<output-file>"

# Single page as JPEG
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/pdf/img" \
  -F "fileInput=@<input-file>" \
  -F "imageFormat=jpeg" \
  -F "singleOrMultiple=single" \
  -F "colorType=color" \
  -F "dpi=300" \
  -F "pageNumbers=1" \
  -o "<output-file>"
```

## PDF to Word / HTML

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/pdf/word" \
  -F "fileInput=@<input-file>" \
  -F "outputFormat=docx" \
  -o "<output-file>"

curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/pdf/html" \
  -F "fileInput=@<input-file>" \
  -o "<output-file>"   # ZIP with the HTML and its assets
```

## Markdown / HTML / URL / Office to PDF

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/markdown/pdf" \
  -F "fileInput=@<input-file>" \
  -o "<output-file>"

curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/html/pdf" \
  -F "fileInput=@<input-file>" \
  -F "zoom=1" \
  -o "<output-file>"

# Internet URLs only: private network, loopback and .local hosts are rejected with a
# 303 redirect (Location: ...?error=error.urlNotReachable), which -f doesn't treat as an error
# noclobber makes the final redirect fail instead of overwriting an existing <output-file>
tmp=$(mktemp) || exit 1; trap 'rm -f "$tmp"' EXIT
code=$(curl -sS -X POST "https://pdf-tools.msageha.net/api/v1/convert/url/pdf" \
  --form-string 'urlInput=<url>' \
  -o "$tmp" -w '%{http_code}') && [ "$code" = 200 ] \
  && (set -o noclobber; cat "$tmp" >"<output-file>") \
  || { echo "conversion failed (HTTP ${code:-none}) or <output-file> exists"; exit 1; }

# Supports .doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .csv, etc.
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/file/pdf" \
  -F "fileInput=@<input-file>" \
  -o "<output-file>"
```

## Images to PDF

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/convert/img/pdf" \
  -F "fileInput=@<first-image>" \
  -F "fileInput=@<second-image>" \
  -F "fitOption=maintainAspectRatio" \
  -F "colorType=color" \
  -F "autoRotate=true" \
  -o "<output-file>"
```

## Merge / Split / Remove / Rotate / Rearrange Pages

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/general/merge-pdfs" \
  -F "fileInput=@<first-pdf>" \
  -F "fileInput=@<second-pdf>" \
  -F "sortType=orderProvided" \
  -o "<output-file>"

curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/general/split-pages" \
  -F "fileInput=@<input-file>" \
  -F "pageNumbers=1,3,5-9" \
  -o "<output-file>"   # split points: cut after pages 1, 3, 5, 6, 7, 8, 9

# Removing pages — unless the user named the pages to remove, confirm first
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/general/remove-pages" \
  -F "fileInput=@<input-file>" \
  -F "pageNumbers=2,4" \
  -o "<output-file>"

curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/general/rotate-pdf" \
  -F "fileInput=@<input-file>" \
  -F "angle=90" \
  -o "<output-file>"

# New order for a 4-page PDF. Pages not listed are dropped: check the page count first,
# and when the order you built leaves pages out, confirm with the user
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/general/rearrange-pages" \
  -F "fileInput=@<input-file>" \
  -F "pageNumbers=3,1,2,4" \
  -o "<output-file>"
```

## Compress

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/compress-pdf" \
  -F "fileInput=@<input-file>" \
  -F "optimizeLevel=5" \
  -o "<output-file>"
```

## OCR

Which `languages` work depends on the `.traineddata` files installed on the
server, and codes that aren't installed are dropped silently. Check that every
language to send is installed; if one the user needs is missing, say so
instead of running OCR without it.

```bash
# Installed languages
curl -sSf "https://pdf-tools.msageha.net/api/v1/ui-data/ocr-pdf" | jq -c .languages

# Japanese + English OCR, only if both are installed
set -o pipefail
curl -sSf "https://pdf-tools.msageha.net/api/v1/ui-data/ocr-pdf" \
  | jq -e '.languages | index("jpn") and index("eng")' >/dev/null \
  || { echo "jpn or eng not installed (or the list couldn't be read)"; exit 1; }
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/ocr-pdf" \
  -F "fileInput=@<input-file>" \
  -F "languages=jpn" \
  -F "languages=eng" \
  -F "ocrType=skip-text" \
  -F "ocrRenderType=hocr" \
  -o "<output-file>"

# Force OCR on all pages. With a single language, a missing one fails with 400 instead of being dropped
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/ocr-pdf" \
  -F "fileInput=@<input-file>" \
  -F "languages=jpn" \
  -F "ocrType=force-ocr" \
  -F "ocrRenderType=sandwich" \
  -F "deskew=true" \
  -F "clean=true" \
  -o "<output-file>"
```

## Repair / Flatten

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/repair" \
  -F "fileInput=@<input-file>" \
  -o "<output-file>"

# Flatten only forms
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/flatten" \
  -F "fileInput=@<input-file>" \
  -F "flattenOnlyForms=true" \
  -o "<output-file>"
```

## Extract Images

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/extract-images" \
  -F "fileInput=@<input-file>" \
  -F "format=png" \
  -o "<output-file>"
```

## Add Page Numbers

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/add-page-numbers" \
  -F "fileInput=@<input-file>" \
  -F "pagesToNumber=all" \
  -F "position=8" \
  -F "fontSize=12" \
  -F "fontType=helvetica" \
  -F "startingNumber=1" \
  --form-string 'customText={n}' \
  -o "<output-file>"
```

## Add Text Stamp

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/add-stamp" \
  -F "fileInput=@<input-file>" \
  -F "pageNumbers=all" \
  -F "stampType=text" \
  --form-string 'stampText=CONFIDENTIAL @date' \
  -F "fontSize=30" \
  -F "rotation=45" \
  -F "opacity=0.3" \
  -F "position=5" \
  -F "overrideX=-1" \
  -F "overrideY=-1" \
  -F "customMargin=medium" \
  -F "customColor=#d3d3d3" \
  -o "<output-file>"
```

## Update Metadata

`keepOmitted=true` keeps the fields you don't send; without it, every
standard field you omit is removed from the document info dictionary (XMP
metadata keeps its values).

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/update-metadata" \
  -F "fileInput=@<input-file>" \
  -F "keepOmitted=true" \
  --form-string 'title=<title>' \
  --form-string 'author=<author>' \
  --form-string 'subject=<subject>' \
  --form-string 'keywords=<keyword1>,<keyword2>' \
  -o "<output-file>"
```

## Add / Remove Password, Watermark

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/security/add-password" \
  -F "fileInput=@<input-file>" \
  -F 'password=<<password-file>' \
  -F "keyLength=256" \
  -o "<output-file>"

# Removes the opening password; if the PDF also had restrictions, they stay under a new
# random permissions password. To keep the original one, use selective removal
# (sourcePassword); to remove everything, add -F "removeAll=true" with the permissions password
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/security/remove-password" \
  -F "fileInput=@<input-file>" \
  -F 'password=<<password-file>' \
  -o "<output-file>"

curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/security/add-watermark" \
  -F "fileInput=@<input-file>" \
  -F "watermarkType=text" \
  --form-string 'watermarkText=DRAFT' \
  -F "fontSize=50" \
  -F "rotation=45" \
  -F "opacity=0.3" \
  -F "convertPDFToImage=false" \
  -o "<output-file>"
```

## Analysis

```bash
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/analysis/page-count" \
  -F "fileInput=@<input-file>"

curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/analysis/basic-info" \
  -F "fileInput=@<input-file>"

curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/analysis/document-properties" \
  -F "fileInput=@<input-file>"
```

## Server Status

```bash
curl -s "https://pdf-tools.msageha.net/api/v1/info/status" | jq .
```

## Obsidian Integration Workflow

```bash
# Convert PDF to Markdown, then copy it into the vault as Notes/<note-name>.md. The Obsidian
# CLI (`obsidian`, which starts the app if it isn't running) is used only for the vault's
# path: its `create` takes the note body as an argument with \n escapes, which would alter
# the Markdown.
md=$(mktemp) || exit 1; trap 'rm -f "$md"' EXIT
code=$(curl -sS -X POST "https://pdf-tools.msageha.net/api/v1/convert/pdf/markdown" \
  -F "fileInput=@<input-file>" -o "$md" -w '%{http_code}') && [ "$code" = 200 ] \
  || { echo "conversion failed (HTTP ${code:-none})"; exit 1; }
[ -s "$md" ] || { echo "conversion returned an empty file"; exit 1; }
# The vault containing the current directory, else the active one; to choose, put vault=<name> first
vault=$(obsidian vault info=path) && [ -d "$vault" ] || { echo "cannot find the vault"; exit 1; }
# noclobber makes the redirect fail instead of overwriting a note that already exists
mkdir -p "$vault/Notes" && (set -o noclobber; cat "$md" >"$vault/Notes/<note-name>.md") \
  || { echo "Notes/<note-name>.md already exists or can't be written"; exit 1; }

# Or extract images from PDF and save alongside the note
curl -sSf -X POST "https://pdf-tools.msageha.net/api/v1/misc/extract-images" \
  -F "fileInput=@<input-file>" \
  -F "format=png" \
  -o "<output-file>"
```
