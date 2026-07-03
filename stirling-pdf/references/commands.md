# Stirling PDF Command Recipes

Ready-to-run `curl` examples for the endpoints listed in
[api-reference.md](api-reference.md). Base URL: `http://172.16.1.101:18085/api/v1`.

## PDF to Markdown (for Obsidian)

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/pdf/markdown" \
  -F "fileInput=@input.pdf" \
  -o output.md
```

## PDF to Text

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/pdf/text" \
  -F "fileInput=@input.pdf" \
  -F "outputFormat=txt" \
  -o output.txt
```

## PDF to Images

```bash
# All pages as separate PNG files (returned as ZIP)
curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/pdf/img" \
  -F "fileInput=@input.pdf" \
  -F "imageFormat=png" \
  -F "singleOrMultiple=multiple" \
  -F "colorType=color" \
  -F "dpi=300" \
  -F "pageNumbers=all" \
  -o output.zip

# Single page as JPEG
curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/pdf/img" \
  -F "fileInput=@input.pdf" \
  -F "imageFormat=jpeg" \
  -F "singleOrMultiple=single" \
  -F "colorType=color" \
  -F "dpi=300" \
  -F "pageNumbers=1" \
  -o page1.jpeg
```

## PDF to Word / HTML

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/pdf/word" \
  -F "fileInput=@input.pdf" \
  -o output.docx

curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/pdf/html" \
  -F "fileInput=@input.pdf" \
  -o output.html
```

## Markdown / HTML / URL / Office to PDF

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/markdown/pdf" \
  -F "fileInput=@input.md" \
  -o output.pdf

curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/html/pdf" \
  -F "fileInput=@input.html" \
  -F "zoom=1" \
  -o output.pdf

curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/url/pdf" \
  -F "urlInput=https://example.com" \
  -o output.pdf

# Supports .doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .csv, etc.
curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/file/pdf" \
  -F "fileInput=@document.docx" \
  -o output.pdf
```

## Images to PDF

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/img/pdf" \
  -F "fileInput=@image1.png" \
  -F "fileInput=@image2.png" \
  -F "fitOption=maintainAspectRatio" \
  -F "colorType=color" \
  -F "autoRotate=true" \
  -o output.pdf
```

## Merge / Split / Remove / Rotate / Rearrange Pages

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/general/merge-pdfs" \
  -F "fileInput=@file1.pdf" \
  -F "fileInput=@file2.pdf" \
  -F "sortType=orderProvided" \
  -F "removeCertSign=true" \
  -o merged.pdf

curl -s -X POST "http://172.16.1.101:18085/api/v1/general/split-pages" \
  -F "fileInput=@input.pdf" \
  -F "pageNumbers=1,3,5-9" \
  -o split.zip

curl -s -X POST "http://172.16.1.101:18085/api/v1/general/remove-pages" \
  -F "fileInput=@input.pdf" \
  -F "pageNumbers=2,4" \
  -o output.pdf

curl -s -X POST "http://172.16.1.101:18085/api/v1/general/rotate-pdf" \
  -F "fileInput=@input.pdf" \
  -F "angle=90" \
  -o rotated.pdf

curl -s -X POST "http://172.16.1.101:18085/api/v1/general/rearrange-pages" \
  -F "fileInput=@input.pdf" \
  -F "pageNumbers=3,1,2,4" \
  -o rearranged.pdf
```

## Compress

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/compress-pdf" \
  -F "fileInput=@input.pdf" \
  -F "optimizeLevel=5" \
  -F "expectedOutputSize=25KB" \
  -o compressed.pdf
```

## OCR

Note: available `languages` values depend on which Tesseract `.traineddata`
files are bundled in the deployed image (full/lite/ultra-lite variant) — check
`languages` availability rather than assuming a fixed list.

```bash
# Japanese + English OCR
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/ocr-pdf" \
  -F "fileInput=@scanned.pdf" \
  -F "languages=jpn" \
  -F "languages=eng" \
  -F "ocrType=skip-text" \
  -F "ocrRenderType=hocr" \
  -o ocr_output.pdf

