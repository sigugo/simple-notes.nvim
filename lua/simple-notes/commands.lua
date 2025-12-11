local config = require("simple-notes.config")

local M = {}

local NOTE_EXTENSION = ".note"
local TOC_START = "<!-- simple-notes:header:start -->"
local TOC_END = "<!-- simple-notes:header:end -->"

local function notify(msg, level)
  vim.notify("simple-notes.nvim: " .. msg, level or vim.log.levels.INFO)
end

local function cwd()
  return vim.loop.cwd() or vim.fn.getcwd(-1, -1)
end

local function is_note_buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  return vim.b[buf].simple_notes_active == true
end

local function ensure_note_buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not is_note_buffer(buf) then
    notify("current buffer is not a simple-notes file", vim.log.levels.WARN)
    return nil
  end
  return buf
end

local function trim(value)
  if not value then
    return ""
  end
  return vim.trim(value)
end

local function prompt_topic()
  vim.fn.inputsave()
  local topic = vim.fn.input("Topic: ")
  vim.fn.inputrestore()
  topic = trim(topic)
  if topic == "" then
    return nil
  end
  return topic
end

local function sanitize_fragment(str)
  local fragment = str:gsub("%s+", "_")
  fragment = fragment:gsub("[^%w_%-]", "")
  if fragment == "" then
    fragment = "note"
  end
  return fragment
end

local function confirm_write(path)
  if not config.options.confirm_writes then
    return true
  end
  local prompt = string.format("Write %s? (y/n) ", vim.fn.fnamemodify(path, ":~."))
  vim.fn.inputsave()
  local answer = vim.fn.input(prompt)
  vim.fn.inputrestore()
  if not answer or answer == "" then
    return false
  end
  local first = string.lower(string.sub(answer, 1, 1))
  return first == "y"
end

local function write_buffer(buf, target)
  buf = buf or vim.api.nvim_get_current_buf()
  local path = target or vim.api.nvim_buf_get_name(buf)
  if path == "" then
    notify("buffer has no name", vim.log.levels.ERROR)
    return false
  end
  if not confirm_write(path) then
    notify("write cancelled", vim.log.levels.INFO)
    return false
  end
  local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd(string.format("silent keepalt keepjumps write! %s", vim.fn.fnameescape(path)))
  end)
  if not ok then
    notify("write failed: " .. err, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function primary_heading_line(topic, stamp)
  stamp = stamp or os.date(config.options.primary_heading_format)
  return string.format("# Note - %s - %s", stamp, topic)
end

local function set_primary_heading(buf, topic, stamp)
  local heading = primary_heading_line(topic, stamp)
  local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  if first and first:match("^#%s*Note") then
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { heading })
  else
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { heading, "" })
  end
  return heading
end

local function extract_primary_heading(buf)
  local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  if not line then
    return nil
  end
  local stamp, topic = line:match("^#%s*Note%s*-%s*(.+)%s*-%s*(.+)$")
  if not stamp then
    return nil
  end
  return {
    line = line,
    stamp = trim(stamp),
    topic = trim(topic),
  }
end

local function build_filename(stamp, topic, opts)
  opts = opts or {}
  if opts.from_heading and stamp then
    stamp = stamp:gsub("%.", "_"):gsub(":", "-")
  end
  local stamp_part = sanitize_fragment(stamp)
  local topic_part = sanitize_fragment(topic)
  local name = string.format("note_%s-%s%s", stamp_part, topic_part, NOTE_EXTENSION)
  local path = vim.fs.joinpath(cwd(), name)
  return vim.fs.normalize(path)
end

function M.note_new()
  local topic = prompt_topic()
  if not topic then
    notify("topic is required", vim.log.levels.WARN)
    return
  end
  local now = os.time()
  local filename = build_filename(os.date(config.options.filename_format, now), topic)
  local heading = primary_heading_line(topic, os.date(config.options.primary_heading_format, now))

  vim.cmd(string.format("tabnew %s", vim.fn.fnameescape(filename)))
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { heading, "" })
  write_buffer(buf, filename)
end

function M.note_add_topic()
  local buf = ensure_note_buffer()
  if not buf then
    return
  end
  local topic = prompt_topic()
  if not topic then
    notify("topic is required", vim.log.levels.WARN)
    return
  end
  set_primary_heading(buf, topic)
end

