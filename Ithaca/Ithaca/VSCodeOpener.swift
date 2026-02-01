//
//  VSCodeOpener.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import Foundation
import AppKit

enum OpenTargetError: LocalizedError {
    case failed(target: OpenTarget)

    var errorDescription: String? {
        switch self {
        case .failed(let target):
            switch target {
            case .vscode:
                return "Could not open in Visual Studio Code. Install the app or enable the 'code' command."
            case .xcode:
                return "Could not open in Xcode."
            case .finder:
                return "Could not reveal in Finder."
            }
        }
    }
}

struct OpenTargetOpener {
    static func open(target: OpenTarget, path: String) async -> Result<Void, OpenTargetError> {
        switch target {
        case .vscode:
            return await openVSCode(path: path)
        case .xcode:
            return await openApp(name: "Xcode", path: path, target: target)
        case .finder:
            return await openFinder(path: path)
        }
    }

    private static func openVSCode(path: String) async -> Result<Void, OpenTargetError> {
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

        return .failure(.failed(target: .vscode))
    }

    private static func openApp(name: String, path: String, target: OpenTarget) async -> Result<Void, OpenTargetError> {
        let openResult = await ProcessRunner.run(
            executable: "/usr/bin/open",
            arguments: ["-a", name, path]
        )
        if openResult.exitCode == 0 {
            return .success(())
        }
        return .failure(.failed(target: target))
    }

    private static func openFinder(path: String) async -> Result<Void, OpenTargetError> {
        let openResult = await ProcessRunner.run(
            executable: "/usr/bin/open",
            arguments: ["-R", path]
        )
        if openResult.exitCode == 0 {
            return .success(())
        }
        return .failure(.failed(target: .finder))
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
