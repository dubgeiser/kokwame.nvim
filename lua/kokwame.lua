-- Kokwame
-- Code Quality Metrics
-- Neovim lua module to calculate some code quality metrics on code units.
-- A unit is basically a function (or a method).
-- Units are collected into a list of following table structure:
--    * 'name' = the name
--    * 'node' = the node itself
--    * 'range' = {line_start, col_start, line_end, col_end } of the name
--    * 'metrics' = the metrics for that specific node

local api = vim.api
local exec = vim.cmd
local lsputils = vim.lsp.util

local tsutils = require('nvim-treesitter.ts_utils')
local parsers = require('nvim-treesitter.parsers')

local ns_id = api.nvim_create_namespace('')

-- Cyclomatic complexity metric
-- For every one of these operations 1 is added to the total value:
--    * Every branch of a condition (if / elif / else)
--    * Every iteration
--    * Every logical operator
--    * The entry point of the method or function
local CyclomaticComplexityMetric = {}

-- Create a new metric
--
-- @param TSNode node
--  The node that this metric will be applied to.
CyclomaticComplexityMetric.new = function(node)
  local self = {}
  local value = nil
  local threshold_low = 7
  local threshold_high = 12
  local meaningful_node_types = {
    if_statement = 1,
    elif_clause = 1,
    else_clause = 1,
    for_statement = 1,
    foreach_statement = 1,
    boolean_operator = 1,
    binary_expression = .50,
  }

  -- Calculate this metric for a given node.
  --
  -- @param TSNode node
  --  The node to calculate this metric for.
  -- @param optional bool recursing default: flase
  --  Whether or not we are recursing, only used internally.
  local function calculate(node, recursing)
    recursing = recursing or false
    if value == nil then
      value = 0
    end
    for child in node:iter_children() do
      if meaningful_node_types[child:type()] then
        value = value + meaningful_node_types[child:type()]
      end
      calculate(child, true)
    end
    if not recursing then
      value = value + 1 -- +1 for entry point of the code unit
    end
  end

  -- Are we dealing with a problematic metric?
  --
  -- @return bool
  function self.is_problematic()
    return value > threshold_low
  end

  -- @param table info
  --  Info on the node that this metric belongs to.
  -- @return table
  --  Diagnostic structure, see `:help diagnostic-structure`
  function self.to_diagnostic(info)
    local severity = vim.diagnostic.severity.INFO
    local message = 'Cyclomatic Complexity: ' .. value
    if value > threshold_low and value <= threshold_high then
      severity = vim.diagnostic.severity.WARN
    elseif value > threshold_high then
      severity = vim.diagnostic.severity.ERROR
    else
      severity = vim.diagnostic.severity.INFO
    end
    local diagnostic = {
      lnum = info.range[1],
      col = info.range[2],
      end_lnum = info.range[3],
      end_col = info.range[4],
      severity = severity,
      message = message,
      source = 'TODO', -- TODO Lookup what this property is for.
    }
    return diagnostic
  end

  calculate(node)

  return self
end

-- Is the node of a certain type?
--
-- @param TSNode node
-- @param types table
--  List of types that must be considered.
local function is_type(node, types)
  local t = node:type()
  for _, ctype in ipairs(types) do
    if t == ctype then
      return true
    end
  end
  return false
end

-- Get metrics for a given node representing a relevant code unit.
local function get_metrics(node)
  metric = CyclomaticComplexityMetric.new(node)
  local metrics = {
    metric,
  }
  return metrics
end

-- Given a relevant node, find and return its naming node (identifier)
local function get_name_node(node)
  for child in node:iter_children() do
    if is_type(child, {'identifier', 'name'}) then
      return child
    elseif is_type(child, {'function_declarator'}) then
      return get_name_node(child)
    end
  end
  error(
    'ERROR: Cannot find the name node.\n' ..
    'This probably means get_name_node() was called without checking the ' ..
    'result of is_relevant_unit() on that same node.\n' ..
    'Or there is another type() of children of node that is not yet ' ..
    'accounted for in get_name_node()'
  )
