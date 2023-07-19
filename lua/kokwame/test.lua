local M = {}

function M.test()
  local buf = vim.api.nvim_get_current_buf()
  local root = vim.treesitter.get_parser(buf, vim.bo.ft):parse()[1]:root()
  local query = vim.treesitter.query.get(vim.bo.ft, 'kokwame-conditionals')

  for _, captures, metadata in query:iter_matches(root, buf) do
    print(vim.inspect(vim.treesitter.get_node_text(captures[1], buf)))
  end
end

return M