function M.note_convert_to()
  local buf = ensure_note_buffer()
  if not buf then
    return
  end
  local heading = extract_primary_heading(buf)
  if not heading then
    local topic = prompt_topic()
    if not topic then
      notify("topic is required", vim.log.levels.WARN)
      return
    end
    local stamp = os.date(config.options.primary_heading_format)
    local new_heading = set_primary_heading(buf, topic, stamp)
    heading = {
      line = new_heading,
      stamp = stamp,
      topic = topic,
    }
  end
  local filename = build_filename(heading.stamp, heading.topic, { from_heading = true })
  if not write_buffer(buf, filename) then
    return
  end
  local old = vim.api.nvim_buf_get_name(buf)
  if old ~= filename and old ~= "" and vim.loop.fs_stat(old) then
    vim.loop.fs_unlink(old)
  end
  vim.api.nvim_buf_set_name(buf, filename)
  notify("renamed note to " .. vim.fn.fnamemodify(filename, ":~."))
end

function M.note_add()
  local buf = ensure_note_buffer()
  if not buf then
    return
  end
  local stamp = os.date(config.options.note_heading_format)
  local line = string.format("## %s | ", stamp)
  local total = vim.api.nvim_buf_line_count(buf)
  if total > 0 then
    local last_line = vim.api.nvim_buf_get_lines(buf, total - 1, total, false)[1]
    if last_line ~= "" then
      vim.api.nvim_buf_set_lines(buf, total, total, false, { "" })
      total = total + 1
    end
  end
  vim.api.nvim_buf_set_lines(buf, total, total, false, { line, "" })
  local col = #line
  vim.api.nvim_win_set_cursor(0, { total + 1, col })
end

local function slugify_heading(text)
  local slug = text:lower()
  slug = slug:gsub("[^%w%s-]", "")
  slug = slug:gsub("%s+", "-")
  slug = slug:gsub("-+", "-")
  slug = slug:gsub("^-", "")
  slug = slug:gsub("-$", "")
  return slug
end

local function collect_subheadings(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local headings = {}
  local in_header_block = false
  for idx, line in ipairs(lines) do
    if line == TOC_START then
      in_header_block = true
    elseif line == TOC_END then
      in_header_block = false
    elseif not in_header_block then
      local text = line:match("^##%s+(.+)$")
      if text then
        table.insert(headings, { line = text, slug = slugify_heading(text), idx = idx })
      end
    end
  end
  return headings
end

local function replace_toc(buf, headings)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local start_idx, end_idx
  for i, line in ipairs(lines) do
    if line == TOC_START then
      start_idx = i
    elseif line == TOC_END then
      end_idx = i
      break
    end
  end
  local block
  if #headings == 0 then
    block = {}
  else
    block = { TOC_START, "## Table of Contents", "" }
    for _, head in ipairs(headings) do
      table.insert(block, string.format("- [%s](#%s)", head.line, head.slug))
    end
    table.insert(block, "")
    table.insert(block, TOC_END)
    table.insert(block, "")
  end
  if start_idx and end_idx then
    local replace_end = end_idx
    if lines[end_idx + 1] == "" then
      replace_end = end_idx + 1
    end
    vim.api.nvim_buf_set_lines(buf, start_idx - 1, replace_end, false, block)
  elseif #block > 0 then
    local insert_pos = 0
    local first = lines[1]
    if first and first:match("^#%s*Note") then
      insert_pos = 1
      if lines[2] ~= "" then
        table.insert(block, 1, "")
      end
    end
    vim.api.nvim_buf_set_lines(buf, insert_pos, insert_pos, false, block)
  end
end

function M.note_toc_update(opts)
  opts = opts or {}
  local buf = opts.bufnr or ensure_note_buffer()
  if not buf then
    return
  end
  local headings = collect_subheadings(buf)
  if #headings == 0 then
    replace_toc(buf, {})
    if not opts.automatic then
      notify("no sub-headings found for TOC", vim.log.levels.INFO)
    end
    return
  end
  local win = vim.api.nvim_get_current_win()
  local cursor
  if vim.api.nvim_win_get_buf(win) == buf then
    cursor = vim.api.nvim_win_get_cursor(win)
  end
  replace_toc(buf, headings)
  if cursor then
    pcall(vim.api.nvim_win_set_cursor, win, cursor)
  end
  if not opts.automatic then
    notify("table of contents updated", vim.log.levels.INFO)
  end
end

return M
