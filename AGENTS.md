# Prose output

Use `/Users/berken/.agents/skills/unslop/SKILL.md` for prose presented to the user.

## Downloads folder

The downloads folder is `/Users/berken/Library/Mobile Documents/com~apple~CloudDocs/Downloads`.

## App verification handoff

After iOS app changes, install and launch the latest build on Sharing Cloud B before finishing the task, so the user can verify it immediately. Leave the app open on the affected screen, preserve its data and Apple Account sign-in, and close owned debugger and log-capture sessions.

## Builds

Avoid cold builds when possible. Reuse compatible build and dependency caches, including those created by other chats, when appropriate for the project, configuration, and toolchain. Use a clean build when needed for correctness or diagnosis, and do not disrupt another active build.

## Simulator streaming

The ommtzi-associated simulator is **Sharing Cloud B**, UDID `ADCA6587-620E-4CB7-AB4B-3AD948C8505D`. When serving it with serve-sim, proactively run `npx --yes serve-sim@latest repair-input -d ADCA6587-620E-4CB7-AB4B-3AD948C8505D` before starting the stream. This restarts SpringBoard and closes running apps, so reopen the app afterward. Reload the browser page after restarting serve-sim. Do not require a separate interaction test every time.

Sharing Cloud B uses a dummy Apple Account and has an existing sharing connection with the user's physical iPhone, which uses the user's own Apple Account. Preserve that connection and both accounts when testing the app's sharing feature.

For UI and feature verification, use only Sharing Cloud B through serve-sim, orchestrated by a GPT-6.1 Terra subagent with high reasoning effort. Open the stream in the user's visible in-app browser before testing so the user can watch the interaction. Reuse an existing Sharing Cloud B stream and browser tab across turns when available; open a new one only when needed. Leave the stream and browser tab open afterward. Follow the app verification handoff above after iOS app changes.

## Agent skills

### Issue tracker

Issues live as local Markdown files under `.scratch/calorie-card-sharing/issues/`. See `Docs/agents/issue-tracker.md`.

### Triage labels

Use the default five triage labels. See `Docs/agents/triage-labels.md`.

### Domain docs

Use one root `CONTEXT.md` and `Docs/adr/` for this single-context repository. See `Docs/agents/domain.md`.
