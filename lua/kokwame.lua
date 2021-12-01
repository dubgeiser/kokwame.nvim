-- Kokwame
-- Code Quality Metrics
-- Neovim lua module to calculate some code quality metrics on code units.
-- A code unit is basically a TSNode of a function (or a method).
-- Units are collected into a list of following table structure:
--    * 'name' = the name
--    * 'node' = the node itself
--    * 'range' = {line_start, col_start, line_end, col_end } of the name
--    * 'metrics' = the metrics for that specific node

local tsutils = require('nvim-treesitter.ts_utils')
local parsers = require('nvim-treesitter.parsers')

local PLUGIN_NAME = 'Kokwame'

-- The default options, which can be overridden by passing an identically
-- structured table as argument to the setup() function.
local default_options = {

  -- Should Kokwame be a diagnostic producer?
  produce_diagnostics = false,

}

-- The ID of the namespace we'll be using for this plugin.
local ns_id = vim.api.nvim_create_namespace(PLUGIN_NAME)

-- Cyclomatic complexity metric
-- For every one of these operations 1 is added to the total value:
--    * Every branch of a condition (if / elif / else)
--    * Every iteration
--    * Every logical operator
--    * The entry point of the method or function
local CyclomaticComplexityMetric = {}

-- Create a new metric
--
-- @param TSNode node The node that this metric will be applied to.
-- @return CyclomaticComplexityMetric
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
    case_statement = 1,
  }

  -- Calculate this metric for a given node.
  --
  -- @param TSNode node The node to calculate this metric for.
  -- @param optional bool recursing default: false
  --  Whether or not we are we are calling from within `calculate()` itself.
  local function calculate(node, recursing)
    recursing = recursing or false
    value = value or 0
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
  -- @return bool Whether or not we're dealing with a problematic metric.
  function self.is_problematic()
    return value > threshold_low
  end

  -- Convert this metric to a diagnostic structure.
  --
  -- @param table info Info on the node that this metric belongs to.
  -- @return table Diagnostic structure, see `:help diagnostic-structure`
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
      source = PLUGIN_NAME,
    }
    return diagnostic
  end

  calculate(node)

  return self
end

-- Is the node of a certain type?
--
-- @param TSNode node
-- @param types table List of types that must be considered.
local function is_type(node, types)
  local t = node:type()
  for _, ctype in ipairs(types) do
    if t == ctype then
      return true
    end
  end
  return false
end

-- Get metrics for a given node representing a code unit.
-- The given node should be a code unit node!
--
-- @param TSNode node The code unit to get metrics on.
local function get_metrics(node)
  metric = CyclomaticComplexityMetric.new(node)
  local metrics = {
    metric,
  }
  return metrics
end

-- Given a code unit node, find and return its naming node (identifier)
--
-- @param TSNode node The node to get the naming node for.
-- @return TSNode The identifier node of the given node.
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
    'result of is_code_unit() on that same node.\n' ..
    'Or there is another type() of children of node that is not yet ' ..
    'accounted for in get_name_node()'
  )
end

-- Build info for a node representing a code unit.
-- Pre condition: is_code_unit(node)
--
-- @param TSNode node The node of the code unit to build an info structure for.
-- @return table
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
--
-- @param TSNode node The node to check for relevancy
-- @return bool Whether or not the given node is a code unit.
local function is_code_unit(node)
  return is_type(node, {'function_definition', 'method_declaration'})
end

-- Collect info on a node.
-- The children of the given node will be traversed recursively.
--
-- @param TSNode node The node to collect info on.
-- @param table info The list of info structures where info on the given node
--  will be added if we're dealing with a code unit.
-- @return table List of info structures of the given node and its children.
local function collect_info(node, info)
  if is_code_unit(node) then
    table.insert(info, build_unit_info(node))
  else
    for child in node:iter_children() do
      collect_info(child, info)
    end
  end
  return info
end

--
-- Collect all metrics for all code units for the file in the current buffer.
-- TODO Rename: this returns a list of all the info on all the code units.
-- @return table List of info structures of all the code units.
local function all_metrics()
  if not parsers.has_parser() then
    return {}
  end
  return collect_info(parsers.get_tree_root(), {})
end

-- Return a list of LSP diagnostic structures.
--
-- @return table List of LSP diagnostic structures.
local function get_diagnostics()
  local list = {}
  for _, each in ipairs(all_metrics()) do
    for _, metric in ipairs(each.metrics) do
      if metric.is_problematic() then
        table.insert(list, metric.to_diagnostic(each))
      end
    end
  end
  return list
