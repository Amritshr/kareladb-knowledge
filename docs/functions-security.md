# Security functions

> Hash and check passwords, make SHA-256 hashes, random tokens and random ids (UUIDs), and encrypt data with PostgreSQL's pgcrypto functions.

- Category: Functions — security
- Keywords: security, password, hash, salt, pbkdf2, login, register, sign up, session, session token, api key, reset link, uuid, random, crypto, pgcrypto, SHA2, HMAC, webhook signature, digest, sha224, sha384, sha512, sha256 bytea, encode sha256 hex, encrypt, decrypt, encryption, pgp, openpgp, gpg, pgp\_sym\_encrypt, pgp\_sym\_decrypt, crypt, gen\_salt, bcrypt, gen\_random\_bytes, armor, dearmor, aes, base64
- See also: [Users and roles](users-and-roles.md), [Keeping kareladb serve safe](server-security.md), [Bytes, hex and base64](functions-bytes.md), [Constraints](constraints.md), [UPDATE and DELETE](update-delete.md)

These functions help your **app** keep its users safe: people who register and log in to your web site or mobile app.

- A **hash** is a short code made from a text. You can not get the text back from the hash.
- `password_hash` and `password_verify` are for passwords. They are **slow on purpose** (about 0.05 to 0.4 seconds), so a thief who steals the hashes can only try a few guesses per second.
- `sha256` and `hmac_sha256` are **fast**. Use them for tokens and signatures, never for passwords.
- `random_bytes`, `random_token` and `gen_random_uuid` take random bytes from the operating system. They give a new value on every call and for every row.
- A `NULL` argument gives `NULL`.

Database users (who may connect to the KarelaDB server itself) are a different thing: see [Users and roles](users-and-roles.md).

**Example: Register a user, then check the password at login**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE, password_hash STRING NOT NULL);
```

```sql
INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', password_hash('correct horse battery'));
SELECT id, email, password_hash FROM app_users;
SELECT id FROM app_users
WHERE email = 'sita@example.com' AND password_verify('correct horse battery', password_hash);
```

Result:

`INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', '$pbkdf2-sha256$i=600000$U8`

```text
1 row(s) inserted
```

`SELECT id, email, password_hash FROM app_users`

| id (INT) | email (STRING) | password_hash (STRING) |
|---|---|---|
| 1 | sita@example.com | $pbkdf2-sha256$i=600000$U8X/Iy5BcDYhZXHzzkuOHg$7SSxzz/CAZJ1NIIMmGOdg2k0JCaT306Eh8ungg4zxn4 |

(1 row)

`SELECT id FROM app_users WHERE email = 'sita@example.com' AND password_verify('correct horse battery`

| id (INT) |
|---|
| 1 |

(1 row)

## password_hash

Syntax:

```sql
password_hash(password)
password_hash(password, iterations)
```

Makes a hash of a password, to store in your users table. Each call uses a new random **salt** (random bytes mixed into the hash), so the same password gives a different hash every time.

| Argument | Type | Meaning |
|---|---|---|
| `password` | text | the password the user typed. A number is turned into text first. |
| `iterations` | whole number | how many rounds of work: 1000 to 10000000. Default `600000`. More is slower and safer. |

- **Returns:** `STRING` like `$pbkdf2-sha256$i=600000$<salt>$<hash>`. It says how it was made (PBKDF2 with HMAC-SHA-256), so `password_verify` can check it later, even after the default changes.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:**
  - With 600000 rounds one call takes about 0.05 to 0.1 seconds on a PC with SHA instructions in the CPU, about 0.4 seconds without them.
  - In `INSERT ... VALUES` and `UPDATE ... SET`, a `password_hash('...')` with plain text is made **before** the statement takes the database lock, so other statements do not wait. The statement KarelaDB shows back has the finished hash, not the password.
  - Because of that, `UPDATE app_users SET password_hash = password_hash('x')` gives **every** changed row the same hash (one salt). Change passwords one row at a time (`WHERE id = ...`).
  - An empty password `''` is accepted. Check the length in your app.
  - Do not compare two hashes with `=`: each hash has its own salt, so they never match. Use `password_verify`.
  - PostgreSQL's pgcrypto way, `crypt(pw, gen_salt('bf'))`, works in KarelaDB too: see [crypt](#crypt). Use it when the hashes must also work in PostgreSQL. MySQL has no safe built-in password hash. KarelaDB's text follows the common `$name$settings$salt$hash` style, but other tools may write the salt and hash a little differently.

**Example: The same password twice gives two different hashes**

```sql
SELECT password_hash('correct horse battery') AS first, password_hash('correct horse battery') AS second;
```

Result:

| first (STRING) | second (STRING) |
|---|---|
| $pbkdf2-sha256$i=600000$AEJqHz277uyzogJujJxyDg$lI664bjp1JvkOTP9sIlB8vlExCHSkPhnaD1jeufLw24 | $pbkdf2-sha256$i=600000$HSwICvAx1ntfHhwZ7bXg9g$cs1D1f6nG8wSTpqlxqfdDPYy/1pNdpcxQNo5Ea/rWvs |

(1 row)

**Example: Register: store the hash, never the password**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE, password_hash STRING NOT NULL, created_at TIMESTAMP DEFAULT now());
```

```sql
INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', password_hash('correct horse battery'));
SELECT id, email, password_hash FROM app_users;
```

Result:

`INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', '$pbkdf2-sha256$i=600000$Bz`

```text
1 row(s) inserted
```

`SELECT id, email, password_hash FROM app_users`

| id (INT) | email (STRING) | password_hash (STRING) |
|---|---|---|
| 1 | sita@example.com | $pbkdf2-sha256$i=600000$Bz8xAYZ+ibP7v/DNUA1jSA$mjeVH4EmESVbgUbeJZLDWIkefXErKAsnxlwcR20hqwk |

(1 row)

**Example: The email is already registered** (shows an error)

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE, password_hash STRING NOT NULL);
INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', password_hash('correct horse battery'));
```

