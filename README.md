# Timetracker

macOS menu bar app that records what you are working on (foreground window, Chrome URL, Claude Code sessions, shell commands, Teams calls, calendar) and turns it into a billable report. Vocabulary lives in `CONTEXT.md`, decisions in `docs/adr/`.

## Build & run

Requires macOS 26 on Apple Silicon and Command Line Tools (no Xcode needed).

```sh
make cert       # once per machine: self-signed signing identity (see Signing)
make install    # build, sign, copy to /Applications and start it there
make test       # swift test
```

### Development loop

After **every** code change run:

```sh
make install
```

It quits the running instance, rebuilds, replaces `/Applications/Timetracker.app` and starts it again. Always run the app from `/Applications`: the login item and the Accessibility grant are tied to that copy. `make app` only builds into `dist/`, `make run` opens that build (fine for a quick look, but it is a second copy macOS treats separately).

The app registers itself as a login item on every launch (toggle in Settings).

First launch asks for **Accessibility** (window titles). Chrome URL reading asks for **Automation** the first time Chrome is in front. Calendar access and Claude Code / zsh hooks are enabled in *Settings* inside the app.

### Signing

Ad-hoc signatures change on every build, so macOS would forget the Accessibility grant each time. Run once:

```sh
make cert    # self-signed "Timetracker Dev" identity in the login keychain
```

`make app` picks it up automatically. Grant Accessibility one more time after the first signed build (remove the old entry with − and add `dist/Timetracker.app` again); it then survives rebuilds. The app also re-installs its hooks on every launch.

## Hooks

*Settings → Install* writes `~/Library/Application Support/Timetracker/tt-hook.sh` and `tt.zsh`, adds hook entries to `~/.claude/settings.json` (SessionStart, UserPromptSubmit, Stop, SessionEnd) and one `source` line to `~/.zshrc`. Hooks append JSON lines to `events.jsonl`; the app tails the file. They print nothing to stdout and never call Claude. *Uninstall* removes both.

## Day summary

Every hour the app checks whether yesterday has been summarized; if not, it sends the day's raw data (windows, Claude sessions and prompts, shell commands, git commits, meetings) to `claude -p --model sonnet` and stores the answer as **AI drafts** in the Day view. Nothing changes until a draft is approved: approving assigns the activities in its time ranges to the draft's project and task (activities you assigned by hand are never touched). *Summarize day* / *Regenerate* runs it for any day. The call runs with `TIMETRACKER_INTERNAL=1`, which the hook script ignores, so it is not tracked as work.

## Debugging

- `tracker.log` in the data directory logs every decision (assignment, idle, sleep/lock, meetings, hooks, summaries, AI drafts).
- Write a bundle id into `dump-ax.txt` → the app dumps that app's Accessibility tree into `ax-dump.txt`.
- Write a tab name (`Day`, `Week`, `Raw`, `Invoice`, `Settings`) into `snapshot.txt` → the app opens that tab and renders the window into `snapshot.png` (the sidebar's vibrancy is not captured).
- Write a day (`2026-09-29`) into `summarize.txt` → the app writes the AI input to `day-input.txt` and runs the day summary.

## Data

SQLite at `~/Library/Application Support/Timetracker/timetracker.sqlite`. Session Summaries use the on-device Apple Foundation Models. "Summarize day" sends the day's raw data (window titles and URLs, Claude Code prompts, shell commands, commit subjects) to Claude via `claude -p`; the exact input is written to `day-input.txt` when triggered through `summarize.txt`.

## Layout

```
Sources/Timetracker/
├── App.swift            menu bar scene, main window, app delegate
├── DB.swift             SQLite wrapper and schema
├── Report.swift         period report, rounding, overlap policy, exports
├── Model/               Interval math, row structs, Settings, Day/Format helpers, ActivityGroup
├── Store/               Store core (projects) + extensions: Assignment, Activities, Sessions, Tasks
├── Tracking/            Tracker (foreground sampling), MeetingTracker, AX helpers, Hooks, EventIngest, Summarizer, Log
└── Views/               one view per file; Components and Issues are shared
```
