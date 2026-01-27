//
//  VSCodeOpener.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import Foundation

enum VSCodeOpenError: LocalizedError {
    case failed(codeStatus: Int32, openStatus: Int32)

    var errorDescription: String? {
        "Could not open in Visual Studio Code. Install the app or enable the 'code' command."
    }
}

struct VSCodeOpener {
    static func open(path: String) async -> Result<Void, VSCodeOpenError> {
        let codeResult = await ProcessRunner.run(
            executable: "/usr/bin/env",
            arguments: ["code", path]
        )
        if codeResult.exitCode == 0 {
            return .success(())
        }

        let openResult = await ProcessRunner.run(
            executable: "/usr/bin/open",
            arguments: ["-a", "Visual Studio Code", path]
        )
        if openResult.exitCode == 0 {
            return .success(())
        }

        return .failure(.failed(codeStatus: codeResult.exitCode, openStatus: openResult.exitCode))
    }
}

struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

enum ProcessRunner {
    static func run(executable: String, arguments: [String]) async -> ProcessResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    stdout: stdout,
                    stderr: stderr
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: ProcessResult(exitCode: 1, stdout: "", stderr: error.localizedDescription))
            }
        }
    }
}