```sql
INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', password_hash('another password'));
```

Result:

Error: `column 'email' must be unique: 'sita@example.com' is already used`

**Example: Surprise: one UPDATE for many rows gives them all the same hash**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE, password_hash STRING NOT NULL);
INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', 'x'), ('ram@example.com', 'y');
```

```sql
UPDATE app_users SET password_hash = password_hash('Temporary-pass-1');
SELECT id, password_hash FROM app_users;
```

Result:

`UPDATE app_users SET password_hash = '$pbkdf2-sha256$i=600000$NsEqa+75z43j7e7rI1FxcA$+O4aQT2AuzGuE8j`

```text
2 row(s) updated
```

`SELECT id, password_hash FROM app_users`

| id (INT) | password_hash (STRING) |
|---|---|
| 1 | $pbkdf2-sha256$i=600000$NsEqa+75z43j7e7rI1FxcA$+O4aQT2AuzGuE8j0xyyq5l1oSqv5fyfNHmkTqYVLeSo |
| 2 | $pbkdf2-sha256$i=600000$NsEqa+75z43j7e7rI1FxcA$+O4aQT2AuzGuE8j0xyyq5l1oSqv5fyfNHmkTqYVLeSo |

(2 rows)

**Example: Fewer rounds: faster, but easier to guess** (shows an error)

```sql
SELECT password_hash('my password', 1000) AS ok_but_weak;
SELECT password_hash('my password', 500) AS too_few;
```

Result:

| ok_but_weak (STRING) |
|---|
| $pbkdf2-sha256$i=1000$2KE7pQHEc0MZGmueGsSG/Q$uCKbUwkW8EsN3nHR34ZT8VGfmoTh65YyRTuvyVUYB6U |

(1 row)

Error: `line 2, column 8: password_hash: iterations must be a whole number from 1000 to 10000000 (default 600000)`

## password_verify

Syntax:

```sql
password_verify(password, hash)
```

Checks if a typed password matches a hash made by `password_hash`.

| Argument | Type | Meaning |
|---|---|---|
| `password` | text | the password the user typed at login |
| `hash` | text | the stored hash, `$pbkdf2-sha256$i=...$...$...` |

- **Returns:** `BOOL`: `true` when the password is right, `false` when it is wrong **or** when the hash is damaged or not a KarelaDB hash. It never gives an error.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:**
  - It is as slow as `password_hash`. Call it **once** per login.
  - In `WHERE`, put the email test **first**: `WHERE email = ... AND password_verify(...)`. Then only the one matching row is checked. The other order checks the password of every user.
  - Show the same message for "no such email" and "wrong password" (for example "wrong email or password"), so nobody can find out which emails are registered.
  - It reads the rounds from the hash, so old hashes with other rounds still work.

**Example: Log in: right password gives the id, wrong password gives no row**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE, password_hash STRING NOT NULL);
INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', password_hash('correct horse battery'));
```

```sql
SELECT id FROM app_users WHERE email = 'sita@example.com' AND password_verify('correct horse battery', password_hash);
SELECT id FROM app_users WHERE email = 'sita@example.com' AND password_verify('wrong guess', password_hash);
```

Result:

`SELECT id FROM app_users WHERE email = 'sita@example.com' AND password_verify('correct horse battery`

| id (INT) |
|---|
| 1 |

(1 row)

`SELECT id FROM app_users WHERE email = 'sita@example.com' AND password_verify('wrong guess', passwor`

| id (INT) |
|---|

(0 rows)

**Example: Wrong, damaged and NULL hashes**

```sql
SELECT password_verify('secret-123', password_hash('secret-123', 1000)) AS right_password,
       password_verify('Secret-123', password_hash('secret-123', 1000)) AS capital_s,
       password_verify('secret-123', 'not a hash') AS damaged,
       password_verify('secret-123', NULL) AS no_hash;
```

Result:

| right_password (BOOL) | capital_s (BOOL) | damaged (BOOL) | no_hash (STRING) |
|---|---|---|---|
| true | false | false | NULL |

(1 row)

**Example: Change a password: check the old one, then store a new hash**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE, password_hash STRING NOT NULL);
INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', password_hash('old password 1'));
```

```sql
SELECT password_verify('old password 1', password_hash) AS old_is_right FROM app_users WHERE id = 1;
UPDATE app_users SET password_hash = password_hash('new password 2') WHERE id = 1;
SELECT password_verify('old password 1', password_hash) AS old_works, password_verify('new password 2', password_hash) AS new_works
FROM app_users WHERE id = 1;
```

Result:

`SELECT password_verify('old password 1', password_hash) AS old_is_right FROM app_users WHERE id = 1`

| old_is_right (BOOL) |
|---|
| true |

(1 row)

`UPDATE app_users SET password_hash = '$pbkdf2-sha256$i=600000$b9TdduXCBnL22H4NYoe0Jg$3pKWkwISYVl5ucj`

```text
1 row(s) updated
```

`SELECT password_verify('old password 1', password_hash) AS old_works, password_verify('new password `

| old_works (BOOL) | new_works (BOOL) |
|---|---|
| false | true |