# Force OCR on all pages
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/ocr-pdf" \
  -F "fileInput=@scanned.pdf" \
  -F "languages=jpn" \
  -F "ocrType=force-ocr" \
  -F "ocrRenderType=sandwich" \
  -F "deskew=true" \
  -F "clean=true" \
  -o ocr_output.pdf
```

## Repair / Flatten

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/repair" \
  -F "fileInput=@corrupted.pdf" \
  -o repaired.pdf

# Flatten only forms
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/flatten" \
  -F "fileInput=@input.pdf" \
  -F "flattenOnlyForms=true" \
  -o flattened.pdf
```

## Extract Images

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/extract-images" \
  -F "fileInput=@input.pdf" \
  -F "format=png" \
  -o images.zip
```

## Add Page Numbers

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/add-page-numbers" \
  -F "fileInput=@input.pdf" \
  -F "pageNumbers=all" \
  -F "position=8" \
  -F "fontSize=12" \
  -F "fontType=helvetica" \
  -F "startingNumber=1" \
  -F "customText={n}" \
  -o numbered.pdf
```

## Add Text Stamp

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/add-stamp" \
  -F "fileInput=@input.pdf" \
  -F "pageNumbers=all" \
  -F "stampType=text" \
  -F "stampText=CONFIDENTIAL" \
  -F "fontSize=30" \
  -F "rotation=45" \
  -F "opacity=0.3" \
  -F "position=5" \
  -o stamped.pdf
```

## Update Metadata

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/update-metadata" \
  -F "fileInput=@input.pdf" \
  -F "title=My Document" \
  -F "author=Author Name" \
  -F "subject=Subject" \
  -F "keywords=keyword1,keyword2" \
  -o updated.pdf
```

## Add / Remove Password, Watermark

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/security/add-password" \
  -F "fileInput=@input.pdf" \
  -F "password=mypassword" \
  -F "keyLength=256" \
  -o protected.pdf

curl -s -X POST "http://172.16.1.101:18085/api/v1/security/remove-password" \
  -F "fileInput=@input.pdf" \
  -F "password=currentpassword" \
  -o unlocked.pdf

curl -s -X POST "http://172.16.1.101:18085/api/v1/security/add-watermark" \
  -F "fileInput=@input.pdf" \
  -F "watermarkType=text" \
  -F "watermarkText=DRAFT" \
  -F "fontSize=50" \
  -F "rotation=45" \
  -F "opacity=0.3" \
  -F "convertPDFToImage=false" \
  -o watermarked.pdf
```

## Analysis

```bash
curl -s -X POST "http://172.16.1.101:18085/api/v1/analysis/page-count" \
  -F "fileInput=@input.pdf"

curl -s -X POST "http://172.16.1.101:18085/api/v1/analysis/basic-info" \
  -F "fileInput=@input.pdf"

curl -s -X POST "http://172.16.1.101:18085/api/v1/analysis/document-properties" \
  -F "fileInput=@input.pdf"
```

## Server Status

```bash
curl -s "http://172.16.1.101:18085/api/v1/info/status" | jq .
```

## Obsidian Integration Workflow

```bash
# 1. Convert PDF to Markdown
curl -s -X POST "http://172.16.1.101:18085/api/v1/convert/pdf/markdown" \
  -F "fileInput=@document.pdf" \
  -o /tmp/document.md

# 2. Add to Obsidian vault
obsidian-cli create "Notes/document" --content "$(cat /tmp/document.md)"

# Or extract images from PDF and save alongside the note
curl -s -X POST "http://172.16.1.101:18085/api/v1/misc/extract-images" \
  -F "fileInput=@document.pdf" \
  -F "format=png" \
  -o /tmp/images.zip
```
