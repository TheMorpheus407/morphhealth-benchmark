# MorphHealth: portable data and local maintenance interface

The Android application and `app/bin/mh.dart` import the same pure Dart library,
`app/lib/core/core.dart`. There is one schema, nutrition calculator, forecast,
food adapter and encrypted store. The CLI does not read a second test database or
implement alternative calculations. Its chosen `--data-dir` is a persistent
instance of that production store. On Android, the instance lives in the app's
private directory; a portable export or backup transfers an instance's content.

## Running the JSON-lines process

```sh
./mh --data-dir /absolute/path/to/data --key-file /absolute/path/to/key \
  --now 2026-09-17T12:00:00+02:00 \
  --food-base-url https://localhost:8788 \
  --food-user-agent 'MorphHealth/1.0-rc3 (benchmark build)'
```

The key file must already contain exactly **32 raw random bytes**, not hexadecimal
or Base64 text. It must be outside `data-dir`; symbolic links are resolved when
checking this. Preserve the key securely: a store cannot be opened without it.
The CLI neither generates nor prints a key. Restrict the containing directory to
your user, for example mode 0700, and the key to mode 0600. A backup uses a separate
passphrase and does not need the original installation key on restore.

The food flags override `ENVIRONMENT.json`, read relative to the CLI's source
location, independently of the shell's working directory. Only HTTPS origins,
without embedded credentials, path or query, are accepted. The supplied manifest
is never changed. Normal deployments can specify `https://world.openfoodfacts.org`.
The benchmark manifest points to the supplied service and is the default here.

Each UTF-8 line is one request object. Each response is one JSON line and is
flushed immediately. EOF closes the database and exits. Stdout has no banner;
startup errors go to stderr with a nonzero exit status. Requests execute in
order. A bad request returns an error and leaves the process usable.

```json
{"request_id":"a","op":"describe"}
{"request_id":"b","op":"nutrition.day","date":"2026-09-17"}
{"request_id":"c","op":"cycle.forecast","on":"2026-09-17"}
{"request_id":"d","op":"food.search","q":"Hafer","page":1}
{"request_id":"e","op":"food.lookup","barcode":"5411188115366"}
{"request_id":"f","op":"portable.export","ack_plaintext":true}
```

A successful response has `{"request_id":…, "ok":true, "data":…}`. An error has
`{"request_id":…, "ok":false, "error":{"code":"…","message":"…"}}`.
`request_id` is echoed unchanged; malformed JSON uses null because its ID cannot
be read. Messages are English; stable codes include `invalid_request`,
`invalid_json`, `unknown_operation`, `confirmation_required`, `invalid_document`,
`overlapping_periods`, `invalid_date`, `food_offline`, `food_timeout`,
`food_rate_limited`, `food_http`, `food_tls` and `authentication_failed`.

`describe.data` documents every operation and all nutrient units. Its
`exampleDocument` is a complete, directly importable example, including foods,
meal, water, periods, weight and symptom. Import it with:

```json
{"request_id":"import","op":"portable.import","confirm_replace":true,"document":{"format":"morphhealth","version":1,"settings":{},"foods":[],"meals":[],"drinks":[],"periods":[],"weights":[],"symptoms":[]}}
```

The inline example is intentionally an empty instance. Use `exampleDocument`
from `describe` for populated data. A successful import reports
`{"replaced":true,"counts":{"foods":0,"meals":0,"drinks":0,"periods":0,"weights":0,"symptoms":0}}`.
Validation completes before the current instance is replaced atomically. Exports
contain unencrypted health data; therefore `ack_plaintext:true` is mandatory.
Replacement requires `confirm_replace:true`. These are request-level protections,
not an interactive CLI prompt.

`--now` freezes the business clock. Its supplied civil date and time are retained
for calendar-day defaults rather than shifted by its offset into another date.
Without it the system clock is read for every request. Normally provide `date` or
`on` explicitly; if omitted, those two read operations use this clock's day.
`describe` reports the effective clock and `today`. Clock settings never rewrite
stored timestamps. An explicit food operation authorizes that network read;
Android additionally offers the `onlineFood` preference.

