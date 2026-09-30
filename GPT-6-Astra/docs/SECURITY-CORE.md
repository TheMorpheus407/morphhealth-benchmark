# Shared-core storage security

The core is pure Dart and is shared by Android and the Linux maintenance process.
Cryptographic primitives come from the pinned `cryptography` 2.9.0 package;
application code does not implement AES, GCM, SHA-256 or PBKDF2. Random bytes use
Dart's `Random.secure`. See the top-level SECURITY.md for Android key custody,
file export UI and operating-system protections.

## Local file

`data-dir/health.mhenc` is a UTF-8 JSON envelope:

```json
{"format":"morphhealth-encrypted","version":1,"kind":"store","cipher":"AES-256-GCM","compression":"gzip","nonce":"BASE64_12_BYTES","ciphertext":"BASE64_CIPHERTEXT","mac":"BASE64_16_BYTES"}
```

The logical plaintext is the entire canonical portable document described in
FORMAT.md. New files gzip-compress its UTF-8 JSON before encryption, using Dart
SDK `GZipCodec` (`dart:io`). Compression runs in the same background isolate as
encryption and greatly reduces repetitive meal-snapshot storage. Encryption uses a 256-bit random installation key, a new 96-bit nonce on every
save, and a 128-bit GCM authentication tag. Additional authenticated data (AAD)
is the exact UTF-8 string:

```text
morphhealth-encrypted|1|store|AES-256-GCM|compression=gzip
```

The optional v1 header `compression` accepts only the string `gzip`; an absent
field means the original uncompressed v1 payload and **omits the complete
`|compression=gzip` suffix from AAD**. Older stores and backups therefore remain
readable with their original authentication rules. A store is rewritten in the
compressed form only on its next successful commit. Adding/removing the field
from a valid file changes AAD and fails authentication. Other compression values,
including explicit null, are rejected.

The 64 MiB document bound is checked on the UTF-8 JSON **before compression**.
On reads, GCM authentication completes **before decompression**. The gzip decoder
receives compressed data in 512-byte chunks and writes through a bounded output
sink; it aborts before retaining more than 64 MiB of decompressed bytes. This
avoids inflating an entire expansion bomb before checking its size. Malformed
gzip data fails closed. The 100 MiB encrypted-file cap also continues to apply.

Only the format/version/type/cipher/compression and ciphertext length are visible without a
key. Dates, names, notes, quantities and settings are encrypted together.

CLI keys are 32 raw bytes in a caller-provided file outside `data-dir`; the CLI
checks length and resolves symlinks before enforcing the separate location.
There is no passphrase-based local key shortcut. A lost key cannot be recovered
from the encrypted data. Android's key is supplied through the native/secure
storage layer and uses exactly the same Store class and cipher format.

The Store holds a cooperative exclusive file lock at `.lock` for its lifetime.
Within a process, writes are queued. Each transaction builds the next state,
encrypts it, writes **ciphertext only** to `health.mhenc.pending`, flushes the file,
and atomically renames it over the committed file. The in-memory state advances
only after that succeeds. A rejected transaction cannot poison the queue. On
open, a leftover uncommitted pending file is discarded only after authenticating
the committed file. The main file is never silently replaced after a wrong key,
corruption, unsupported version or authentication failure.

The containing directory is not explicitly fsynced after rename by portable
Dart APIs. Atomic replacement protects against mixed/partial snapshots; the
strongest guarantees against a device power loss depend on the filesystem.
There is no rollback detection if an attacker with filesystem access substitutes
an older authentic snapshot. Locking is cooperative, not a defense against
privileged malware. The plaintext exists in process memory while in use, and a
full snapshot is held in memory. Expensive encryption/decryption runs in an
isolate to keep the UI event loop available.

## Passphrase backup

An exported encrypted backup is a separate interoperable envelope:

```json
{"format":"morphhealth-encrypted","version":1,"kind":"backup","cipher":"AES-256-GCM","compression":"gzip","kdf":{"name":"PBKDF2-HMAC-SHA256","iterations":600000,"salt":"BASE64_16_BYTES"},"nonce":"BASE64_12_BYTES","ciphertext":"BASE64_CIPHERTEXT","mac":"BASE64_16_BYTES"}
```

A 256-bit key is derived from the exact UTF-8 passphrase by PBKDF2-HMAC-SHA256,
600,000 iterations, and a new random 128-bit salt. Accepted passphrases have
10–1024 Dart string code units; no trimming, Unicode normalization or silent
truncation is applied. Use a long unique phrase. The backup has a fresh random
nonce independent of the salt. Its authenticated header string is exactly:

```text
morphhealth-encrypted|1|backup|AES-256-GCM|PBKDF2-HMAC-SHA256|600000|BASE64_SALT|compression=gzip
```

The backup's derived key is not the installation key. Restoration authenticates,
decrypts and validates the portable document, then commits it under the fresh
installation's local key. An incorrect passphrase or changed ciphertext fails
with `authentication_failed`. Unsupported/altered KDF parameters are rejected
before derivation, including iteration counts that could weaken security or
cause unbounded resource consumption. Missing/malformed nonce/tag/salt lengths
and unsupported header fields are rejected. Encrypted input is capped at 100
MiB and decrypted portable content at 64 MiB. No local key or passphrase is
included in a backup or logged by the core.

## Export, deletion and networking

Portable exports are intentionally **plaintext**, machine-readable JSON. The CLI
requires `ack_plaintext:true`. Store replacement requires `confirm_replace:true`
and validates the complete candidate before writing. Android requests equivalent
explicit user actions. Exports written to a user-selected location remain under
the user's control; deleting local data does not erase already exported files.

Clearing the store atomically replaces its content with an empty encrypted
instance. It does not promise physical erasure of historical flash blocks,
filesystem snapshots or external copies. Installation-key removal/rotation is
managed by the platform integration. Closing the core clears its owned key byte
list, but Dart's garbage-collected memory and copies made by cryptographic
libraries/isolates cannot provide a comprehensive memory zeroization guarantee.

Only explicit food searches/lookups send a query or barcode and the configured
User-Agent to the configured HTTPS origin. Personal journal documents are never
sent. TLS uses the system trust store with no certificate-validation bypass.
Redirects are disabled. The adapter has timeouts and response size limits. There
is no telemetry, analytics, advertising, runtime AI, account or backend service
in this core.

## Verification

`app/test/core_test.dart` checks wrong keys, altered ciphertext, malformed
portable input, failed import preservation, serialized concurrent updates,
randomized nonces, backups restored under a different installation key and KDF
header rejection. Independent original-v1 fixtures cover uncompressed store and
backup compatibility; additional tests check authenticated compression metadata,
malformed gzip and bounded decompression of a highly compressed expansion bomb. It also tests nutrient correctness/missingness, old and new
OFF schemas, all nutrient conversions, dates/DST, overlap constraints, forecast
uncertainty/retrospective behavior, history filtering, and 10,000-record
persistence. These checks are implementation tests, not a third-party security
audit. Actual measurements and execution logs are reported with the final build.
