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

Similarly, for the page, not all fields are of interest. I put the XML struct into `parser.go`:

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

To verify that things work, I put the example page from above into a test file (`parser_test.go`), and compare the parsed result with the original data.

```go
package wikirel_test

import (
	"encoding/xml"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/sebnyberg/wikirel"
)

func Test_Page(t *testing.T) {
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
$ go test parser_test.go
ok      command-line-arguments  0.070s
```

### Parsing the entire XML file

While developing new features, I prefer to use some generic error to mark that something is not implemented yet. I put this in `wikirel.go`:

```go
package wikirel

import "errors"

var ErrNotImplemented = errors.New("not implemented")
```

I create two new files `parser.go`, and `parser_test.go` and put them in the root directory.

The parser is pretty basic, it yields pages one by one when the method `Next()` is called:

```go
package wikirel

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
)

// Parser is used to read Pages from a Wikipedia download.
type Parser interface {
	// Next returns one page from the download.
	// The last page will return io.EOF. Subsequent calls
	// return a nil page with io.EOF as the error.
	Next() (*Page, error)
}

type parser struct{}

var ErrParseFailed = errors.New("parse failed")

// NewParser returns a new page parser.
// Data is assumed to be compressed in bzip2 format.
func NewParser(r io.Reader) Parser {
	return &parser{}
}

var ErrInvalidFile = errors.New("invalid file")

// NewParserFromFile creates a new page parser from file.
// If the file path does not end with .bz2, an error is returned.
func NewParserFromFile(filename string) (Parser, error) {
	if ext := path.Ext(filename); ext != ".bz2" {
		return nil, fmt.Errorf(
			"%w: file must be in bzip2 format, was: %v",
			ErrInvalidFile, ext,
		)
	}

	f, err := os.OpenFile(filename, os.O_RDONLY, 0644)
	if err != nil {
		return nil, err
	}
	buf := bufio.NewReader(f)

	return NewParser(buf), nil
}

func (p *parser) Next() (*Page, error) {
	return nil, ErrNotImplemented
}
```

The reason for not just exposing `NewReader` is that new Go programmers tend to not create buffered writers (`bufio.Reader`), which in turn results in performance degradation.

Every time the Go program requests to read from disk, a syscall is made, which blocks the running Goroutine. In the current case, where we read sequentially, the program would grind to a halt every time a token is read from disk.

Interestingly, the bzip2 reader uses an internal buffer, so in this case the difference would be neglible, but I keep the bufio here anyway for visibility.

To test the reader, I add another page (Anarchism) from the previously decompressed XML document to `parser_test.go` and construct a complete example exerpt:

```go
var anarchismPage = wikirel.Page{
	Title:     "Anarchism",
	Namespace: 0,
	ID:        12,
	Redirect:  nil,
	// Leaving out text
	// Text: ...
}

// This article is too large to show here, TODO: see Github repo
const anarchismXML = ``

var completeTestSample = fmt.Sprintf(`<mediawiki xmlns="http://www.mediawiki.org/xml/export-0.10/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.mediawiki.org/xml/export-0.10/ http://www.mediawiki.org/xml/export-0.10.xsd" version="0.10" xml:lang="en">
	%s
	%s
	%s
</mediawiki>
`, siteInfo, accessibleComputing, anarchism)
```

Let's start with a test for the `NewParseFromFile` constructor:

```go
func Test_NewParserFromFile(t *testing.T) {
	for _, tc := range []struct {
		filename    string
		expectedErr error
	}{
		{"somefile.xml", wikirel.ErrInvalidFile},
		{"", wikirel.ErrInvalidFile},
	} {
		t.Run(tc.filename, func(t *testing.T) {
			_, err := wikirel.NewParserFromFile(tc.filename)
			if !errors.Is(err, tc.expectedErr) {
				t.Fatalf("invalid err, expected: %v, got: %v", tc.expectedErr, err)
			}
		})
	}
}
```

And a test for the parsing of pages:

```go
func Test_Parser_Next(t *testing.T) {
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
			{&anarchismPage, io.EOF},
			{nil, io.EOF},
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			r := strings.NewReader(tc.input)
			parser := wikirel.NewParser(r)
			for _, expected := range tc.want {
				p, err := parser.Next()
				if !cmp.Equal(p, expected.page) {
					t.Errorf("result page did not match expectation: %v", cmp.Diff(p, expected.page))
				}
				if !cmp.Equal(err, expected.err, cmpopts.EquateErrors()) {
					t.Errorf("error did not match expection: %v", cmp.Diff(err, expected.err, cmpopts.EquateErrors()))
				}
			}
		})
	}
}
```

The tests (successfully) fail:

```bash
$ go test parser_test.go
--- FAIL: Test_Parser_Next (0.00s)
    --- FAIL: Test_Parser_Next/empty_input (0.00s)
        parser_test.go:44: error did not match expection:   (*errors.errorString)(
            -   e"not implemented",
            +   e"parse failed",
              )
    --- FAIL: Test_Parser_Next/invalid_input (0.00s)
        parser_test.go:44: error did not match expection:   (*errors.errorString)(
            -   e"not implemented",
            +   e"parse failed",
              )
    --- FAIL: Test_Parser_Next/download_example (0.00s)
        parser_test.go:41: result page did not match expectation:   (*wikirel.Page)(
            -   nil,
            +   &{
            +           Title:    "AccessibleComputing",
            +           ID:       10,
            +           Redirect: &wikirel.Redirect{Title: "Computer accessibility"},
            +           Text:     "#REDIRECT [[Computer accessibility]]\n\n\t{{R from move}}\n\t{{R from CamelCase}}\n\t{{R unprintworthy}}",
            +   },
              )
        parser_test.go:44: error did not match expection:   interface{}(
            -   e"not implemented",
              )
        parser_test.go:41: result page did not match expectation:   (*wikirel.Page)(
            -   nil,
            +   &{Title: "Anarchism", ID: 12},
              )
        parser_test.go:44: error did not match expection:   (*errors.errorString)(
            -   e"not implemented",
            +   e"EOF",
              )
        parser_test.go:44: error did not match expection:   (*errors.errorString)(
            -   e"not implemented",
            +   e"EOF",
              )
FAIL
FAIL    command-line-arguments  0.297s
FAIL
```


