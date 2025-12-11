local config = require("simple-notes.config")
local commands = require("simple-notes.commands")

local M = {
  note_new = commands.note_new,
  note_add_topic = commands.note_add_topic,
  note_convert_to = commands.note_convert_to,
  note_add = commands.note_add,
  note_toc_update = commands.note_toc_update,
}

local augroup = vim.api.nvim_create_augroup("SimpleNotes", { clear = true })
local commands_registered = false
local keymaps_set = false

local default_keymaps = {
  { mode = "n", lhs = "<leader>nn", rhs = commands.note_new, desc = "simple-[n]otes: new [n]ote" },
  { mode = "n", lhs = "<leader>na", rhs = commands.note_add, desc = "simple-[n]otes: [a]dd entry" },
  { mode = "n", lhs = "<leader>nct", rhs = commands.note_convert_to, desc = "simple-[n]otes: [c]onvert [t]itle" },
  { mode = "n", lhs = "<leader>nt", rhs = commands.note_toc_update, desc = "simple-[n]otes: refresh [t]oc" },
}

local function tracked_patterns()
  local patterns = { "*.notes" }
  if config.options.use_md then
    table.insert(patterns, "*.md")
  end
  return patterns
end

local function mark_buffer(buf)
  vim.b[buf].simple_notes_active = true
  local name = vim.api.nvim_buf_get_name(buf)
  if name:match("%.notes$") then
    vim.bo[buf].filetype = "markdown"
  end
end

local function setup_autocmds()
  vim.api.nvim_clear_autocmds({ group = augroup })
  local patterns = tracked_patterns()
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = augroup,
    pattern = patterns,
    callback = function(args)
      mark_buffer(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup,
    pattern = patterns,
    callback = function(args)
      if not config.options.auto_toc_on_save then
        return
      end
      if not vim.b[args.buf].simple_notes_active then
        return
      end
      commands.note_toc_update({ bufnr = args.buf, automatic = true })
    end,
  })
end

local function setup_commands()
  if commands_registered then
    return
  end
  local defs = {
    NoteNew = commands.note_new,
    NoteAddTopic = commands.note_add_topic,
    NoteConvertTo = commands.note_convert_to,
    NoteAdd = commands.note_add,
    NoteTocUpdate = commands.note_toc_update,
  }
  for name, fn in pairs(defs) do
    vim.api.nvim_create_user_command(name, fn, {})
  end
  commands_registered = true
end

local function setup_keymaps()
  if keymaps_set then
    return
  end
  for _, map in ipairs(default_keymaps) do
    if vim.fn.maparg(map.lhs, map.mode) == "" then
      vim.keymap.set(map.mode, map.lhs, map.rhs, { desc = map.desc })
    end
  end
  keymaps_set = true
end

function M.setup(opts)
  config.setup(opts)
  setup_autocmds()
  setup_commands()
  setup_keymaps()
  return M
end

return M
