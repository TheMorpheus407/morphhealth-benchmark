# MorphHealth benchmark

Raw runs of the MorphHealth benchmark: a complete Flutter Android app for
nutrition, a personal cycle tracker, weight and symptoms, plus a local
command-line maintenance interface, built by an AI model in a single run.

## Task

Every model received the same inputs:

- [`SPEC.md`](SPEC.md): the assignment (German)
- [`ENVIRONMENT.json`](ENVIRONMENT.json): the measured reference host and
  Android reference device
- [`prompt.txt`](prompt.txt): the prompt that started the run

Food data came from a local HTTPS mirror of the Open Food Facts API contract,
built from the official Open Food Facts database dump (ODbL).

## Runs

One folder per model. Each folder contains the files of the model's workspace
at the end of its run, including its own copy of the inputs above.

| Folder | Model | Run |
|---|---|---|
| [`Claude-Opus-5.5/`](Claude-Opus-5.5/) | Claude Opus 5.5 | 2026-09-23 |
| [`GPT-6-Astra/`](GPT-6-Astra/) | GPT-6 Astra | 2026-09-26 |
| [`Claude-Sonnet-5.5/`](Claude-Sonnet-5.5/) | Claude Sonnet 5.5 | 2026-09-29 |
| [`GPT-6.1-Sol/`](GPT-6.1-Sol/) | GPT-6.1 Sol | 2026-09-30 |
| [`Mistral-Large-4/`](Mistral-Large-4/) | Mistral Large 4 | 2026-10-07 |

Build outputs, caches, IDE state, signing keys and harness configuration are
left out (see [`.gitignore`](.gitignore)); a `.gitignore` written by a model
applies to its folder.

## License

MIT, see [LICENSE](LICENSE). Third-party components keep their own licenses.