Local encrypted snapshots and passphrase backups now gzip-compress the portable
JSON before AES-256-GCM encryption. Their v1 envelope includes
`compression:"gzip"`, authenticated by the suffix `|compression=gzip` in AAD.
An absent compression field selects the original uncompressed v1 representation
and original AAD; existing files remain readable. Unknown compression values are
rejected. This changes no portable JSON field, unit or calculation. The 64 MiB
limit always applies to the uncompressed UTF-8 document. Authenticated compressed
payloads are decoded incrementally with a hard output limit; the full wire
contract is in [SECURITY-CORE.md](SECURITY-CORE.md).

## Portable schema version 1

The top-level object contains `format:"morphhealth"`, `version:1`, `settings`,
and arrays `foods`, `meals`, `drinks`, `periods`, `weights`, `symptoms`. Required
arrays must exist. IDs are nonempty strings, unique within each array. Notes
are strings and default to `""`. Numbers must be finite JSON numbers, not strings.
Unsupported versions, unknown fields, duplicate IDs and invalid dates are errors.
Imports normalize optional fields/default settings and all missing nutrient
values to null. Export returns the normalized complete document. Maximum input:
100,000 records total and 64 MiB encoded plaintext. The product target is 10,000
journal entries.

Dates are real `YYYY-MM-DD` calendar dates. Timestamps are
`YYYY-MM-DDTHH:mm:ss[.fraction][Z|±HH:mm]`, accepting the local timestamps emitted
by Android's date/time controls. Fractional seconds accept 1–6 digits. An entry
belongs to the date prefix actually entered. A timestamp with an offset is not
shifted into a different diary day. Calendar-day arithmetic uses UTC midnights,
so daylight-saving transitions do not change cycle lengths.

| Settings field | Type and meaning |
|---|---|
| `language` | `de` (default) or `en` |
| `weightUnit` | `kg` (default) or `lb`; underlying values are always kg |
| `onlineFood` | boolean, default false; Android online search control |
| `cyclePredictions` | boolean, default true; false is diary mode |
| `visible` | booleans `nutrition`, `cycle`, `weight`, `symptoms`, default true |
| `goals` | `water` in ml, `energy` in kcal, `protein`, `carbs`, `fat` in g; each positive number or null |

| Collection | Fields |
|---|---|
| `foods` | `id`, nonempty `name`, `source` (`custom` default or `off`), optional `barcode` and `brand`, `basis` (`g` default or `ml`), `servingSize` (positive number in basis units, or null), `nutrients` object, `favorite` boolean (default false) |
| `meals` | `id`, `food` (complete food snapshot), positive `amount`, `unit` (`g`, `ml`, `serving`), `at`, `meal` (`breakfast`, `lunch`, `dinner`, `snack`), `note` |
| `drinks` | `id`, `kind` (`water` or `caffeine`), positive `amount` (ml or mg respectively), `at`, `note` |
| `periods` | `id`, `start`, `end` (inclusive dates, null means ongoing), `flow` (`spotting`, `light`, `medium`, `heavy`), `note` |
| `weights` | `id`, `at`, positive `kg` (maximum 2000), `note` |
| `symptoms` | `id`, `at`, nonempty `name`, integer `intensity` 0–10, `note` |

Non-spotting period episodes cannot overlap, and an ongoing episode must be the
latest. End cannot precede start. Spotting is independently recordable and may
overlap a period. Weight conversion uses 1 kg = 2.20462262185 lb. Meal snapshots
are intentional: editing/deleting a catalog food does not change earlier meals.
An individual meal can still be edited or deleted. Missing referenced catalog IDs
are allowed because the full food snapshot is embedded.

Food nutrient values are **per 100 g or per 100 ml**, according to `basis`.
Amounts must use that same unit. `serving` requires `servingSize`; one serving
is that many basis units. There is no inferred g↔ml density conversion.

| Nutrient keys | Unit |
|---|---|
| `energy` | kcal |
| `protein`, `carbs`, `fat`, `saturatedFat`, `sugar`, `fiber`, `salt`, `sodium` | g |
| `caffeine` | mg |
| `vitaminA`, `vitaminD`, `vitaminK`, `vitaminB7`, `vitaminB9`, `vitaminB12` | µg |
| `vitaminC`, `vitaminE`, `vitaminB1`, `vitaminB2`, `vitaminB3`, `vitaminB5`, `vitaminB6` | mg |
| `calcium`, `iron`, `magnesium`, `potassium`, `zinc`, `phosphorus` | mg |
| `selenium`, `iodine` | µg |

