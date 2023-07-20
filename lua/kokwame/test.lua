local M = {}

local function print_query_matches(node, buf, query_name)
  local query = vim.treesitter.query.get(vim.bo.ft, query_name)
  for _, captures, metadata in query:iter_matches(node, buf) do
    if #captures >= 1 then
      print(vim.inspect(vim.treesitter.get_node_text(captures[1], buf)))
    else
      print('empty, else clause?')
    end
  end
end

function M.test()
  local buf = vim.api.nvim_get_current_buf()
  local root = vim.treesitter.get_parser(buf, vim.bo.ft):parse()[1]:root()
  -- print_query_matches(root, buf, 'kokwame-functions')
  print_query_matches(root, buf, 'kokwame-conditionals')
  -- print_query_matches(root, buf, 'kokwame-iterations')
end

return M
