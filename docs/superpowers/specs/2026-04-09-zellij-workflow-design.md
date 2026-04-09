# Zellij-Based Codex Workflow Redesign

## Context

This repository currently provides a lightweight zsh plugin for `codex + tmux` workflows on remote servers. The existing model centers on `dev`, `cx`, `cwa`, `cxx`, and `cwl`, with tmux sessions as the underlying abstraction.

The redesign changes the underlying multiplexer from `tmux` to `zellij` and intentionally rethinks the command model instead of preserving tmux-oriented compatibility. The primary user goal is faster multi-project switching. The preferred interaction is direct commands first, with list-based selection as a secondary path.

## Goals

1. Make switching between active projects as fast as possible.
2. Use `zellij` as the session and pane manager instead of `tmux`.
3. Create a consistent default workspace layout for project sessions:
   - top pane: shell in the project directory
   - bottom pane: `codex` started in the same project directory
4. Keep a distinction between long-lived project sessions and a reusable temporary session.
5. Prioritize direct command entry over interactive selection, while still providing a selector for convenience.

## Non-Goals

1. Preserve tmux command compatibility or tmux-specific title integration.
2. Recreate every existing command exactly as-is.
3. Build a full project registry or configuration database in the first version.
4. Add unrelated workspace-management features beyond project entry, temporary entry, session listing, and session selection.

## User Model

The workflow has two session types:

1. Project session
   - Bound to a specific project directory.
   - Persistent and reusable across repeated entries.
   - Optimized for ongoing work in named repositories or stable folders.

2. Temporary session
   - Bound to one fixed zellij session name.
   - Intended for throwaway or short-lived work.
   - Recreated explicitly when the user wants a fresh temporary context.

The high-frequency path is entering a project directly by command. Interactive selection is a fallback when the user does not want to type the path manually.

## Command Design

### Primary Commands

1. `pj <dir|alias>`
   - Main project entry command.
   - Enters the zellij session associated with a project directory.
   - If the session does not exist, creates it with the standard two-pane layout.
   - First version must support directories.
   - The `alias` portion is reserved for future extension; initial implementation may treat non-path arguments conservatively or leave alias support unimplemented.

2. `px [dir]`
   - Temporary entry command.
   - Enters one fixed temporary zellij session.
   - If the temporary session does not exist, creates it using the same default layout and the target directory.
   - If no directory is provided, uses the current working directory.

3. `pjs`
   - Lists project sessions and their associated directories.
   - Intended as a quick visibility tool for current active project contexts.

4. `pjp`
   - Interactive project picker.
   - Allows the user to choose a project from a list, then internally routes to `pj`.
   - First version should prioritize existing project sessions as candidate sources.

5. `pxr`
   - Resets the temporary session.
   - Destroys the existing temporary zellij session if present.
   - Used when the user wants a clean temporary workspace before re-entering with `px`.

### Removed Legacy Model

The old `dev/cx/cwa/cxx/cwl` model is not the primary design target. Compatibility aliases can be discussed later, but the redesign assumes the new workflow is centered on `pj`, `px`, `pjs`, `pjp`, and `pxr`.

## Session Semantics

### Project Sessions

Each project directory maps to one zellij session. Re-entering the same project should return to the same session rather than creating a new one.

The mapping must be stable and deterministic:

1. Resolve the input directory to an absolute path.
2. Generate a session name from that directory.
3. If a session already exists for that path, attach or switch to it.
4. If not, create a new session with the default layout.

Different directories with the same basename must not collide. Name generation should produce a human-readable base name and append suffixes when needed to preserve uniqueness.

### Temporary Session

The temporary workflow always uses one fixed session name, for example `codex-temp`.

The temporary session is intentionally stateful and separate from project sessions. If it already exists, `px` should enter it directly instead of silently mutating its panes to a new target directory. If the user wants to repoint the temporary workspace, they should explicitly reset it with `pxr` and then recreate it with `px <dir>`.

This avoids hidden state drift, especially the failure mode where the top shell and bottom `codex` pane end up in different directories.

## Zellij Layout Design

The layout is fixed and intentional:

1. Top pane
   - Starts as a normal interactive shell.
   - Working directory is the selected project or temporary target directory.

