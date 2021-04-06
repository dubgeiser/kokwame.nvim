-- Kokwame
-- Code Quality Metrics
-- Neovim plugin that will calculate some code quality related metrics on code
-- units.
-- A unit is basically a function (or a method) that is relevant to us to collect
-- metrics from.

-- TODO Re-evaluate function names.
-- TODO are there more types that should be relevant, see _is_relevant_unit()

local utils = require('nvim-treesitter.ts_utils')
local parsers = require('nvim-treesitter.parsers')

local M = {}

-- Is the node of a certain type?
function M.is_type(node, types)
  local t = node:type()
  for _, ctype in ipairs(types) do
    if t == ctype then
      return true
    end
  end
  return false
end

-- Get metrics for a given node representing a node unit.
function M._get_metrics(node)
  local metrics = {}
  metrics.cyclomatic_complexity = M._metric_cyclomatic_complexity(node)
  return metrics
end

function M._is_conditional(node)
  return M.is_type(node, {'if_statement', 'elif_clause', 'else_clause'})
end

function M._is_iteration(node)
  return M.is_type(node, {'for_statement'})
end

-- Calculate cyclomatic complexity metric of a relevant node.
-- Cyclomatic complexity here is:
-- 1 for the unit (function/method)
-- +1 for every iteration
-- +1 for every conditional
-- +1 for every branch in the conditional
-- +1 for every logical operator in the conditional
-- @param node The parent node indicating the function/method.
function M._metric_cyclomatic_complexity(node)
  return 1
end

-- Given a relevant node, find and return its naming node (identifier)
function M._get_name_node(node)
  for child in node:iter_children() do
    local t = child:type()
    if M.is_type(child, {'identifier', 'name'}) then
      return child
    elseif M.is_type(child, {'function_declarator'}) then
      return M._get_name_node(child)
    end
  end
  error(
    'ERROR: Cannot find the name node.\n' ..
    'This probably means _get_name_node() was called without checking the ' ..
    'result of _is_relevant_unit() on that same node.\n' ..
    'Or there is another type() of children of node that is not yet ' ..
    'accounted for in _get_name_node()'
  )
end

-- Build info for a node representing a code unit.
-- Pre condition: M._is_relevant_unit(node)
function M._build_unit_info(node)
  local info = {}
  local identifier = M._get_name_node(node)
  info.name = utils.get_node_text(identifier)[1]
  -- TODO assure not off-by-ones, I think :range() returns zero-based.
  info.range = {identifier:range()}
  info.metrics = M._get_metrics(node)
  return info
end

-- Is the given node a code unit that we care enough about to gather metrics for?
function M._is_relevant_unit(node)
  return M.is_type(node, {'function_definition', 'method_declaration'})
end

-- Collect info on a node.
function M._collect_info(node, info)
  if M._is_relevant_unit(node) then
    table.insert(info, M._build_unit_info(node))
  else
    for child in node:iter_children() do
      M._collect_info(child, info)
    end
  end
  return info
end

-- Collect all metrics for all relevant units for the file in the current buffer.
function M.all_metrics()
  if not parsers.has_parser() then
    return nil
  end
  local root = parsers.get_tree_root()
  local info = M._collect_info(root, {})
  for _, each in ipairs(info) do
    print(vim.inspect(each))
  end
end

return M
