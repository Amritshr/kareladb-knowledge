# Bytes, hex and base64

> Store raw bytes (hashes, keys, small images) and turn them into hex or base64 text and back.

- Category: Functions — JSON and bytes
- Keywords: BYTES, BYTEA, BLOB, binary, hex, base64, \\x, hash, file hash, image, avatar, bytes to text, X', convert\_to, convert\_from, encoding, UTF8, LATIN1, escape format
- See also: [JSON functions](functions-json.md), [Security functions](functions-security.md), [Column types](column-types.md), [Text functions](functions-text.md)

A `BYTES` value holds raw bytes: any byte from 0 to 255, also zero bytes. Good uses are a file hash (SHA-256 is 32 bytes), a key, a signature or a very small image.
`BYTEA` and `BLOB` are other names for the same column type (see [column types](column-types.md)). One value can be at most 16 MB; keep big files outside the database and save their path and hash.

- **Hex** writes every byte as two digits `0-9 a-f`: the bytes 0, 255, 16 are `00ff10`.
- **Base64** writes 3 bytes as 4 letters: the same bytes are `AP8Q`. It is shorter than hex, and is often used in JSON and HTTP.
- KDB **shows** `BYTES` as `\x` and hex (`\x00ff10`), like PostgreSQL. This is the same in the shell, CSV and HTTP answers.
- On `BYTES`, `length()`, `octet_length()`, `substr()` and `reverse()` work on bytes, not letters (see [text functions](functions-text.md)).

Setup used by the examples below:

```sql
CREATE TABLE reports (
  id LONG PRIMARY KEY AUTO,
  symbol STRING NOT NULL,
  fiscal_year STRING NOT NULL,
  pdf_url STRING,
  pdf_sha256 BYTES
);
INSERT INTO reports (symbol, fiscal_year, pdf_url, pdf_sha256) VALUES
  ('CITY', '2082/83', 'https://files.example.com/city/2082-83-q4.pdf',
   X'9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08'),
  ('VOLT', '2082/83', 'https://files.example.com/volt/2082-83-q4.pdf', NULL);
```

**Example: A report PDF stays outside; KDB keeps its SHA-256 hash**

```sql
SELECT symbol,
       pdf_sha256,
       length(pdf_sha256) AS bytes,
       hex(pdf_sha256) AS hash_hex,
       to_base64(pdf_sha256) AS hash_base64
FROM reports
ORDER BY symbol;
```

Result:

| symbol (STRING) | pdf_sha256 (BYTES) | bytes (LONG) | hash_hex (STRING) | hash_base64 (STRING) |
|---|---|---|---|---|
| CITY | \\x9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08 | 32 | 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08 | n4bQgYhMfWWaL+qgxVrQFaO/TxsrC4Is0V1sFbDwCgg= |
| VOLT | NULL | NULL | NULL | NULL |

(2 rows)

<a id="x-literal"></a>

## X'...' bytes literal

Syntax:

```sql
X'0A0B'        x'0a0b'        X''
'\x0a0b'       text that becomes BYTES in a BYTES column or CAST
CAST('\x0a0b' AS BYTES)       '\x0a0b'::BYTES
```

`X'...'` writes bytes in hex inside SQL. Each byte is two hex digits; big or small letters both work. There must be no space between `X` and the quote.

When text goes into a `BYTES` column (or `CAST(... AS BYTES)`):

| Text | Bytes |
|---|---|
| starts with `\x`, like `'\x0a0b'` | the hex digits after `\x` |
| any other text, like `'hi'` | the UTF-8 bytes of the text (`\x6869`) |

