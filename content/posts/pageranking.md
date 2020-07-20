+++
date = 2020-07-09T20:00:00Z
lastmod = 2020-07-09T20:00:00Z
author = "default"
title = "Page ranking Wikipedia for NLP model validation"
subtitle = "Parsing the Wikipedia dataset in Golang and finding relationships in an effort to validate a NLP model"
draft = "true"
+++

## Background

A friend of mine has built a new NLP model based on X.

The purpose of the model is to:

1. Summarize text (of any length?)
2. Compare texts to determine relevance

While it's possible to validate the model manually by feeding things that are known to be relevant, it is preferable to be able to validate the model in an automated fashion.

For this purpose, I looked into the possibility of using the Wikipedia Download as a validation source, which is what this article is about.

Is this a good idea? I honestly don't know. It is at least a very interesting programming task, so I decided to throw myself at the problem. I'm also on vacation currently, so what else would I do? Go to the beach? Pfft.

### Getting started

The first order of business is to initialize the Git repository for this project. I'll be adding code to the Git repository throughout this article, and the final result can be seen [here](https://github.com/sebnyberg/wikirel)

```bash
mkdir wikirel
cd wikirel
go mod init github.com/sebnyberg/wikirel
```

I don't currently foresee a need for me to have multiple packages in this repo, and I prefer to put my things in the root for as long as possible, so I create a cmd package and put the main.go there, i.e. in `cmd/main/main.go`:

```go
package main

import "fmt"

func main() {
	fmt.Println("hello, world!")
}
```

```bash
$ go run main.go
hello, world!
```

#### Wikipedia Downloads

