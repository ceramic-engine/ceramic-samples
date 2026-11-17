// Runs a command and makes sure it never shows anything on screen:
// no on screen window, no Dock icon (regular activation policy), no focus change.
// On any violation the command is killed and the guard exits with code 90.
// The command is also killed after WINDOW_GUARD_TIMEOUT seconds (default 900),
// and the guard then exits with code 92.
//
// Usage: window-guard <command> [args...]

import AppKit
import CoreGraphics
import Foundation

func fail(_ message: String, _ process: Process) -> Never {
    FileHandle.standardError.write(("window-guard: " + message + "\n").data(using: .utf8)!)
    if process.isRunning {
        process.terminate()
        usleep(200_000)
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }
    exit(90)
}

let args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty {
    FileHandle.standardError.write("Usage: window-guard <command> [args...]\n".data(using: .utf8)!)
    exit(64)
}

let frontmostBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier

let process = Process()
process.executableURL = URL(fileURLWithPath: args[0])
process.arguments = Array(args.dropFirst())
var environment = ProcessInfo.processInfo.environment
// Ask SDL not to turn the process into a regular (Dock) app nor to activate it
environment["SDL_MAC_BACKGROUND_APP"] = "1"
process.environment = environment

do {
    try process.run()
} catch {
    FileHandle.standardError.write("window-guard: cannot run \(args[0]): \(error)\n".data(using: .utf8)!)
    exit(91)
}

let pid = process.processIdentifier
let timeout = Double(ProcessInfo.processInfo.environment["WINDOW_GUARD_TIMEOUT"] ?? "") ?? 900
let start = Date()

while process.isRunning {
    if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
        for window in list {
            if let owner = window[kCGWindowOwnerPID as String] as? Int32, owner == pid {
                let layer = window[kCGWindowLayer as String] as? Int ?? 0
                fail("the process put a window on screen (layer \(layer))", process)
            }
        }
    }
    if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular {
        fail("the process became a regular app (Dock icon)", process)
    }
    if let front = NSWorkspace.shared.frontmostApplication?.processIdentifier, front == pid, front != frontmostBefore {
        fail("the process took the focus", process)
    }
    if Date().timeIntervalSince(start) > timeout {
        FileHandle.standardError.write("window-guard: timeout after \(Int(timeout)) s\n".data(using: .utf8)!)
        process.terminate()
        usleep(200_000)
        if process.isRunning { kill(pid, SIGKILL) }
        exit(92)
    }
    usleep(50_000)
}

exit(process.terminationStatus)
