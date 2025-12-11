# simple-notes.nvim

A focused Neovim plugin for timestamped note taking inside `.notes` buffers (optionally `.md`). It creates structured headings, keeps a table of contents fresh, and politely asks before touching the filesystem.

## Features
- Treats `*.notes` files as Markdown while leaving other Markdown plugins untouched.
- Guided workflows for new notes, topic headings, sub-headings, and TOC maintenance.
- Always prompts before the plugin writes to disk (toggleable).
- Optional support for native Markdown (`*.md`) buffers.

## Requirements
- Neovim 0.11.0 or newer
- No external dependencies

## Installation (Lazy)
```lua
{
  "sigugo/simple-notes.nvim",
  config = function()
    require("simple-notes").setup()
  end,
}
```

## Configuration
```lua
require("simple-notes").setup({
  use_md = false,             -- also treat *.md buffers as notes
  confirm_writes = true,      -- prompt before plugin writes to disk
  auto_toc_on_save = true,    -- run :NoteTocUpdate on save
  filename_format = "%Y-%m-%d_%H-%M", -- os.date() format for filenames
  primary_heading_format = "%Y-%m-%d.%H:%M",
  note_heading_format = "%Y-%m-%d.%H:%M",
})
```

### Headline Formats
- `filename_format` shapes `note_<stamp>-topic.notes`.
- `primary_heading_format` is used in `# Note - <stamp> - TOPIC`.
- `note_heading_format` is used for `## <stamp> |` sub-headlines.

## Commands
| Command | Default Map | Description |
| --- | --- | --- |
| `:NoteNew` | `<leader>nn` | Prompt for a topic, create `<cwd>/note_<timestamp>-<topic>.notes`, insert heading, open in new tab. |
| `:NoteAddTopic` | — | Prompt for a topic and ensure the primary heading exists (no save). |
| `:NoteConvertTo` | `<leader>nct` | Rename current note using the heading’s timestamp/topic. Prompts for heading first if missing. |
| `:NoteAdd` | `<leader>na` | Append `## <timestamp> |` (plus a trailing space for typing) at EOF and place the cursor for writing. |
| `:NoteTocUpdate` | `<leader>nt` | Build/refresh a Markdown TOC linking to all `##` headings. Runs on save when `auto_toc_on_save = true`. |

Commands other than `:NoteNew` operate only on buffers tagged as simple-notes (matching `*.notes` by default, `*.md` when `use_md = true`).

## Keymaps
Default normal-mode mappings are only applied if the slot is free, and descriptions highlight mnemonic letters:
- `<leader>nn` → `:NoteNew` (`simple-[n]otes: new [n]ote`)
- `<leader>na` → `:NoteAdd` (`simple-[n]otes: [a]dd entry`)
- `<leader>nct` → `:NoteConvertTo` (`simple-[n]otes: [c]onvert [t]itle`)
- `<leader>nt` → `:NoteTocUpdate` (`simple-[n]otes: refresh [t]oc`)
Remap or clear them in your config if you prefer different bindings.

## Workflow
1. `:NoteNew` prompts for a topic, creates a file in the directory where Neovim was launched, and opens it in a new tab.
2. Use `:NoteAddTopic` to retrofit a missing `# Note - …` heading.
3. Append timestamped sections with `:NoteAdd`.
4. `:NoteTocUpdate` keeps navigation links fresh (auto on save by default).
5. `:NoteConvertTo` fixes filenames so they always reflect the primary heading.

## License
MIT