The Wikipedia Downloads are well-structured and can be found [here](https://dumps.wikimedia.org/).

In our case, we are interested in the XML dump of the English Wikipedia, mirrors found [here](https://dumps.wikimedia.org/mirrors.html).

The extracts come in a couple of different formats. Each extract can either be downloaded in its entirety, or in multiple parts. There are also two versions: muti-stream and regular.

Let's start by downloading the first part of the multi-part extract in it's regular format (it's roughly 200MB in size):

```bash
echo "tmp" >> .gitignore

mkdir tmp
curl -sL https://ftp.acc.umu.se/mirror/wikimedia.org/dumps/enwiki/20200620/enwiki-20200620-pages-articles1.xml-p1p30303.bz2 -o tmp/regular-part1.xml.bz2
```

{{< alert "The dates of the extracts are continuously updated, so the file in the example will quickly become unavailable. Please check the latest version before downloading." >}}

Decompress the file:

```bash
$ bzip2 --keep --decompress tmp/regular-part1.xml.bz2
$ ls -lah tmp
total 1738592
drwxr-xr-x  4 seb  staff   128B Jul 10 16:55 .
drwxr-xr-x  8 seb  staff   256B Jul 10 16:52 ..
-rw-r--r--  1 seb  staff   649M Jul 10 16:52 regular-part1.xml
-rw-r--r--  1 seb  staff   178M Jul 10 16:52 regular-part1.xml.bz2
```

It becomes pretty clear why the extract is bzipped to begin with - the original file size has been reduced to 27%!

Extract the head to learn more about its structure:

```bash
head -n 150 tmp/regular-part1.xml > tmp/head.xml
```

The structure like this:

```xml
<mediawiki xmlns="http://www.mediawiki.org/xml/export-0.10/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.mediawiki.org/xml/export-0.10/ http://www.mediawiki.org/xml/export-0.10.xsd" version="0.10" xml:lang="en">
  <siteinfo>
    <sitename>Wikipedia</sitename>
    <dbname>enwiki</dbname>
    <base>https://en.wikipedia.org/wiki/Main_Page</base>
    <generator>MediaWiki 1.35.0-wmf.37</generator>
    <case>first-letter</case>
    <namespaces>
      <namespace key="-2" case="first-letter">Media</namespace>
      <namespace key="-1" case="first-letter">Special</namespace>
      <namespace key="0" case="first-letter" />
      <namespace key="1" case="first-letter">Talk</namespace>
      <namespace key="2" case="first-letter">User</namespace>
      <namespace key="3" case="first-letter">User talk</namespace>
      <!-- ... and more namespaces -->
    </namespaces>
  </siteinfo>
  <page>
    <title>AccessibleComputing</title>
    <ns>0</ns>
    <id>10</id>
    <redirect title="Computer accessibility" />
    <revision>
      <id>854851586</id>
      <parentid>834079434</parentid>
      <timestamp>2018-08-14T06:47:24Z</timestamp>
      <contributor>
        <username>Godsy</username>
        <id>23257138</id>
      </contributor>
      <comment>remove from category for seeking instructions on rcats</comment>
      <model>wikitext</model>
      <format>text/x-wiki</format>
      <text bytes="94" xml:space="preserve">#REDIRECT [[Computer accessibility]]

{{R from move}}
{{R from CamelCase}}
{{R unprintworthy}}</text>
      <sha1>42l0cvblwtb4nnupxm6wo000d27t6kf</sha1>
    </revision>
  </page>
  <page>
    <title>Anarchism</title>
    <ns>0</ns>
    <id>12</id>
    <revision>
      <!-- ... -->
    </revision>
  </page>
  <!-- ... and so on, tons of pages here -->
</mediawiki>
```

The goal then is to continuously decompress tokens in the input, then pass the decompressed contents to an XML parser. The XML parser should skip the first line (`<mediawiki>`), decode site-info, then parse pages one by one.

### XML in Golang

Go has excellent support a number of encoding formats (check them out [here](https://golang.org/pkg/encoding/#pkg-subdirectories)), including XML. The XML package supports the use of tags to annotate struct fields so that they can be decoded into native structs.

When a XML is decoded into a struct, and a field is missing, it is simply discarded. In our case, we are not interested in the `<siteinfo>...</siteinfo>` tag. This means we can create an empty anonymous struct to skip past the Site Info section when parsing the document.

Let's start by creating the XML structs. Since these are likely to see re-use between files in the package, I put them in `wikirel.go`:

```go
package wikirel

type Redirect struct {
	Title string `xml:"title,attr"`
}

type Page struct {
	Title     string    `xml:"title"`
	Namespace uint64    `xml:"ns"`
	ID        uint64    `xml:"id"`
	Redirect  *Redirect `xml:"redirect"`
	Text      string    `xml:"revision>text"`
}
```

To verify that things work, I put the example page from above into a test file (`reader_test.go`), and compare the parsed result with the original data.

```go
package wikirel_test

import (
	"encoding/xml"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/sebnyberg/wikirel"
)

func Test_PageStruct(t *testing.T) {
	var p wikirel.Page
	if err := xml.Unmarshal([]byte(accessibleComputingXML), &p); err != nil {
		t.Fatalf("failed to unmarshal page: %v", err)
	}

	if !cmp.Equal(p, accessibleComputingPage) {
		t.Fatalf("failed to parse page\n%v", cmp.Diff(p, accessibleComputingPage))
	}
}

const siteInfo = `<siteinfo>
	<sitename>Wikipedia</sitename>
	<dbname>enwiki</dbname>
	<base>https://en.wikipedia.org/wiki/Main_Page</base>
	<generator>MediaWiki 1.35.0-wmf.37</generator>
	<case>first-letter</case>
	<namespaces>
		<namespace key="-2" case="first-letter">Media</namespace>
		<namespace key="2303" case="case-sensitive">Gadget definition talk</namespace>
	</namespaces>
</siteinfo>`

var accessibleComputingPage = wikirel.Page{
	Title:     "AccessibleComputing",
	ID:        10,
	Namespace: 0,
	Redirect: &wikirel.Redirect{
		Title: "Computer accessibility",
	},
	Text: `#REDIRECT [[Computer accessibility]]

	{{R from move}}
	{{R from CamelCase}}
	{{R unprintworthy}}`,
}

const accessibleComputingXML = `<page>
	<title>AccessibleComputing</title>
	<ns>0</ns>
	<id>10</id>
	<redirect title="Computer accessibility" />
	<revision>
		<id>854851586</id>
		<parentid>834079434</parentid>
		<timestamp>2018-08-14T06:47:24Z</timestamp>
		<contributor>
			<username>Godsy</username>
			<id>23257138</id>
		</contributor>
		<comment>remove from category for seeking instructions on rcats</comment>
		<model>wikitext</model>
		<format>text/x-wiki</format>
		<text bytes="94" xml:space="preserve">#REDIRECT [[Computer accessibility]]

	{{R from move}}
	{{R from CamelCase}}
	{{R unprintworthy}}</text>
		<sha1>42l0cvblwtb4nnupxm6wo000d27t6kf</sha1>
	</revision>
</page>
`
```

{{< alert "I like to put large test inputs at the end of tests files - attention should be drawn primarily to the tests, not the large blocks of text used in the tests." "info" "note" >}}

{{< alert "Notice how I used the package `wikirel_test` instead of `wikirel`, which makes internals of the package inaccessible from the test. This is very much intentional. The test should only test the public API, and internals should be left alone as an implementation detail." "info" "note" >}}

Tests come out clean:

```bash
$ go test reader_test.go
ok      command-line-arguments  0.070s
```

### Parsing the entire XML file

While developing new features, I prefer to use some generic error to mark that something is not implemented yet. I put this error in `wikirel.go`:

```go
var ErrNotImplemented = errors.New("not implemented")
```

The next step is to implement the page reader. The idea is pretty basic, expose a function which reads the next page into the provided struct.

```go
package wikirel

import (
	"compress/bzip2"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
)

// PageReader reads Wikipedia pages from an input stream.
type PageReader struct {}

var ErrParseFailed = errors.New("parse failed")

// NewPageReader returns a new page reader reading from r.
// The provided reader is expected to read plaintext XML from
// the non-multi-stream Wikipedia database download.
func NewPageReader(r io.Reader) *PageReader {
	return &PageReader{}
}

var ErrInvalidFile = errors.New("invalid file")

// Read stores the next page from the reader in the provided page.
// If there are no more pages, io.EOF is returned.
func (r *PageReader) Read(page *Page) error {
	return ErrNotImplemented
}
```

To test the reader, I add another page (Anarchism) from the previously decompressed XML document to `pagereader_test.go` and construct a complete example exerpt:

```go
var anarchismPage = wikirel.Page{
	Title:     "Anarchism",
	Namespace: 0,
	ID:        12,
	Redirect:  nil,
	// Leaving out text
	// Text: ...
}

// This page is too large to show here, TODO: see Github repo
const anarchismXML = ``

var completeTestSample = fmt.Sprintf(`<mediawiki xmlns="http://www.mediawiki.org/xml/export-0.10/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.mediawiki.org/xml/export-0.10/ http://www.mediawiki.org/xml/export-0.10.xsd" version="0.10" xml:lang="en">
	%s
	%s
	%s
</mediawiki>
`, siteInfo, accessibleComputing, anarchism)
```

And a test for the parsing of pages:

```go
func Test_PageReader(t *testing.T) {
	type result struct {
		page *wikirel.Page
		err  error
	}

	for _, tc := range []struct {
		name  string
		input string
		want  []result
	}{
		{"empty input", "", []result{{nil, wikirel.ErrParseFailed}}},
		{"invalid input", "abc123", []result{{nil, wikirel.ErrParseFailed}}},
		{"download example", downloadContents, []result{
			{&accessibleComputingPage, nil},
			{&anarchismPage, nil},
			{nil, io.EOF},
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			r := strings.NewReader(tc.input)
			pageReader := wikirel.NewPageReader(r)
			for _, expected := range tc.want {
				var p wikirel.Page
				err := pageReader.Read(&p)
				if !cmp.Equal(expected.page, p, cmpopts.IgnoreFields(wikirel.Page{}, "Text")) {
					t.Errorf("expected page did not match result\n%v", cmp.Diff(expected.page, p))
				}
				if !cmp.Equal(err, expected.err, cmpopts.EquateErrors()) {
					t.Errorf("invalid err, expected: %v, got: %v\n", expected.err, err)
				}
			}
		})
	}
}
```

The tests (successfully) fail:

```bash
$ go test pagereader_test.go
--- FAIL: Test_PageReader (0.00s)
    --- FAIL: Test_PageReader/empty_input (0.00s)
        pagereader_test.go:44: invalid err, expected: parse failed, got: not implemented
    --- FAIL: Test_PageReader/invalid_input (0.00s)
        pagereader_test.go:44: invalid err, expected: parse failed, got: not implemented
    --- FAIL: Test_PageReader/download_example (0.00s)
        pagereader_test.go:41: expected page did not match result
              (*wikirel.Page)(
            -   &{
            -           Title:    "AccessibleComputing",
            -           ID:       10,
            -           Redirect: &wikirel.Redirect{Title: "Computer accessibility"},
            -           Text:     "#REDIRECT [[Computer accessibility]]\n\n\t{{R from move}}\n\t{{R from CamelCase}}\n\t{{R unprintworthy}}",
            -   },
            +   nil,
              )
        pagereader_test.go:44: invalid err, expected: <nil>, got: not implemented
        pagereader_test.go:41: expected page did not match result
              (*wikirel.Page)(
            -   &{Title: "Anarchism", ID: 12},
            +   nil,
              )
        pagereader_test.go:44: invalid err, expected: <nil>, got: not implemented
        pagereader_test.go:44: invalid err, expected: EOF, got: not implemented
FAIL
FAIL    command-line-arguments  0.193s
FAIL  
```

Let's add the XML decoder to the pageReader struct and a field to denote whether the header (mediawiki and siteinfo tags) has been skipped:

```go
type PageReader struct {
	dec           *xml.Decoder
	headerSkipped bool
}
```

These are initialized in the constructor (default initialization of headerSkipped to false):

```go
// NewPageReader returns a new page reader reading from r.
// The provided reader is expected to read plaintext XML from
// the non-multi-stream Wikipedia database download.
func NewPageReader(r io.Reader) *PageReader {
	return &PageReader{
		dec: xml.NewDecoder(r),
	}
}
```

`Read(*Page)` skips the header if it has not yet been skipped, otherwise it decodes the next block into the provided page:

```go
// Read stores the next page from the reader in the provided page.
// If there are no more pages, io.EOF is returned.
func (r *PageReader) Read(page *Page) error {
	// Skip <mediawiki> and <siteinfo> tag once per document
	if !r.headerSkipped {
		// Skip <mediawiki> tag
		if _, err := r.dec.Token(); err != nil {
			return fmt.Errorf("%w: could not parse mediawiki tag, err: %v", ErrParseFailed, err)
		}

		// Skip <siteinfo> tag
		si := struct{}{}
		if err := r.dec.Decode(&si); err != nil {
			return fmt.Errorf("%w: could not parse siteinfo tag, err: %v", ErrParseFailed, err)
		}

		r.headerSkipped = true
	}

	if err := r.dec.Decode(page); err != nil {
		if err == io.EOF {
			return io.EOF
		}
		return fmt.Errorf("%w: could not parse page, err: %v", ErrParseFailed, err)
	}

	return nil
}
```

Tests are now passing:

```bash
$ go test pagereader_test.go
ok      command-line-arguments  0.310s
```

### Reading the entire file

Let's test the solution by reading the entire file:

```go
package main

import (
	"fmt"
	"io"
	"log"
	"time"

	"github.com/pkg/profile"
	"github.com/sebnyberg/wikirel"
)

func main() {
	// Print elapsed time
	defer func(start time.Time) {
		log.Println("Elapsed time: ", time.Now().Sub(start))
	}(time.Now())

	f, err := os.OpenFile("tmp/regular-part1.xml.bz2", os.O_RDONLY, 0644)
	check(err)
	bz := bzip2.NewReader(f)

	r := wikirel.NewPageReader(bz)
	if err != nil {
		log.Fatalln(err)
	}

	var p wikirel.Page
	count := 0
	for ; ; count++ {
		if err := r.Read(&p); err != nil {
			if err == io.EOF {
				break
			}
			log.Fatalf("Unexpected err: %v", err)
		}
		if count%10 == 0 {
			fmt.Printf("Read: %v\r", count)
		}
	}

	log.Printf("Done! Read %v pages\n", count)
}
```

```bash
$ go run cmd/main/main.go
2020/07/11 02:02:08 Done! Read 19803 pages
2020/07/11 02:02:08 Elapsed time:  46.582391887s
```

Not too bad, but not exceptional either.

### Using the MultiStream format to read pages

The previous solution could be run in a concurrent fashion by downloading each of the parts, then reading from files in parallel. However, there is a download format which allows for concurrent reads from a single file.

The problem of reading from the same file concurrently is that the second reader needs to know how far to skip ahead. To solve this problem, the multi-stream export contains two sets of files: the regular files with pages, and indexing files containing the offsets of pages in the respective pages file. Unclear? Let's look at the data and you'll understand how this works.

```bash
curl -sL 'https://ftp.acc.umu.se/mirror/wikimedia.org/dumps/enwiki/20200620/enwiki-20200620-pages-articles-multistream-index1.txt-p1p30303.bz2' -o tmp/index-part1.txt.bz2
bzip2 --keep --decompress tmp/index-part1.txt.bz2
```

Let's check the head of the file:

```bash
$ head tmp/index-part1.txt
617:10:AccessibleComputing
617:12:Anarchism
617:13:AfghanistanHistory
617:14:AfghanistanGeography
617:15:AfghanistanPeople
617:18:AfghanistanCommunications
617:19:AfghanistanTransportations
617:20:AfghanistanMilitary
617:21:AfghanistanTransnationalIssues
617:23:AssistiveTechnology
```

And tail:

```bash
$ tail tmp/index-part1.txt
186707777:30282:Time signature
186707777:30283:Tristan Bernard
186707777:30284:Statistical hypothesis testing
186707777:30288:Tensor/Alternate
186707777:30292:The Hobbit
186707777:30294:The Lord of the Rings/One Ring
186707777:30296:Tax Freedom Day
187406849:30297:Tax
187406849:30299:Transhumanism
187406849:30302:TARDIS
```

The file contains blocks of indices, i.e. for each offset, there are many pages. Let's count the number of pages in each block.

At the start of the file:

```bash
$ awk -v FS=':' '{ print $1 }' tmp/index-part1.txt | uniq -c | head
 100 617
 100 641127
 100 1956236
 100 3302522
 100 4196525
 100 5309395
 100 6192941
 100 7009647
 100 7752545
 100 8311623
```

And near the end of the file (notice how the last block only contains 3 pages):

```bash
$ awk -v FS=':' '{ print $1 }' tmp/index-part1.txt | uniq -c | tail
 100 179315631
 100 180285122
 100 181014875
 100 181992299
 100 182908869
 100 183630119
 100 184299776
 100 185492497
 100 186707777
   3 187406849
```

{{< alert "`awk` is great for reading text. It parses the fields of each line in the input, and gives each field a variable that can be used to print. In the above example, I set the field separator (FS) to be ':', which allows me to print the byte offset in each row. Then `uniq -c` counts the number of rows with the same byte offset." info >}}

Using this indexing structure, concurrent readers can pick up un-read blocks. Having more than one page per block is also good design. If the blocks were not here, it would still be a good idea to create custom blocks to reduce disk seek.

```go
```

```go
```