2. Bottom pane
   - Automatically starts `codex`.
   - Working directory is exactly the same as the top pane's initial directory.

The plugin should treat this layout as a contract. The main value of the tool is not just session creation, but session creation with a reliable default working context for both panes.

Repeated entry into an existing session should not recreate the layout or reset the pane state. It should only attach or switch into the existing zellij session.

## Candidate Zellij Integration Strategy

The shell plugin should own:

1. command parsing
2. directory normalization
3. session naming
4. session existence checks
5. entry dispatch

Zellij should own:

1. session lifecycle
2. pane creation
3. pane arrangement
4. running the shell and `codex` inside panes

The implementation should prefer a minimal, explicit bridge into zellij rather than trying to emulate tmux behavior. If zellij supports layouts or actions that can declaratively create the two-pane startup state, that should be favored over brittle imperative sequences.

## Project Picker Design

`pjp` exists to complement the direct command path, not replace it.

First-version candidate sources:

1. currently known active project sessions

Possible later extensions:

1. configured project shortcuts
2. recent project directories
3. scanned directories under a known workspace root

Those later sources are out of scope for the initial redesign. The first version should stay focused on active-session switching speed and simple discoverability.

## Error Handling

The plugin should fail clearly and early in the following cases:

1. `zellij` is not available in `PATH`
2. `codex` is not available in `PATH`
3. target directory does not exist
4. target directory cannot be resolved to an accessible absolute path
5. zellij session creation or attachment fails

Behavioral rules:

1. No silent fallback to unrelated sessions.
2. No hidden mutation of an existing project session to a different directory.
3. No hidden mutation of an existing temporary session to a new directory.
4. No partial success messages when layout creation fails.

## Naming Strategy

Session names should be readable first and collision-safe second.

Recommended initial strategy:

1. use the directory basename as the base session name
2. sanitize characters that are awkward for session identifiers
3. if another session already uses that name for a different directory, append numeric suffixes

This preserves short names during normal use while still handling common collisions like multiple repositories named `api`, `server`, or `frontend`.

## Testing Strategy

### Shell-Level Validation

Test the logic that does not require live zellij interaction:

1. path normalization
2. invalid-directory handling
3. session-name derivation
4. collision resolution
5. command routing semantics for `pj`, `px`, `pjs`, `pjp`, and `pxr`

### Integration Validation

Run manual or scripted checks in an environment with `zellij` and `codex` installed:

1. `pj <dir>` creates a new project session
2. the new project session opens with top shell and bottom `codex`
3. both panes start in the same target directory
4. repeated `pj <same-dir>` returns to the existing session
5. `px <dir>` creates the temporary session
6. repeated `px` re-enters the same temporary session
7. `pxr` removes the temporary session cleanly
8. `pjs` shows session-to-path mappings correctly
9. `pjp` selects an existing project session and routes to it correctly

## Migration Notes

This redesign is intentionally a workflow change, not an internal refactor only. Users should expect the zellij version to introduce a new primary command surface. Documentation should reflect that the plugin is now zellij-first, and old tmux-specific guidance should either be retired or clearly marked as historical.

## Open Decisions Deferred From This Spec

The following items are intentionally deferred so the initial redesign stays focused:

1. full alias registry and persistence
2. automatic workspace scanning
3. backward-compatible wrappers for old command names
4. advanced zellij UI customization beyond the required two-pane startup layout

## Recommended Implementation Sequence

1. replace tmux-oriented command architecture with the new zellij-oriented command surface
2. implement path resolution and stable session naming
3. implement project session creation and re-entry with the default two-pane layout
4. implement temporary session creation and reset behavior
5. implement project listing
6. implement project picker
7. rewrite repository documentation around the new workflow

## Acceptance Criteria

The redesign is successful when all of the following are true:

1. A user can enter a project with one short command and land in a zellij session for that project.
2. A new project session always starts with a shell pane on top and a `codex` pane on bottom.
3. Both panes start in the same project directory.
4. Re-entering the same project does not create duplicate sessions.
5. Temporary work remains available through a separate reusable session model.
6. Direct command entry is the fastest path, and interactive selection remains optional.