Null/missing means **unknown**, never zero. A known zero remains numeric zero.
All 31 values are supported in custom foods, food details, daily calculations and
selectable trends. Nutrient numbers cannot be negative and have a generous
finite validation maximum of 1 billion in their respective display unit; the app
does not claim to validate nutritional plausibility or label accuracy.

## Nutrition result

`nutrition.day` returns `date`, `entries` (meals with an added `totals` object),
`drinks`, `totals`, `waterMl`, `extraCaffeineMg`, `caffeineMg`, `knownCounts`,
`completeness`, `extraCaffeineEntryCount` and `entryCount`.

Per-entry totals multiply the recorded amount by each known value per 100 basis
units; servings first multiply by the food's serving size. Daily totals sum known
values, or return null when none are known. `knownCounts[key]` counts meal records
with a known value. `completeness[key]` is true when all meals specify it, false
when some are missing, and null when there are no meals. A partial sum is not a
claim that unknown foods contribute zero.

`waterMl` counts explicit water records. `extraCaffeineMg` counts caffeine drink
records and is added to `totals.caffeine`/`caffeineMg`. `knownCounts.caffeine`
still counts meals only; `extraCaffeineEntryCount` describes the separate records.
An empty day has zero water/extra caffeine, zero entries and null nutrient totals.

## Personal cycle estimate

`cycle.forecast` returns `status` (`disabled`, `insufficient`, `ready`), `on`,
`intervals`, `observedIntervals`, `sampleSize`, `periodCount`, `excludedIntervals`,
`spottingExcluded`, `cycleLength`, `predictedStart`, `earliest`, `latest`,
`lastStart`, `daysSinceLastStart`, `overdueDays`, `confidence`, `method` and
`explanation` in both languages. Dates/lengths not yet estimable are null.

The algorithm uses only starts on or before `on`, excludes spotting, and takes
at most the last 12 start-to-start intervals. It needs at least two usable
intervals (three starts), without a population/default cycle length. Intervals
outside 10–120 days are reported as excluded probable fragments/gaps. With at
least four plausible intervals, an interval beyond the larger of seven days or
three median absolute deviations from the personal median is excluded if at
least three remain. The center is the retained median.

The estimated next start is the latest actual start plus the rounded personal
median. The planning window includes the observed minimum/maximum and a margin
of three days for fewer than four intervals, otherwise two; a scaled median
absolute deviation can widen it further. This is a descriptive planning range,
**not a calibrated probability/confidence interval**. Explanation includes the
sample size, variability, exclusions and sparse data warning. `confidence` is
`limited` for sparse/variable history, otherwise `moderate`; an old history is
`stale`. No confidence ever becomes “certain”.

If the window has passed, `overdueDays` reports that fact. The estimate stays
anchored to the last recorded start: the app never fabricates unrecorded cycles.
Forecasts do not diagnose conditions or estimate ovulation, contraception or
fertile days. Diary mode disables the estimate while retaining all data.

## Food service mapping

The client requests the two paths in SPEC.md with a configured User-Agent and
an explicit field projection. It reads v3.6 `nutrition.aggregated_set` (including
explicit `per` and nutrient `unit`) and legacy CGI `nutriments.*_100g` normalized
values. It avoids mixing prepared and as-sold values, converts mass units to the
units above and kJ to kcal via division by 4.184. Unsupported IU/% units and
strict “less/greater than” label bounds remain unknown. It prefers reported
values, then API-provided computed values. Salt/sodium can derive via factor 2.5.
B3/B5/B7/B9 aliases include niacin, pantothenic acid, biotin and folates.

The selected declared nutrition basis is retained, even if a package's volume
unit differs. A serving is imported only if its unit matches that basis. Food
name/brand are source content, not translated health advice. Lookup of an absent
product returns null; invalid network responses, TLS errors, rate limits and
timeouts return failures, preserving local usage. Requests have connection/read
timeouts, a 16 MiB response cap, and no automatic cross-origin redirects.

References used for the implementation:
[OFF API](https://openfoodfacts.github.io/openfoodfacts-server/api/),
[API/schema change log](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-api-and-product-schema-change-log/).
The supplied endpoint was exercised with a real search and v3.6 lookup; this
revealed the new structured schema even when legacy `nutriments` is empty.
