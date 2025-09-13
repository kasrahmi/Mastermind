# Mastermind — Terminal Game (Swift)

![Language: Swift](https://img.shields.io/badge/language-Swift-orange) ![Terminal Game](https://img.shields.io/badge/terminal-game-blue)

## Overview

A simple, robust terminal implementation of the classic code-breaking game **Mastermind**, written in Swift. The player attempts to guess a hidden 4-digit secret where each digit is in the range `1..6`. After each guess, the game returns feedback using:

* `B` (black peg): a digit that is correct **in both value and position**
* `W` (white peg): a digit that is correct **in value but in the wrong position**

The project supports two modes:

* **LOCAL** — the secret code is generated locally inside the program.
* **REMOTE** — the program uses the remote API `https://mastermind.darkube.app` to create a game and send guesses. If remote creation fails, the program falls back to LOCAL mode.

## Features

* Clean, human-friendly terminal UI with simple prompts
* Input validation (exactly 4 digits, each in `1..6`) and graceful error messages
* `exit` command supported at any prompt (or `Ctrl-D` / EOF to quit)
* Remote API integration with JSON encoding/decoding and timeouts
* Deterministic peg computation (no duplicate counting mistakes)

## Requirements

* Swift 5.0 or later
* macOS or Linux (with Swift toolchain installed)
* Internet connection if you want to use `--remote` mode

## Quick start

Clone or download the repository and then either run the script directly or compile it.

### Run directly (script)

```bash
# Make it executable once:
chmod +x main.swift
./main.swift
# or
swift main.swift
```

### Compile and run

```bash
swiftc main.swift -o mastermind
./mastermind
```

### Remote mode

```bash
./main.swift --remote
# or
./mastermind --remote
```

If the remote API is unreachable or returns an error while creating a game, the program will print a helpful message and continue in LOCAL mode.

## How to play

* Each attempt, type a 4-digit string (for example `1234`) where every digit must be between `1` and `6`.
* After submitting, you will see a string composed of `B` and `W` characters. Order of pegs does not map to digit positions — it only reports counts (standard Mastermind behavior).
* Example:

  * Secret: `1234`, Guess: `1235` → `BBB` (three correct digits in correct positions)
  * Secret: `1234`, Guess: `4321` → `WWWW` (four correct digits but all in wrong positions)
* Type `exit` at any prompt to end the game immediately.

## Input validation & error handling

* Guesses must be exactly 4 characters long and only contain digits `1` through `6`.
* If a guess is invalid, the program prints a clear error message and asks for another input.
* Remote requests (create game, post guess) use a 10-second wait before timing out. On network or decoding errors, helpful diagnostic messages are shown.

## Implementation notes

* `randomSecret()` — generates a random 4-digit secret with digits in `1...6`.
* `parseGuess(_:)` — validates and parses a user input string into `[Int]` or returns `nil` on invalid input.
* `check(guess:secret:)` — computes `black` and `white` pegs without double-counting: first count exact matches, then count value-only matches using frequency arrays.
* Remote client uses `URLSession` with JSON `Codable` structs for communicate with the API endpoints `/game` and `/guess`. `DispatchSemaphore` provides simple synchronous waits for the short-lived HTTP calls.

## Troubleshooting & tips

* If your network blocks requests or the API is down, run without `--remote`.
* If you accidentally enter non-digit characters, you'll receive a validation error and can retry.
* On macOS, if `swiftc` is not found, install the latest Swift toolchain or use `swift` to run the script directly.

## Tests

This repository does not include a test suite, but the logic is modular and easy to test. Suggested quick unit tests:

* `parseGuess("")` and invalid values produce `nil`
* `check` on identical arrays returns `(4,0)`
* `check` on permutations returns `(0,4)` as appropriate

## Contribution

PRs are welcome — small, focused changes are preferred (fixes, tests, README enhancements). Please open an issue first if you plan large changes.
