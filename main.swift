#!/usr/bin/env swift
import Foundation

// ---------- Helpers ----------
func prompt(_ text: String) {
    print(text, terminator: " ")
    fflush(stdout)
}

func readLineOrExit() -> String {
    guard let line = readLine() else {
        // EOF -> exit
        exit(0)
    }
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.lowercased() == "exit" {
        print("Bye 👋")
        exit(0)
    }
    return trimmed
}

// ---------- Mastermind logic ----------
func randomSecret() -> [Int] {
    (0..<4).map { _ in Int.random(in: 1...6) }
}

func check(guess: [Int], secret: [Int]) -> (black: Int, white: Int) {
    var black = 0
    var secretCounts = Array(repeating: 0, count: 7) // index 1..6
    var guessCounts = Array(repeating: 0, count: 7)

    for i in 0..<4 {
        if guess[i] == secret[i] {
            black += 1
        } else {
            secretCounts[secret[i]] += 1
            guessCounts[guess[i]] += 1
        }
    }
    var white = 0
    for d in 1...6 {
        white += min(secretCounts[d], guessCounts[d])
    }
    return (black, white)
}

func parseGuess(_ s: String) -> [Int]? {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count == 4 else { return nil }
    var arr: [Int] = []
    for ch in trimmed {
        guard let d = Int(String(ch)), (1...6).contains(d) else {
            return nil
        }
        arr.append(d)
    }
    return arr
}

// ---------- Remote API client ----------
struct CreateGameResponse: Codable {
    let game_id: String
}
struct GuessRequest: Codable {
    let game_id: String
    let guess: String
}
struct GuessResponse: Codable {
    let black: Int
    let white: Int
}
let apiBase = "https://mastermind.darkube.app"

func createRemoteGame() -> String? {
    guard let url = URL(string: "\(apiBase)/game") else { return nil }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    let sem = DispatchSemaphore(value: 0)
    var resultGameID: String? = nil

    let task = URLSession.shared.dataTask(with: req) { data, resp, err in
        defer { sem.signal() }
        if let err = err {
            print("Error creating game: \(err.localizedDescription)")
            return
        }
        guard let http = resp as? HTTPURLResponse else {
            print("No HTTP response.")
            return
        }
        // unwrap data safely
        guard (200...299).contains(http.statusCode), let data = data else {
            let code = http.statusCode
            var body = ""
            if let d = data, let s = String(data: d, encoding: .utf8) {
                body = s
            }
            print("Create game failed: HTTP \(code) \(body)")
            return
        }
        do {
            let dec = JSONDecoder()
            let cg = try dec.decode(CreateGameResponse.self, from: data)
            resultGameID = cg.game_id
        } catch {
            print("Failed to decode create response: \(error)")
            if let s = String(data: data, encoding: .utf8) {
                print("body:", s)
            }
        }
    }
    task.resume()
    _ = sem.wait(timeout: .now() + 10) // wait up to 10s
    return resultGameID
}

func postRemoteGuess(gameID: String, guessStr: String) -> (black: Int, white: Int)? {
    guard let url = URL(string: "\(apiBase)/guess") else { return nil }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let gr = GuessRequest(game_id: gameID, guess: guessStr)
    do {
        req.httpBody = try JSONEncoder().encode(gr)
    } catch {
        print("Failed to encode JSON: \(error)")
        return nil
    }
    let sem = DispatchSemaphore(value: 0)
    var result: (Int, Int)? = nil
    let task = URLSession.shared.dataTask(with: req) { data, resp, err in
        defer { sem.signal() }
        if let err = err {
            print("Error in guess request: \(err.localizedDescription)")
            return
        }
        guard let http = resp as? HTTPURLResponse else {
            print("No HTTP response.")
            return
        }
        // unwrap data safely
        guard (200...299).contains(http.statusCode), let data = data else {
            let code = http.statusCode
            var body = ""
            if let d = data, let s = String(data: d, encoding: .utf8) {
                body = s
            }
            print("Guess failed: HTTP \(code) \(body)")
            return
        }
        do {
            let dec = JSONDecoder()
            let grr = try dec.decode(GuessResponse.self, from: data)
            result = (grr.black, grr.white)
        } catch {
            print("Failed to decode guess response: \(error)")
            if let s = String(data: data, encoding: .utf8) {
                print("body:", s)
            }
        }
    }
    task.resume()
    _ = sem.wait(timeout: .now() + 10)
    return result
}

// ---------- Main ----------
let args = CommandLine.arguments
let useRemote = args.contains("--remote")

print("=== Mastermind (terminal) ===")
print("Rules: guess a 4-digit code; digits 1..6. Type 'exit' anytime to quit.")
print("Mode:", useRemote ? "REMOTE (API)" : "LOCAL")

var secret: [Int] = []
var remoteGameID: String? = nil

if useRemote {
    print("Creating remote game...")
    if let gid = createRemoteGame() {
        remoteGameID = gid
        print("Remote game id:", gid)
    } else {
        print("Failed to create remote game. Falling back to LOCAL mode.")
        secret = randomSecret()
    }
} else {
    secret = randomSecret()
}

var attempts = 0
while true {
    attempts += 1
    prompt("Attempt #\(attempts) — enter your guess (4 digits 1-6):")
    let line = readLineOrExit()
    guard let guessArr = parseGuess(line) else {
        print("Invalid guess. Make sure it's exactly 4 digits, each between 1 and 6. Try again or type 'exit'.")
        continue
    }
    if let gid = remoteGameID {
        // remote flow
        let guessStr = guessArr.map(String.init).joined()
        if let resp = postRemoteGuess(gameID: gid, guessStr: guessStr) {
            let black = resp.black
            let white = resp.white
            print(String(repeating: "B", count: black) + String(repeating: "W", count: white))
            if black == 4 {
                print("Congratulations! You found the code in \(attempts) attempts.")
                exit(0)
            }
        } else {
            print("Remote guess failed. If network/API is down, you can restart without --remote.")
        }
    } else {
        // local flow
        let (black, white) = check(guess: guessArr, secret: secret)
        print(String(repeating: "B", count: black) + String(repeating: "W", count: white))
        if black == 4 {
            print("Congratulations! You found the code in \(attempts) attempts.")
            print("Secret was:", secret.map(String.init).joined())
            exit(0)
        }
    }
}

