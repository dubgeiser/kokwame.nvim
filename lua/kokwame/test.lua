local M = {}

function M.test()
  local buf = vim.api.nvim_get_current_buf()
  local root = vim.treesitter.get_parser(buf, vim.bo.ft):parse()[1]:root()

  local q1 = vim.treesitter.query.parse(vim.bo.ft, '')
  local query = vim.treesitter.query.parse(vim.bo.ft, [[
    (method_declaration name: (name) @function.name) @function.definition
    (function_definition name: (name) @function.name) @function.definition
  ]])

  for _, captures, metadata in query:iter_matches(root, buf) do
    print(vim.inspect(vim.treesitter.get_node_text(captures[1], buf)))
  end
end

return M