- **Returns:** `BYTES`.
- **NULL:** `NULL` stays `NULL`.
- **Notes:** an odd number of digits or a letter that is not hex is an error (`X'ABC'`). `X'...'` is read as `unhex('...')`, so its error message says `unhex`.
- `'\x0a0b'` alone, outside a `BYTES` column or cast, is just text of 6 characters.
- A number cannot become `BYTES` (`CAST(5 AS BYTES)` is an error).
- Compare: `BYTES` compare byte by byte. `BYTES` compared with text read the text like the table above, so `X'6869' = 'hi'` is true.
- `X'01' || X'02'` joins bytes (see [||](functions-text.md#concat-operator)). Bytes joined with **text** give text: `X'0102' || 'ab'` is the text `'\x0102ab'`, not bytes.

**Example**

```sql
SELECT X'0A0B' AS a,
       x'0a0b' AS small_letters,
       X'' AS empty,
       '\x0a0b'::BYTES AS from_hex_text,
       CAST('hi' AS BYTES) AS from_text,
       X'0102' || X'03' AS joined;
```

Result:

| a (BYTES) | small_letters (BYTES) | empty (BYTES) | from_hex_text (BYTES) | from_text (BYTES) | joined (BYTES) |
|---|---|---|---|---|---|
| \\x0a0b | \\x0a0b | \\x | \\x0a0b | \\x6869 | \\x010203 |

(1 row)

**Example: Store and compare file hashes**

Setup:

```sql
CREATE TABLE avatars (user_id LONG PRIMARY KEY, png_header BYTES, sha256 BYTES);
INSERT INTO avatars VALUES
  (1, X'89504E470D0A1A0A', '\x2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae'),
  (2, 'not a png', NULL);
```

```sql
SELECT user_id, png_header, length(png_header) AS bytes,
       png_header = X'89504E470D0A1A0A' AS is_png
FROM avatars
ORDER BY user_id;
```

Result:

| user_id (LONG) | png_header (BYTES) | bytes (LONG) | is_png (BOOL) |
|---|---|---|---|
| 1 | \\x89504e470d0a1a0a | 8 | true |
| 2 | \\x6e6f74206120706e67 | 9 | false |

(2 rows)

**Example: Bytes compared with text**

```sql
SELECT X'6869' = 'hi' AS same_as_text,
       X'0A0B' = '\x0a0b' AS same_as_hex_text,
       X'01' < X'02' AS smaller,
       length('\x0a0b') AS text_letters,
       length('\x0a0b'::BYTES) AS bytes;
```

Result:

| same_as_text (BOOL) | same_as_hex_text (BOOL) | smaller (BOOL) | text_letters (LONG) | bytes (LONG) |
|---|---|---|---|---|
| true | true | true | 6 | 2 |

(1 row)

**Example: An odd number of hex digits** (shows an error)

```sql
SELECT X'ABC';
```

Result:

Error: `line 1, column 8: unhex: 'ABC' is not hex (an even number of the digits 0-9 and a-f)`

**Example: Bad hex in a BYTES column** (shows an error)

```sql
INSERT INTO reports (symbol, fiscal_year, pdf_sha256) VALUES ('COAST', '2082/83', '\x9F86ZZ');
```

Result:

Error: `column 'pdf_sha256' (BYTES): '\x9F86ZZ' is not hex bytes; write them like '\x0a0b' or X'0A0B'`

## hex

Syntax:

```sql
hex(value)
```

Writes bytes as hex text: two small-letter digits for every byte. Text is written as its UTF-8 bytes. A whole number is written as a hex number.

| Argument | Type | Meaning |
|---|---|---|
| `value` | `BYTES`, `STRING` or a whole number | what to write as hex |

- **Returns:** `STRING`.
- **NULL:** `hex(NULL)` is `NULL`.
- **Notes:** `hex(255)` is `ff` (like MySQL). A negative number uses 16 digits: `hex(-1)` is `ffffffffffffffff`. Other values (a `DOUBLE`, a time) are first turned into text: `hex(2.5)` is the hex of the text `'2.5'`.
- A Nepali letter is 3 bytes in UTF-8, so it gives 6 hex digits.
- The opposite is `unhex`.

**Example**

```sql
SELECT hex(X'00FF10') AS from_bytes,
       hex('CITY') AS from_text,
       hex(255) AS from_number,
       hex(-1) AS negative,
       hex('न') AS nepali_letter;
```

Result:

| from_bytes (STRING) | from_text (STRING) | from_number (STRING) | negative (STRING) | nepali_letter (STRING) |
|---|---|---|---|---|
| 00ff10 | 43495459 | ff | ffffffffffffffff | e0a4a8 |

(1 row)

**Example: Show a short hash code for each report on a web page**

```sql
SELECT symbol, left(hex(pdf_sha256), 12) AS short_hash
FROM reports
WHERE pdf_sha256 IS NOT NULL;
```

Result:

| symbol (STRING) | short_hash (STRING) |
|---|---|
| CITY | 9f86d081884c |

(1 row)

## unhex

Syntax:

```sql
unhex(hex_text)
```

Reads hex text and gives the bytes. It is the opposite of `hex`.

| Argument | Type | Meaning |
|---|---|---|
| `hex_text` | `STRING` | an even number of hex digits (`0-9`, `a-f` or `A-F`), nothing else |

- **Returns:** `BYTES`.
- **NULL:** `unhex(NULL)` is `NULL`.
- **Notes:** no `\x` in front, no spaces. An odd number of digits or another sign is an error. `unhex('')` is empty bytes.
- `decode(hex_text, 'hex')` does the same.

**Example**

```sql
SELECT unhex('4E4142494C') AS a, unhex('00ff10') AS b, unhex('') AS empty;
```

Result:

| a (BYTES) | b (BYTES) | empty (BYTES) |
|---|---|---|
| \\x4e4142494c | \\x00ff10 | \\x |

(1 row)

**Example: Save a SHA-256 hash as 32 bytes instead of 64 letters**

Setup:

```sql
INSERT INTO reports (symbol, fiscal_year, pdf_url, pdf_sha256)
VALUES ('COAST', '2082/83', 'https://files.example.com/coast/2082-83-q4.pdf',
        unhex('2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae'));
```

```sql
SELECT symbol, length(pdf_sha256) AS bytes, hex(pdf_sha256) AS hash_hex
FROM reports
WHERE symbol = 'COAST';
```

Result:

| symbol (STRING) | bytes (LONG) | hash_hex (STRING) |
|---|---|---|
| COAST | 32 | 2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae |

(1 row)

**Example: Spaces are not allowed** (shows an error)

```sql
SELECT unhex('4E 41 42');
```

Result:

Error: `line 1, column 8: unhex: '4E 41 42' is not hex (an even number of the digits 0-9 and a-f)`

## to_base64

Syntax:

```sql
to_base64(value)
```

Writes bytes as base64 text (letters `A-Z a-z 0-9 + /`, with `=` at the end to fill). Text is written as its UTF-8 bytes.

| Argument | Type | Meaning |
|---|---|---|
| `value` | `BYTES` or `STRING` | what to write as base64 |

- **Returns:** `STRING`.
- **NULL:** `to_base64(NULL)` is `NULL`.
- **Notes:** the result is one line (no line breaks). It uses the normal alphabet with `+` and `/`, not the URL alphabet (`-` and `_`).
- `encode(value, 'base64')` does the same. The opposite is `from_base64`.

**Example**

```sql
SELECT to_base64(X'00FF10') AS bytes_value,
       to_base64('CITY') AS text_value,
       to_base64('नेपाल') AS nepali,
       to_base64('') AS empty;
```

Result:

| bytes_value (STRING) | text_value (STRING) | nepali (STRING) | empty (STRING) |
|---|---|---|---|
| AP8Q | Q0lUWQ== | 4KSo4KWH4KSq4KS+4KSy |  |

(1 row)

**Example: Send a small image to an app inside JSON**

Setup:

```sql
CREATE TABLE avatars (user_id LONG PRIMARY KEY, image BYTES);
INSERT INTO avatars VALUES (7, X'89504E470D0A1A0A0000000D49484452');
```

```sql
SELECT json_object('user_id', user_id, 'image_base64', to_base64(image)) AS answer
FROM avatars;
```

Result:

| answer (JSON) |
|---|
| {"user_id":7,"image_base64":"iVBORw0KGgoAAAANSUhEUg=="} |

(1 row)

## from_base64

Syntax:

```sql
from_base64(text)
```

Reads base64 text and gives the bytes. It is the opposite of `to_base64`.

| Argument | Type | Meaning |
|---|---|---|
| `text` | `STRING` | base64 text |

- **Returns:** `BYTES`.
- **NULL:** `from_base64(NULL)` is `NULL`.
- **Notes:** both alphabets work: `+ /` and the URL one `- _`. The `=` at the end may be left out. Spaces and line breaks are skipped. Any other sign is an error.
- `decode(text, 'base64')` does the same.
- There is no function yet to turn `BYTES` back into normal text: `CAST(bytes AS STRING)` gives the `\x...` hex text. Keep text in a `STRING` column.

**Example**

```sql
SELECT from_base64('AP8Q') AS a,
       from_base64('TkFCSUw=') AS with_padding,
       from_base64('TkFCSUw') AS without_padding,
       from_base64('TkFC
SUw=') AS with_line_break;
```

Result:

| a (BYTES) | with_padding (BYTES) | without_padding (BYTES) | with_line_break (BYTES) |
|---|---|---|---|
| \\x00ff10 | \\x4e4142494c | \\x4e4142494c | \\x4e4142494c |

(1 row)

**Example: A mobile app uploads an avatar as base64**

Setup:

```sql
CREATE TABLE avatars (user_id LONG PRIMARY KEY, image BYTES);
```

```sql
INSERT INTO avatars VALUES (7, from_base64('iVBORw0KGgoAAAANSUhEUg=='));
SELECT user_id, image, length(image) AS bytes FROM avatars;
```

Result:

`INSERT INTO avatars VALUES (7, from_base64('iVBORw0KGgoAAAANSUhEUg=='))`

```text
1 row(s) inserted
```

`SELECT user_id, image, length(image) AS bytes FROM avatars`

| user_id (LONG) | image (BYTES) | bytes (LONG) |
|---|---|---|
| 7 | \\x89504e470d0a1a0a0000000d49484452 | 16 |

(1 row)

**Example: Not base64** (shows an error)

```sql
SELECT from_base64('abc$');
```

Result:

Error: `line 1, column 8: from_base64: the text is not valid base64`

## encode

Syntax:

```sql
encode(value, format)
```

Writes bytes as text in `format`: `'hex'`, `'base64'` or `'escape'`, as PostgreSQL does. `hex()` and `to_base64()` do the same as the first two.

| Argument | Type | Meaning |
|---|---|---|
| `value` | `BYTES` or `STRING` | what to write (text is written as its UTF-8 bytes) |
| `format` | `STRING` | `'hex'`, `'base64'` or `'escape'` (big or small letters) |

- **Returns:** `STRING`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:**
  - `'base64'` breaks the text into lines of 76 characters, as PostgreSQL does; `to_base64()` keeps one line. `decode` reads both.
  - `'escape'` writes a zero byte and bytes from 128 up as `\nnn` (three octal digits) and a backslash as `\\`; the rest stays as it is.
  - `encode(sha256(x), 'hex')` encodes the hash's own bytes, so PostgreSQL code gives the same 64 characters ([sha256](functions-security.md#sha256)).

**Example**

```sql
SELECT encode(X'00FF10', 'hex') AS hex_text,
       encode(X'00FF10', 'base64') AS base64_text,
       encode(X'00FF10', 'escape') AS escape_text,
       encode('CITY', 'HEX') AS text_as_hex;
```

Result:

| hex_text (STRING) | base64_text (STRING) | escape_text (STRING) | text_as_hex (STRING) |
|---|---|---|---|
| 00ff10 | AP8Q | \\000\\377 | 43495459 |

(1 row)

**Example: Other formats are an error** (shows an error)

```sql
SELECT encode(X'00FF10', 'utf8');
```

Result:

Error: `line 1, column 8: encode: format 'utf8' is not supported; use 'hex', 'base64' or 'escape'`

## decode

Syntax:

```sql
decode(text, format)
```

Reads text in `format` (`'hex'`, `'base64'` or `'escape'`) and gives the bytes. It is the opposite of `encode`, and does the same as `unhex()` and `from_base64()`.

| Argument | Type | Meaning |
|---|---|---|
| `text` | `STRING` | hex, base64 or escape text |
| `format` | `STRING` | `'hex'`, `'base64'` or `'escape'` (big or small letters) |

- **Returns:** `BYTES`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** bad hex, bad base64 or a backslash in escape text that is not `\\` or `\nnn` is an error. Line breaks in base64 are skipped. Another format is an error. To turn bytes into text of an encoding, use [convert_from](#convert_from).

**Example**

```sql
SELECT decode('00ff10', 'hex') AS from_hex,
       decode('AP8Q', 'base64') AS from_base64_text,
       decode('00ff10', 'hex') = decode('AP8Q', 'base64') AS same_bytes;
```

Result:

| from_hex (BYTES) | from_base64_text (BYTES) | same_bytes (BOOL) |
|---|---|---|
| \\x00ff10 | \\x00ff10 | true |

(1 row)

**Example: Check a download: compare the hash the server sent with the saved one**

```sql
SELECT symbol,
       pdf_sha256 = decode('n4bQgYhMfWWaL+qgxVrQFaO/TxsrC4Is0V1sFbDwCgg=', 'base64') AS hash_matches
FROM reports
WHERE symbol = 'CITY';
```

Result:

| symbol (STRING) | hash_matches (BOOL) |
|---|---|
| CITY | true |

(1 row)

**Example: Wrong format name** (shows an error)

```sql
SELECT decode('hello', 'utf8');
```

Result:

Error: `line 1, column 8: decode: format 'utf8' is not supported; use 'hex', 'base64' or 'escape'`

## convert_to

Syntax:

```sql
convert_to(text, encoding)
```

The bytes of a text in an encoding (PostgreSQL). `convert_to(token, 'UTF8')` is how PostgreSQL code turns a text into bytes before hashing it.

| Argument | Type | Meaning |
|---|---|---|
| `text` | `STRING` | the text |
| `encoding` | `STRING` | `'UTF8'` (also `'UTF-8'`), `'LATIN1'` or `'SQL_ASCII'` |

- **Returns:** `BYTES`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** KDB keeps text as UTF-8, so `'UTF8'` gives those bytes as they are. `'LATIN1'` gives one byte per character; a character LATIN1 does not have (like Nepali letters) is an error, never a `?`. Other encodings are an error.

**Example**

```sql
SELECT convert_to('CITY', 'UTF8') AS utf8_bytes,
       convert_to('नेपाल', 'UTF8') AS nepali_bytes,
       convert_to('Æ', 'LATIN1') AS latin1_byte;
```

Result:

| utf8_bytes (BYTES) | nepali_bytes (BYTES) | latin1_byte (BYTES) |
|---|---|---|
| \\x43495459 | \\xe0a4a8e0a587e0a4aae0a4bee0a4b2 | \\xc6 |

(1 row)

**Example: Not in LATIN1** (shows an error)

```sql
SELECT convert_to('नेपाल', 'LATIN1');
```

Result:

Error: `line 1, column 8: convert_to: character 'न' has no equivalent in encoding "LATIN1"`

<a id="convert_from"></a>

## convert_from

Syntax:

```sql
convert_from(bytes, encoding)
```

The text that bytes in an encoding stand for (PostgreSQL). The opposite of `convert_to`.

| Argument | Type | Meaning |
|---|---|---|
| `bytes` | `BYTES` | the bytes |
| `encoding` | `STRING` | `'UTF8'`, `'LATIN1'` or `'SQL_ASCII'` |

- **Returns:** `STRING`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** with `'UTF8'` (and `'SQL_ASCII'`) the bytes must be valid UTF-8; bad bytes are an error that names the first one, as in PostgreSQL. `'LATIN1'` turns each byte into its character.

**Example**

```sql
SELECT convert_from('\x43495459'::bytea, 'UTF8') AS text,
       convert_from('\xc6'::bytea, 'LATIN1') AS latin1;
```

Result:

| text (STRING) | latin1 (STRING) |
|---|---|
| CITY | Æ |

(1 row)

**Example: Not UTF-8** (shows an error)

```sql
SELECT convert_from('\xff'::bytea, 'UTF8');
```

Result:

Error: `line 1, column 8: convert_from: invalid byte sequence for encoding "UTF8": 0xff`
