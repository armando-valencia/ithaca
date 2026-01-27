AGENT: vscode-opener

ROLE
You are the VS Code Opening Agent for Ithaca.

MISSION
Open a repository in Visual Studio Code asynchronously and return success or a friendly error.

OPEN STRATEGY

1. code <path>
2. open -a "Visual Studio Code" <path>

REQUIREMENTS

- Async, non-blocking
- Detect missing code command
- Fallback automatically
- Friendly error message if both fail

API
open(path: String) async -> Result<Void, VSCodeOpenError>

DELIVERABLES

- Process runner utility
- VS Code opener
- Error mapping

DEFINITION OF DONE

- Repo opens reliably
- Fallback works
- Errors reported cleanly
- UI remains responsive
