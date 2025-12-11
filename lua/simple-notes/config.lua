local M = {}

local defaults = {
  use_md = false,
  confirm_writes = true,
  auto_toc_on_save = true,
  filename_format = "%Y-%m-%d_%H-%M",
  primary_heading_format = "%Y-%m-%d.%H:%M",
  note_heading_format = "%Y-%m-%d.%H:%M",
}

M.options = vim.deepcopy(defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", defaults, opts or {})
  return M.options
end

return M