end

-- Handler for textDocument/publishDiagnostics
--
-- @param ? err
-- @param ? result
-- @param table ctx The context for the diagnostics
-- @param table config Extra configuration; will contain the `original_handler`
local function diagnostics(err, result, ctx, config)
  vim.diagnostic.set(
    ns_id,
    vim.api.nvim_get_current_buf(),
    get_diagnostics()
  )
 config.original_handler(err, result, ctx, config)
end

-- Set up LSP diagnostics for Kokwame.
local function setup_lsp_diagnostics()
  local original_handler = vim.lsp.handlers['textDocument/publishDiagnostics']
  vim.lsp.handlers['textDocument/publishDiagnostics'] = vim.lsp.with(diagnostics, {
    original_handler = original_handler,
  })
end

-- Center a given text according to a given width.
-- This will prepend the given text with spaces so that it will appear centered
-- when displayed in a given width.
--
-- @param string text The text to align
-- @param int width The width to which the text must be aligned.
-- @return string The centered text
local function align_center(text, width)
  if #text >= width then return text end
  return string.rep(' ', math.floor((width - #text) / 2)) .. text
end

-- Open a window displaying the given code unit info
--
-- @param table info The code unit info of which the metrics should be
--  displayed in a window.
local function open_metrics_window(info)
  local lines = {}
  local max_width = #info.name
  for i, metric in ipairs(info.metrics) do
    local line = ' '..i..'. '..metric.to_diagnostic(info).message..' '
    max_width = math.max(max_width, #line)
    table.insert(lines, line)
  end
  table.insert(lines, 1, align_center(info.name, max_width))
  table.insert(lines, 2, '')
  local opts = {
    height = #lines, -- Including top/bottom padding if necessary
    width = max_width,
    wrap = false,
    focusable = true,
    focus = true,
  }
  vim.lsp.util.open_floating_preview(lines, 'markdown', opts)
end

-- Is our cursor positioned in a given range?
--
-- @param table range The range as {row_start, col_start, row_end, col_end}
-- @return bool Whether or not the position of the cursor is in a given range.
local function is_cursor_in_range(range)
  -- nvim_win_get_cursor() is 1-based, while ranges are 0-based
  local row_cursor = vim.api.nvim_win_get_cursor(0)[1] - 1
  local row_node_start = range[1]
  local row_node_end = range[3]
  return row_cursor >= row_node_start and row_cursor <= row_node_end
end

-- Show info for the current code unit.
-- There's probably a more efficient way to find the relevant node_info for
-- the current cursor position.
-- But I've been experimenting with `tsutils.get_node_at_cursors()` and then
-- traveling up the tree via `node:parent()` but this gets quite hairy if you
-- want to take some expected UI behavior into account:
-- Consider this PHP method where '|' is the cursor:
--
-- class Foo {
-- |   public function foobar() {
--     }
-- }
--
-- Upon `:KokwameInfo` this will travel up the tree and find no code unit.
-- So then one has to try the next node, etc... of course a lot of nil checking
-- has to be done in between to check if we're still finding nodes; What if the
-- cursor is at the end of the buffer, etc, etc, etc...
-- It's quite ugly tbh. and I think more is gained by building a light weight
-- structure of all the relevant nodes and gather metrics on a need-to-know
-- basis.
-- This together with tsutils.memoize_by_buf_tick should make fairly simple
-- code that is performant enough to not worry about it.
-- If not, we can still make it _very_ hairy ;-)
local function info()
  for _, info in ipairs(all_metrics()) do
    if is_cursor_in_range({info.node:range()}) then
      open_metrics_window(info)
      break
    end
  end
end

-- Set the defaults on given options if they've not been set.
--
-- @param table opts The options to which the defaults will be added.
-- @return table The given options with added defaults for unset options.
local function set_defaults(opts)
  local opts = opts or {}
  for k, v in pairs(default_options) do
    if not opts[k] then opts[k] = v end
  end
  return opts
end

-- Setup Kokwame
--
-- @param table opts The options for Kokwame that will override the defaults.
-- @see default_options
local function setup(opts)
  opts = set_defaults(opts)
  vim.api.nvim_command('command! KokwameInfo lua require("kokwame").info()')
  if opts.produce_diagnostics then
    setup_lsp_diagnostics()
  end
end

return {
  info = info,
  setup = setup,
}
