local M = {}

local function print_query_matches(node, buf, query_name)
  local query = vim.treesitter.query.get(vim.bo.ft, query_name)
  local nquery = vim.treesitter.query.parse(vim.bo.ft, "name: (name) @name")
  for _, matches, metadata in query:iter_matches(node, buf) do
    for id, node in pairs(matches) do
      for _, nmatches, nmetadata in nquery:iter_matches(node, buf) do
        for nid, nnode in pairs(nmatches) do
          print(vim.inspect(vim.treesitter.get_node_text(nnode, buf)))
        end
      end
    end
  end
end

function M.test()
  local buf = vim.api.nvim_get_current_buf()
  local root = vim.treesitter.get_parser(buf, vim.bo.ft):parse()[1]:root()
  print_query_matches(root, buf, 'kokwame-functions')
  -- print_query_matches(root, buf, 'kokwame-conditionals')
  -- print_query_matches(root, buf, 'kokwame-iterations')
end

return M