end

-- Build info for a node representing a code unit.
-- Pre condition: is_relevant_unit(node)
local function build_unit_info(node)
  local info = {}
  local identifier = get_name_node(node)
  info.node = node
  info.name = tsutils.get_node_text(identifier)[1]
  info.range = {identifier:range()}
  info.metrics = get_metrics(node)
  return info
end

-- Is the given node a code unit that we care enough about to gather metrics for?
local function is_relevant_unit(node)
  return is_type(node, {'function_definition', 'method_declaration'})
end

-- Collect info on a node.
local function collect_info(node, info)
  if is_relevant_unit(node) then
    table.insert(info, build_unit_info(node))
  else
    for child in node:iter_children() do
      collect_info(child, info)
    end
  end
  return info
end

--
-- Collect all metrics for all relevant units for the file in the current buffer.
-- TODO Rename: this returns a list of all the info of relevant nodes.
--
local function all_metrics()
  if not parsers.has_parser() then
    return {}
  end
  return collect_info(parsers.get_tree_root(), {})
end

-- The on_attach handler that will be called when an LSP client is attached to
-- a buffer.
--
-- @param vim.lsp.client client
-- @param int bufnr
-- TODO Keep diagnostics visible (atm. they only briefly display).
--      This seems only to be the case with pyright...
-- TODO Keep diagnostics in sync when editing a buffer.
local function diagnostics(client, bufnr)
  local list = {}
  for _, each in ipairs(all_metrics()) do
    for _, metric in ipairs(each.metrics) do
      if metric.is_problematic() then
        table.insert(list, metric.to_diagnostic(each))
      end
    end
  end
  vim.diagnostic.set(
    vim.lsp.diagnostic.get_namespace(client.id),
    bufnr,
    list
  )
end

-- Center a given text according to a given width.
--
-- @param string text
--  The text to align
-- @param int width
--  The width to which the text must be aligned.
-- @return string
--  The centered text
local function align_center(text, width)
  if #text >= width then return text end
  return string.rep(' ', math.floor((width - #text) / 2)) .. text
end

-- Open a window displaying the given code unit info
-- @param table info
--  The code unit info of which the metrics should be displayed in a window.
local function open_metrics_window(info)
  local buf_lines = {}
  local max_width = #info.name
  for i, metric in ipairs(info.metrics) do
    local line = ' '..i..'. '..metric.to_diagnostic(info).message..' '
    max_width = math.max(max_width, #line)
    table.insert(buf_lines, line)
  end
  table.insert(buf_lines, 1, align_center(info.name, max_width))
  table.insert(buf_lines, 2, '')
  local opts = {
    relative = 'cursor',
    width = max_width,
    height = #buf_lines,

    -- Make it look like the cursor stays in place.
    anchor = 'NW',
    col = -1,
    row = -1,

    style = 'minimal',
    border = 'rounded'
  }
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, true,  buf_lines)
  api.nvim_open_win(buf, true, opts)
end

-- Is our cursor positioned in a given range?
--
-- @param table range
--  The range as {row_start, col_start, row_end, col_end}
-- @return bool
--  Whether or not the position of the cursor is in a given range.
local function cursor_in_range(range)
  -- nvim_win_get_cursor() is 1-based, while ranges are 0-based
  local row_cursor = api.nvim_win_get_cursor(0)[1] - 1
  local row_node_start = range[1]
  local row_node_end = range[3]
  return row_cursor >= row_node_start and row_cursor <= row_node_end
end

-- Toggle Kokwame for the current code unit.
local function toggle()
  -- TODO There's probably a more efficient way to find the relevant node_info
  --      for the current cursor position.
  for _, info in ipairs(all_metrics()) do
    if cursor_in_range({info.node:range()}) then
      open_metrics_window(info)
      break
    end
  end
end


exec [[ command KokwameToggle lua require'kokwame'.toggle() ]]


return {
  toggle = toggle,
  diagnostics = diagnostics,
}