(1 row)

## sha256

Syntax:

```sql
sha256(text)
sha256(bytes)
sha224(...), sha384(...), sha512(...)
```

The SHA-256 hash of a value. The same value always gives the same hash. It is fast. `sha224`, `sha384` and `sha512` are the other SHA-2 sizes and work the same way.

| Argument | Type | Meaning |
|---|---|---|
| `text` | text | the value to hash. Numbers, dates and other values are turned into text first. |
| `bytes` | `BYTES` | raw bytes to hash |

- **Returns:**
  - text in: `STRING` of lower-case hex characters (64 for `sha256`), KarelaDB's own handy form.
  - `BYTES` in: `BYTES`, the raw hash (32 bytes for `sha256`), as PostgreSQL's `sha256(bytea)` gives.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:**
  - The text is hashed as UTF-8 bytes, so text in any language (Nepali, Chinese, emoji) works.
  - Never use it for passwords: it is far too fast to guess. Use `password_hash`.
  - Good uses: store the hash of a session token or reset token (a stolen copy of the table can not be used to log in), find the same news article loaded twice, make a short key from a long text.
  - PostgreSQL code works as it is: `encode(sha256(convert_to(token, 'UTF8')), 'hex')` and `encode(sha256('abc'), 'hex')` give the 64 hex characters of the hash (KarelaDB encodes the hash's own bytes, not its hex text again).
  - For other hash kinds by name, use [digest](#digest). MySQL's `SHA2(text, 256)` returns hex like KarelaDB's text form.

**Example**

```sql
SELECT sha256('abc') AS abc, sha256('') AS empty, sha256(NULL) AS null_value;
```

Result:

| abc (STRING) | empty (STRING) | null_value (STRING) |
|---|---|---|
| ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 | NULL |

(1 row)

**Example: Bytes in, bytes out; the PostgreSQL way to get hex**

```sql
SELECT sha256('abc'::bytea) AS raw_hash,
       encode(sha256(convert_to('abc', 'UTF8')), 'hex') AS pg_style_hex,
       encode(sha256('abc'), 'hex') = sha256('abc') AS same_hex,
       sha512('abc') AS sha512_hex;
```

Result:

| raw_hash (BYTES) | pg_style_hex (STRING) | same_hex (BOOL) | sha512_hex (STRING) |
|---|---|---|---|
| \\xba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad | ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad | false | ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f |

(1 row)

**Example: Nepali text, and a number is hashed as its text**

```sql
SELECT sha256('नेपाल') AS nepal, sha256(123) = sha256('123') AS number_as_text, length(sha256('any text at all')) AS hex_chars;
```

Result:

| nepal (STRING) | number_as_text (BOOL) | hex_chars (LONG) |
|---|---|---|
| b57bd645ef34d014bb596b4c4ed6342637d1e2af00e86132ca34fb1673e6135b | true | 64 |

(1 row)

**Example: Find news articles that were loaded twice**

Setup:

```sql
CREATE TABLE news (id INT PRIMARY KEY AUTO, title STRING, body STRING);
INSERT INTO news (title, body) VALUES
  ('Index up 20 points', 'The index closed higher today.'),
  ('Index gains', 'The index closed higher today.'),
  ('Bank results', 'CITY reported its quarterly profit.');
```

```sql
SELECT sha256(body) AS body_hash, count(*) AS copies
FROM news
GROUP BY sha256(body)
HAVING count(*) > 1;
```

Result:

| body_hash (STRING) | copies (LONG) |
|---|---|
| 4c81bafab2be552b171006f4e3cd1eaf6b94743d2e1ac597e7366a95c394844c | 2 |

(1 row)

## digest

Syntax:

```sql
digest(value, type)
```

The hash of `value` as **bytes**, with the kind named by `type` (PostgreSQL's pgcrypto).

| Argument | Type | Meaning |
|---|---|---|
| `value` | text or `BYTES` | what to hash (text as its UTF-8 bytes) |
| `type` | `STRING` | `'md5'`, `'sha1'`, `'sha224'`, `'sha256'`, `'sha384'` or `'sha512'` (big or small letters) |

- **Returns:** `BYTES`. Use `encode(..., 'hex')` for hex text.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** another `type` is an error. `md5` and `sha1` are broken for security; use them only to match what another system gives.

**Example: The same text, three hash kinds**

```sql
SELECT encode(digest('abc', 'sha1'), 'hex') AS sha1,
       encode(digest('abc', 'md5'), 'hex') AS md5,
       encode(digest('abc', 'sha256'), 'hex') = sha256('abc') AS same_as_sha256;
```

Result:

| sha1 (STRING) | md5 (STRING) | same_as_sha256 (BOOL) |
|---|---|---|
| a9993e364706816aba3e25717850c26c9cd0d89d | 900150983cd24fb0d6963f7d28e17f72 | true |

(1 row)

## hmac_sha256

Syntax:

```sql
hmac_sha256(key, message)
```

A **signature** of a message made with a secret key (HMAC with SHA-256). Only someone who knows the key can make the same signature. Payment gateways and webhooks (a web site that calls your app) use it to prove that a message is real and was not changed.

| Argument | Type | Meaning |
|---|---|---|
| `key` | text | the secret key |
| `message` | text | the message to sign, for example the body of a request |

- **Returns:** `STRING` of 64 lower-case hex characters.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** the order is **key first**, then the message. PostgreSQL's pgcrypto writes `hmac(message, key, 'sha256')` (message first, returns `BYTEA`); MySQL has no HMAC function.

**Example**

```sql
SELECT hmac_sha256('key', 'The quick brown fox jumps over the lazy dog') AS signature;
```

Result:

| signature (STRING) |
|---|
| f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8 |

(1 row)

**Example: Check a webhook: is the signature in the request real?**

```sql
SELECT hmac_sha256('whsec_shop_secret_42', '{"order":1001,"amount":1500}')
         = 'f30505d17def40c02ad9b90fdaef65762d0c6b69cc93843c3228b506340bcfc1' AS real_message,
       hmac_sha256('whsec_shop_secret_42', '{"order":1001,"amount":15}')
         = 'f30505d17def40c02ad9b90fdaef65762d0c6b69cc93843c3228b506340bcfc1' AS amount_changed;
```

Result:

| real_message (BOOL) | amount_changed (BOOL) |
|---|---|
| true | false |

(1 row)

The signature `f30505d1...` came with the request. Only the real message with the right key gives the same signature. Compare signatures in your app with a constant-time compare when you can.

## random_bytes

Syntax:

```sql
random_bytes(n)
```

`n` random bytes from the operating system, written as hex (2 characters per byte).

| Argument | Type | Meaning |
|---|---|---|
| `n` | whole number | how many bytes: 1 to 1024. There is no default. |

- **Returns:** `STRING` of `2 * n` hex characters.
- **NULL:** `random_bytes(NULL)` is `NULL`.
- **Notes:** a new value for every call and every row. For tokens in links and cookies, `random_token` is shorter (URL-safe text). For raw `BYTES`, as PostgreSQL gives them, use [gen_random_bytes](#gen-random-bytes).

**Example**

```sql
SELECT random_bytes(4) AS four_bytes, random_bytes(16) AS api_secret, length(random_bytes(16)) AS hex_chars;
```

Result:

| four_bytes (STRING) | api_secret (STRING) | hex_chars (LONG) |
|---|---|---|
| d42e5366 | 70d10565b853aa7e17052623a53e3fb5 | 32 |

(1 row)

**Example: The number must be from 1 to 1024** (shows an error)

```sql
SELECT random_bytes(0);
```

Result:

Error: `line 1, column 8: random_bytes: the number of bytes must be a whole number from 1 to 1024`

**Example: The number is required** (shows an error)

```sql
SELECT random_bytes();
```

Result:

Error: `line 1, column 8: function 'random_bytes' takes 1 argument(s), got 0`

## random_token

Syntax:

```sql
random_token()
random_token(n)
```

`n` random bytes (default 32) as **URL-safe base64** text: letters, digits, `-` and `_`. It can go into a link or a cookie as it is. 32 bytes give 43 characters.

| Argument | Type | Meaning |
|---|---|---|
| `n` | whole number | how many random bytes: 1 to 1024. Default `32` (256 bits, strong enough for any token). |

- **Returns:** `STRING`.
- **NULL:** `random_token(NULL)` is `NULL`.
- **Notes:**
  - Use it for session tokens, "forgot password" links, email confirm links and API keys.
  - Send the token to the user, but store only `sha256(token)`. Then a stolen copy of the table can not be used.
  - A new value for every call and every row.

**Example**

```sql
SELECT random_token() AS session_token, random_token(16) AS shorter, length(random_token()) AS chars;
```

Result:

| session_token (STRING) | shorter (STRING) | chars (LONG) |
|---|---|---|
| ef1Byr8U4K74tNrLMzzFVuObic0jo3YxezoAAFkvlak | sWyNZOAlkXuSrOFNpTBOMA | 43 |

(1 row)

**Example: Forgot password: store the hash of a reset token for 30 minutes**

Setup:

```sql
CREATE TABLE password_resets (token_hash STRING PRIMARY KEY, user_id INT NOT NULL, expires_at TIMESTAMP NOT NULL);
```

```sql
SELECT random_token() AS token_for_the_email_link;
INSERT INTO password_resets VALUES (sha256('Qm9vSw1mY3Jk0x7Lr2nT5uV8wZ1aB4cD6eF9gH2jK3m'), 1, dateadd('m', 30, now()));
SELECT user_id FROM password_resets
WHERE token_hash = sha256('Qm9vSw1mY3Jk0x7Lr2nT5uV8wZ1aB4cD6eF9gH2jK3m') AND expires_at > now();
```

Result:

`SELECT random_token() AS token_for_the_email_link`

| token_for_the_email_link (STRING) |
|---|
| s0OjZHx2B2iJDW-npBx4F4oa5S5bnlLYr_xtw2NxSY0 |

(1 row)

`INSERT INTO password_resets VALUES (sha256('Qm9vSw1mY3Jk0x7Lr2nT5uV8wZ1aB4cD6eF9gH2jK3m'), 1, datead`

```text
1 row(s) inserted
```

`SELECT user_id FROM password_resets WHERE token_hash = sha256('Qm9vSw1mY3Jk0x7Lr2nT5uV8wZ1aB4cD6eF9g`

| user_id (INT) |
|---|
| 1 |

(1 row)

**Example: Too many bytes** (shows an error)

```sql
SELECT random_token(2000);
```

Result:

Error: `line 1, column 8: random_token: the number of bytes must be a whole number from 1 to 1024`

## gen_random_uuid

Syntax:

```sql
gen_random_uuid()
```

A random id in the standard UUID form (version 4), like `0465d47f-8194-4c94-a372-eda3b70504a0`. Two calls practically never give the same id.

- **Returns:** `STRING` of 36 characters. KarelaDB has no separate UUID column type: use a `STRING` column.
- **NULL:** takes no arguments.
- **Notes:**
  - Good as a public id of a forum post or an order, when you do not want people to guess the next id (`/post/7`, `/post/8`, ...).
  - `DEFAULT gen_random_uuid()` gives each new row its own id.
  - `ALTER TABLE ... ADD COLUMN id STRING DEFAULT gen_random_uuid()` gives all **old** rows one and the same value; only new rows get their own.
  - The same name and form as PostgreSQL 13 and newer. MySQL's `UUID()` makes version 1 ids (based on time, not random).

**Example**

```sql
SELECT gen_random_uuid() AS id, length(gen_random_uuid()) AS chars;
```

Result:

| id (STRING) | chars (LONG) |
|---|---|
| 7fee4fb5-134e-4138-b2d3-d4c83f3e88d3 | 36 |

(1 row)

**Example: Forum posts with a random public id**

Setup:

```sql
CREATE TABLE forum_posts (public_id STRING PRIMARY KEY DEFAULT gen_random_uuid(), author STRING, title STRING);
```

```sql
INSERT INTO forum_posts (author, title) VALUES ('sita', 'CITY dividend news'), ('ram', 'बजार आज कस्तो होला?');
SELECT public_id, author, title FROM forum_posts;
```

Result:

`INSERT INTO forum_posts (author, title) VALUES ('sita', 'CITY dividend news'), ('ram', 'बजार आज कस्त`

```text
2 row(s) inserted
```

`SELECT public_id, author, title FROM forum_posts`

| public_id (STRING) | author (STRING) | title (STRING) |
|---|---|---|
| 9fa7000c-1164-49c6-935f-1e9b07b5fbf9 | ram | बजार आज कस्तो होला? |
| dd3f7069-8645-416f-a008-3a6ff5cf62ff | sita | CITY dividend news |

(2 rows)

**Example: No arguments** (shows an error)

```sql
SELECT gen_random_uuid(4);
```

Result:

Error: `line 1, column 8: function 'gen_random_uuid' takes 0 argument(s), got 1`

<a id="pgcrypto"></a>

## PostgreSQL pgcrypto functions

KarelaDB has the functions of PostgreSQL's **pgcrypto** extension, and they give the **same bytes**. Data encrypted in PostgreSQL opens in KarelaDB, and data encrypted in KarelaDB opens in PostgreSQL (and in GnuPG). There is no `CREATE EXTENSION` to run: they are always there.

| Function | What it does |
|---|---|
| [pgp_sym_encrypt](#pgp-sym-encrypt) / [pgp_sym_decrypt](#pgp-sym-decrypt) | encrypt with a password (OpenPGP). The best choice for secrets you must read back. |
| [encrypt / decrypt](#encrypt) | raw AES, Blowfish or DES with a key you manage yourself |
| [crypt / gen_salt](#crypt) | password hashes: bcrypt `$2a$`, MD5 `$1$`, DES |
| [gen_random_bytes](#gen-random-bytes) | random `BYTES` from the operating system |
| [armor / dearmor](#armor) | encrypted bytes as `-----BEGIN PGP MESSAGE-----` text, and back |
| [base64](#base64) | QuestDB's `base64(data, maxLength)` |

Errors use PostgreSQL's words and codes. Most are SQLSTATE `39000`, for example `Wrong key or corrupt data`.

## pgp_sym_encrypt

Syntax:

```sql
pgp_sym_encrypt(text, password)
pgp_sym_encrypt(text, password, options)
pgp_sym_encrypt_bytea(bytes, password [, options])
```

Encrypts with a password. The result is an **OpenPGP** message (RFC 4880), the format of GnuPG: a key made from the password with a random salt (65536 to 253952 bytes of SHA-1 hashing), AES-128, and a SHA-1 check that finds any change to the message.

| Argument | Type | Meaning |
|---|---|---|
| `text` / `bytes` | text or `BYTES` | what to encrypt |
| `password` | text | the password |
| `options` | text | optional, like `'cipher-algo=aes256, s2k-count=65536'` (see the table below) |

| Option | Values | Default |
|---|---|---|
| `cipher-algo` | `aes128` (`aes`), `aes192`, `aes256`, `bf`, `3des` | `aes128` |
| `s2k-mode` | `0` plain, `1` salted, `3` salted and repeated | `3` |
| `s2k-count` | 1024 to 65011712 bytes of hashing (with `s2k-mode=3`) | random, 65536 to 253952 |
| `s2k-digest-algo` | `sha1`, `md5`, `sha256`, `sha384`, `sha512` | `sha1` |
| `sess-key` | `1`: a random session key, encrypted with the password key | `0` |
| `s2k-cipher-algo` | cipher for the session key (with `sess-key=1`) | as `cipher-algo` |
| `disable-mdc` | `1`: no integrity check (old format; do not use) | `0` |
| `convert-crlf` | `1`: line ends become `\r\n` | `0` |
| `unicode-mode` | `1`: mark the text as UTF-8 | `0` |
| `compress-algo` | `0` only (KarelaDB does not compress) | `0` |

- **Returns:** `BYTES`. The same text gives different bytes every time (a new salt and a random start).
- **NULL:** `NULL` in, `NULL` out.
- **Notes:**
  - Keep the result in a `BYTES` column. `armor()` turns it into text that GnuPG reads: `gpg --decrypt`.
  - Each call hashes the password again (on purpose, it makes guessing slow): about 0.05 ms per row on a CPU with SHA instructions. For millions of rows, `s2k-count=1024` is about 10 times faster but easier to guess.
  - `cast5`, `twofish` and `compress-algo` 1 or 2 are refused (SQLSTATE `0A000`); PostgreSQL has them. `pgp_pub_encrypt` (public keys) is refused too.

**Example: Encrypt a secret, read it back**

```sql
SELECT pgp_sym_decrypt(pgp_sym_encrypt('secret', 'pw'), 'pw') AS back,
       length(pgp_sym_encrypt('secret', 'pw')) AS bytes;
```

Result:

| back (STRING) | bytes (LONG) |
|---|---|
| secret | 72 |

(1 row)

**Example: Store encrypted phone numbers**

Setup:

```sql
CREATE TABLE customers (id INT PRIMARY KEY AUTO, name STRING, phone BYTES);
```

```sql
INSERT INTO customers (name, phone) VALUES ('Sita', pgp_sym_encrypt('9841000001', 'shop-key-2026', 'cipher-algo=aes256'));
SELECT name, pgp_sym_decrypt(phone, 'shop-key-2026') AS phone FROM customers;
```

Result:

`INSERT INTO customers (name, phone) VALUES ('Sita', pgp_sym_encrypt('9841000001', 'shop-key-2026', '`

```text
1 row(s) inserted
```

`SELECT name, pgp_sym_decrypt(phone, 'shop-key-2026') AS phone FROM customers`

| name (STRING) | phone (STRING) |
|---|---|
| Sita | 9841000001 |

(1 row)

**Example: As text GnuPG reads**

```sql
SELECT armor(pgp_sym_encrypt('hello gpg', 'pw')) AS message;
```

Result:

| message (STRING) |
|---|
| -----BEGIN PGP MESSAGE-----  ww0EBwMCEkfmllFHwKxq0joBYddnBOgp6xGgTMhSe0o8TvXzo1cMXXl1edLJver4dB322JUucoQn bLisdtiIcqwU8dyzEtuj5KAd =sCfI -----END PGP MESSAGE-----  |

(1 row)

## pgp_sym_decrypt

Syntax:

```sql
pgp_sym_decrypt(message, password [, options])
pgp_sym_decrypt_bytea(message, password [, options])
```

Opens a message made by `pgp_sym_encrypt`, by PostgreSQL's pgcrypto or by `gpg --symmetric`.

| Argument | Type | Meaning |
|---|---|---|
| `message` | `BYTES` | the encrypted message (`dearmor()` it first if it is text) |
| `password` | text | the password |
| `options` | text | only `convert-crlf=1` matters here: `\r\n` becomes `\n` |

- **Returns:** `pgp_sym_decrypt` gives `STRING`, `pgp_sym_decrypt_bytea` gives `BYTES`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:**
  - A wrong password, a changed byte or a cut message all give one error: `Wrong key or corrupt data` (SQLSTATE `39000`). It never gives wrong text.
  - It reads AES-128/192/256, Blowfish and 3DES, all key kinds, and ZIP and ZLIB compression (what GnuPG writes by default).
  - Data encrypted as bytes gives `Not text data` in `pgp_sym_decrypt`: use `pgp_sym_decrypt_bytea`. Text that is not valid UTF-8 gives SQLSTATE `22021`.

**Example: The wrong password is an error, never wrong text** (shows an error)

```sql
SELECT pgp_sym_decrypt(pgp_sym_encrypt('secret', 'pw'), 'pw') AS right_password;
SELECT pgp_sym_decrypt(pgp_sym_encrypt('secret', 'pw'), 'guess') AS wrong_password;
```

Result:

| right_password (STRING) |
|---|
| secret |

(1 row)

Error: `line 2, column 8: Wrong key or corrupt data`

**Example: A message PostgreSQL's pgcrypto made (password foobar)**

```sql
SELECT pgp_sym_decrypt(dearmor('-----BEGIN PGP MESSAGE-----

jA0EBwMCci97v0Q6Z0Zg0kQBsVf5Oe3iC+FBzUmuMV9KxmAyOMyjCc/5i8f1Eest
UTAsG35A1vYs02VARKzGz6xI2UHwFUirP+brPBg3Ee7muOx8pA==
=XtrP
-----END PGP MESSAGE-----'), 'foobar') AS from_postgres;
```

Result:

| from_postgres (STRING) |
|---|
| Secret message. |

(1 row)

## encrypt

Syntax:

```sql
encrypt(data, key, type)
decrypt(data, key, type)
encrypt_iv(data, key, iv, type)
decrypt_iv(data, key, iv, type)
```

Raw encryption with a key you keep yourself. `type` is the cipher, then optionally `-mode` and `/pad:`:

| Part | Values | Default |
|---|---|---|
| cipher | `aes` (key up to 32 bytes: AES-128, 192 or 256 by length), `bf` (Blowfish), `des`, `3des` | - |
| mode | `-cbc`, `-ecb` (`bf-cfb` too) | `-cbc` |
| padding | `/pad:pkcs`, `/pad:none` | `/pad:pkcs` |

- **Returns:** `BYTES`. Use `convert_from(decrypt(...), 'UTF8')` for text.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:**
  - A short key is filled with zero bytes, as pgcrypto does: `'k'` is the AES-128 key `6b000000...`.
  - The same data and key always give the same bytes (the IV is zero). `encrypt_iv` takes your own IV.
  - `decrypt` can **not** tell a wrong key: it gives wrong bytes, as in PostgreSQL. Prefer `pgp_sym_encrypt`, which checks.
  - A wrong `type` gives `Cannot use "...": No such cipher algorithm` (SQLSTATE `22023`).
  - A statement that uses one key for many rows prepares the key once.

**Example: Encrypt and decrypt with AES**

```sql
SELECT encrypt('x', 'k', 'aes') AS encrypted,
       convert_from(decrypt(encrypt('x', 'k', 'aes'), 'k', 'aes'), 'UTF8') AS back;
```

Result:

| encrypted (BYTES) | back (STRING) |
|---|---|
| \\xc7c594ca6690a3fd6861111945a9c1f5 | x |

(1 row)

**Example: The FIPS 197 test: one AES block, no padding**

```sql
SELECT encode(encrypt('\x00112233445566778899aabbccddeeff'::bytea, '\x000102030405060708090a0b0c0d0e0f'::bytea, 'aes-ecb/pad:none'), 'hex') AS block;
```

Result:

| block (STRING) |
|---|
| 69c4e0d86a7b0430d8cdb78070b4c55a |

(1 row)

**Example: Not a cipher** (shows an error)

```sql
SELECT encrypt('x', 'k', 'rot13');
```

Result:

Error: `line 1, column 8: Cannot use "rot13": No such cipher algorithm`

## crypt

Syntax:

```sql
crypt(password, salt)
gen_salt(type)
gen_salt(type, rounds)
```

pgcrypto's password hashes. `gen_salt` makes a new random salt; `crypt` makes the hash. To check a password later, give `crypt` the stored hash as the salt: the right password gives the same hash back.

| `type` | Hash | `rounds` |
|---|---|---|
| `'bf'` | bcrypt, `$2a$` + 60 characters. The one to use. | 4 to 31, default 6. Each step up doubles the time. |
| `'md5'` | MD5-crypt, `$1$` | fixed |
| `'xdes'` | extended DES, `_` | odd, 1 to 16777215, default 725 |
| `'des'` | old DES: only 8 characters of the password count | fixed |

- **Returns:** `STRING`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:**
  - The hashes are the same as PostgreSQL's (and Linux's `crypt()`), so users can move between the two.
  - bcrypt uses only the first 72 bytes of a password.
  - A salt it can not use gives `crypt(3) returned NULL` (SQLSTATE `39000`). An unknown type in `gen_salt` gives SQLSTATE `22023`.
  - A high `rounds` can take very long (31 is hours); the statement timeout stops it.
  - KarelaDB's own [password_hash](#password-hash) is the simpler choice when PostgreSQL does not need the hashes.

**Example: Register and log in with bcrypt**

Setup:

```sql
CREATE TABLE app_users (email STRING PRIMARY KEY, pw_hash STRING NOT NULL);
```

```sql
INSERT INTO app_users VALUES ('sita@example.com', crypt('correct horse', gen_salt('bf', 8)));
SELECT left(pw_hash, 7) AS kind,
       crypt('correct horse', pw_hash) = pw_hash AS right_password,
       crypt('wrong guess', pw_hash) = pw_hash AS wrong_password
FROM app_users;
```

Result:

`INSERT INTO app_users VALUES ('sita@example.com', crypt('correct horse', gen_salt('bf', 8)))`

```text
1 row(s) inserted
```

`SELECT left(pw_hash, 7) AS kind, crypt('correct horse', pw_hash) = pw_hash AS right_password, crypt(`

| kind (STRING) | right_password (BOOL) | wrong_password (BOOL) |
|---|---|---|
| $2a$08$ | true | false |

(1 row)

**Example: The same hash as PostgreSQL and Linux**

```sql
SELECT crypt('pw', '$1$saltsalt') AS md5_crypt, crypt('pw', 'ab') AS old_des;
```

Result:

| md5_crypt (STRING) | old_des (STRING) |
|---|---|
| $1$saltsalt$6SNdNaZLKst2LlSm7oPPL1 | abzlUXK5ed5rs |

(1 row)

**Example: Too few rounds** (shows an error)

```sql
SELECT gen_salt('bf', 3);
```

Result:

Error: `line 1, column 8: gen_salt: Incorrect number of rounds`

## gen_random_bytes

Syntax:

```sql
gen_random_bytes(n)
```

`n` random bytes from the operating system's secure random generator, as `BYTES` (pgcrypto's form; [random_bytes](#random-bytes) gives hex text).

| Argument | Type | Meaning |
|---|---|---|
| `n` | whole number | 1 to 1024 |

- **Returns:** `BYTES`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** a new value for every call and every row. Another `n` gives `Length not in range` (SQLSTATE `39000`).

**Example**

```sql
SELECT length(gen_random_bytes(16)) AS bytes, encode(gen_random_bytes(8), 'hex') AS hex;
```

Result:

| bytes (LONG) | hex (STRING) |
|---|---|
| 16 | ca286c700826ad30 |

(1 row)

## armor

Syntax:

```sql
armor(data)
armor(data, keys, values)
dearmor(text)
```

`armor` writes bytes as OpenPGP text: `-----BEGIN PGP MESSAGE-----`, base64 lines of 76 characters and a CRC-24 check line. `dearmor` reads such text back into bytes. `keys` and `values` are two arrays of header lines (`Comment: ...`).

- **Returns:** `armor` gives `STRING`, `dearmor` gives `BYTES`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** text with a wrong check line or a character that is not base64 gives `Corrupt ascii-armor` (SQLSTATE `39000`). Text before and after the block is skipped.

**Example: Bytes to text and back**

```sql
SELECT armor('\x01'::bytea) AS text, dearmor(armor('\x01'::bytea)) AS back;
```

Result:

| text (STRING) | back (BYTES) |
|---|---|
| -----BEGIN PGP MESSAGE-----  AQ== =5yUo -----END PGP MESSAGE-----  | \\x01 |

(1 row)

**Example: With a header line**

```sql
SELECT armor('\x01'::bytea, ARRAY['Comment'], ARRAY['made by KarelaDB']) AS text;
```

Result:

| text (STRING) |
|---|
| -----BEGIN PGP MESSAGE----- Comment: made by KarelaDB  AQ== =5yUo -----END PGP MESSAGE-----  |

(1 row)

## base64

Syntax:

```sql
base64(data, maxLength)
```

QuestDB's function: the standard base64 text of the first `maxLength` bytes of `data`.

- **Returns:** `STRING`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** `maxLength` must be more than 0. For whole values, `encode(data, 'base64')` and `to_base64(data)` work too.

**Example**

```sql
SELECT base64('ab', 10) AS whole, base64('abcdef', 3) AS first_three;
```

Result:

| whole (STRING) | first_three (STRING) |
|---|---|
| YWI= | YWJj |

(1 row)

<a id="app-login"></a>

## App register, login and sessions

Syntax:

```sql
register:  INSERT ... password_hash('password')
login:     SELECT ... WHERE email = ... AND password_verify('password', password_hash)
session:   random_token()  ->  store sha256(token) with an expiry time
request:   SELECT ... WHERE token_hash = sha256('token') AND expires_at > now()
log out:   DELETE ... WHERE token_hash = sha256('token')
```

The whole way an app lets people register, log in and stay logged in. Your backend (the server program of your app) runs these statements. The browser only ever gets the token.

| Step | What your backend does |
|---|---|
| Register | stores `password_hash(password)`; `UNIQUE` on the email stops a second account |
| Log in | finds the user with `password_verify`; on "no row" says "wrong email or password" |
| Session | makes `random_token()`, sends it as a cookie (`HttpOnly; Secure; SameSite=Lax`), stores `sha256(token)` with an expiry |
| Every request | finds the user by `sha256(token)` and `expires_at > now()`: fast, no slow hash |
| Log out | deletes the session row |

- **Returns:** see each function above.
- **NULL:** a `NULL` token or password finds no row.
- **Notes:**
  - Always send user text as **parameters** of your driver (`$1`, `$2`), never glued into the SQL text (that allows SQL injection).
  - Count failed logins per email and per IP address in your app and wait longer after each failure. KarelaDB does this for its own logins, not for your tables.
  - Delete old sessions now and then: `DELETE FROM app_sessions WHERE expires_at < now();`
  - After a password change, delete the user's other sessions.

**Example: The complete flow: register, log in, session, request, log out**

Setup:

```sql
CREATE TABLE app_users (
  id INT PRIMARY KEY AUTO,
  email STRING NOT NULL UNIQUE,
  password_hash STRING NOT NULL,
  created_at TIMESTAMP DEFAULT now()
);
CREATE TABLE app_sessions (
  token_hash STRING PRIMARY KEY,
  user_id INT NOT NULL REFERENCES app_users(id),
  expires_at TIMESTAMP NOT NULL
);
```

```sql
-- 1. register
INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', password_hash('correct horse battery'));
-- 2. log in: one row means the password is right
SELECT id FROM app_users WHERE email = 'sita@example.com' AND password_verify('correct horse battery', password_hash);
-- 3. make a token for the cookie; below, one fixed token stands for it, so the steps fit together
SELECT random_token() AS token;
INSERT INTO app_sessions VALUES (sha256('mR3v7yJ2nqKx0Qe8i4uX1t9LZbF5cH6aWgD2sP0oVkE'), 1, dateadd('d', 7, now()));
-- 4. every request: who is this?
SELECT u.id, u.email
FROM app_sessions s JOIN app_users u ON u.id = s.user_id
WHERE s.token_hash = sha256('mR3v7yJ2nqKx0Qe8i4uX1t9LZbF5cH6aWgD2sP0oVkE') AND s.expires_at > now();
-- 5. log out
DELETE FROM app_sessions WHERE token_hash = sha256('mR3v7yJ2nqKx0Qe8i4uX1t9LZbF5cH6aWgD2sP0oVkE');
SELECT count(*) AS sessions_left FROM app_sessions;
```

Result:

`INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', '$pbkdf2-sha256$i=600000$6c`

```text
1 row(s) inserted
```

`SELECT id FROM app_users WHERE email = 'sita@example.com' AND password_verify('correct horse battery`

| id (INT) |
|---|
| 1 |

(1 row)

`SELECT random_token() AS token`

| token (STRING) |
|---|
| 72rweLEV8CvqGW4Og3SM6SGYynQjnve9nQPE7hzC-Js |

(1 row)

`INSERT INTO app_sessions VALUES (sha256('mR3v7yJ2nqKx0Qe8i4uX1t9LZbF5cH6aWgD2sP0oVkE'), 1, dateadd('`

```text
1 row(s) inserted
```

`SELECT u.id, u.email FROM app_sessions AS s JOIN app_users AS u ON u.id = s.user_id WHERE s.token_ha`

| id (INT) | email (STRING) |
|---|---|
| 1 | sita@example.com |

(1 row)

`DELETE FROM app_sessions WHERE token_hash = sha256('mR3v7yJ2nqKx0Qe8i4uX1t9LZbF5cH6aWgD2sP0oVkE')`

```text
1 row(s) deleted
```

`SELECT count(*) AS sessions_left FROM app_sessions`

| sessions_left (LONG) |
|---|
| 0 |

(1 row)
