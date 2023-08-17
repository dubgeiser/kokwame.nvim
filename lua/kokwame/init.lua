--[[ Kokwame - Code Quality Metrics

  Neovim lua module to calculate some code quality metrics on functions.

  A function is a TSNode representing a function or a method.
  These function points are collected into a list, each element in following
  table structure:

     * 'name' = the name of the function
     * 'node' = the node itself
     * 'range_name' = {line_start, col_start, line_end, col_end } of the name
     * 'metrics' = the metrics for that specific node
     * 'has_cursor()' = whether or not the cursor is somewhere in the fucntion

  See the function `build_function_point_info` for the real code version of
  this structure.
]]

local parsers = require('nvim-treesitter.parsers')


-- Use `currbuf()` to get the current buffer!
--
-- Reads fine as "current buffer" and is way less greedy on line length.
-- And separating it in a local function provides opportunity to build in some
-- lazy loading / caching later down the line.
local currbuf = vim.api.nvim_get_current_buf

local PLUGIN_NAME = 'Kokwame'
local M = {}

-- The default options, which can be overridden by passing an identically
-- structured table as argument to the setup() function.
local options = {
  -- Should Kokwame be a diagnostic producer?
  is_diagnostic_producer = false,

  -- Which type of border?
  -- Will be used for vim.lsp.util.open_floating_preview()
  border = 'rounded',
}

-- The node types that are considered to be function points.
local node_types = {
  'function_definition',
  'method_declaration',
}

-- The node types that are considered to be the declaration of a function point.
local declaration_node_types = {
  'function_declarator',
}

-- The node types that are considered to be a name of a function point.
local name_node_types = {
  'identifier',
  'name',
}

-- The ID of the namespace we'll be using for this plugin.
local ns_id = vim.api.nvim_create_namespace(PLUGIN_NAME)

-- Cyclomatic cmplexity metric.
-- For every one of these operations 1 is added to the total value:
--    * Every branch of a condition (if / elif / else)
--    * Every iteration
--    * Every logical operator
--    * The entry point of the method or function
local CyclomaticComplexityMetric = {}

---@param node TSNode The node that this metric will be applied to.
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

  ---@param node TSNode The function point to calculate this metric for.
  ---@param recursing boolean|nil Whether or not we are recursing.
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
      -- The function point itself counts too.
      value = value + 1
    end
  end

  ---@return boolean
  function self.is_problematic()
    return value > threshold_low
  end

  ---@param info table Information on the node that this metric belongs to.
  ---@return table - LSP diagnostic structure
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
      lnum = info.range_name[1],
      col = info.range_name[2],
      end_lnum = info.range_name[3],
      end_col = info.range_name[4],
      severity = severity,
      message = message,
      source = PLUGIN_NAME,
    }
    return diagnostic
  end

  calculate(node)

  return self
end

---@param node TSNode The node to check against a list of types.
---@param types table The list of types to check against
---@return boolean
local function is_type(node, types)
  local t = node:type()
  for _, ctype in ipairs(types) do
    if t == ctype then
      return true
    end
  end
  return false
end

---@param node TSNode The function node to get metrics on.
---@return CyclomaticComplexityMetric
local function get_metrics(node)
  local metrics = {
    CyclomaticComplexityMetric.new(node),
  }
  return metrics
end


---@param node TSNode The node to build a string represenation for.
---@return string
local function node2str(node)
  local range = { node:range() }
  local start_row = range[1] + 1
  local start_col = range[2]
  local end_row = range[3] + 1
  local end_col = range[4]
  return node:type() ..
      ' (' .. start_row .. ', ' .. start_col .. ')' ..
      ' -> ' ..
      '(' .. end_row .. ', ' .. end_col .. ')'
end

---@param node TSNode The node to get the naming node for (its identifier)
---@return TSNode - The node that is the identifier for the given node, this
---                 will contain the name of a function point.
local function get_name_node(node)
  for child in node:iter_children() do
    if is_type(child, name_node_types) then
      return child
    elseif is_type(child, declaration_node_types) then
      return get_name_node(child)
    end
  end
  error(
    'ERROR: Cannot find the name node [' .. node2str(node) .. ']\n' ..
    'This probably means get_name_node() was called on a non-function node\n' ..
    'Or there is another node type not yet accounted for in get_name_node()\n'
  )
end

---@param node TSNode
---@return table - Info structure of the given function point node.
local function build_function_info(node, buf)
  local identifier = get_name_node(node)
  -- nvim_win_get_cursor() is 1-based, while ranges are 0-based
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local start_row, start_col, end_row, end_col = node:range()

  local info = {}
  info.name = vim.treesitter.get_node_text(identifier, buf)
  info.node = node
  info.range_name = { identifier:range() }
  info.metrics = get_metrics(node)
  info.has_cursor = function ()
    return  cursor_row >= start_row and cursor_row <= end_row
  end
  return info
end

---@return table - A list of all the info structs for each function in the
---                current buffer
local function all_info()
  if not parsers.has_parser() then return {} end
  local info = {}
  local root = parsers.get_tree_root()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo.filetype
  -- TODO Fool proofing; this breaks if no query files exist for a file type
  local query = vim.treesitter.query.get(ft, 'kokwame-functions')
  for _, match, metadata in query:iter_matches(root, buf) do
    for id, node in pairs(match) do
      table.insert(info, build_function_info(node, buf))
    end
  end
  return info
end

---@return table - Diagnostics for each function point that is problematic.
local function get_diagnostics()
  local list = {}
  for _, each in ipairs(all_info()) do
    for _, metric in ipairs(each.metrics) do
      if metric.is_problematic() then
        table.insert(list, metric.to_diagnostic(each))
      end
    end
  end
  return list
end

---@param err any?
---@param result any?
---@param ctx table The context for the diagnostics.
---@param config table Extra config; this will contain the `original_handler`.
local function diagnostics(err, result, ctx, config)
  vim.diagnostic.set(ns_id, currbuf(), get_diagnostics())
  config.original_handler(err, result, ctx, config)
end

local function setup_diagnostic_producer()
  local original_handler = vim.lsp.handlers['textDocument/publishDiagnostics']
  vim.lsp.handlers['textDocument/publishDiagnostics'] = vim.lsp.with(diagnostics, {
    original_handler = original_handler,
  })
end

---@param text string The text to center.
---@param width integer Width to center the text against
---@return string - The centered text
local function align_center(text, width)
  if #text >= width then return text end
  return string.rep(' ', math.floor((width - #text) / 2)) .. text
end

---@param info table Info on function point, contains the metrics to display.
local function open_metrics_window(info)
  local lines = {}
  local max_width = #info.name
  for i, metric in ipairs(info.metrics) do
    local line = ' ' .. i .. '. ' .. metric.to_diagnostic(info).message .. ' '
    max_width = math.max(max_width, #line)
    table.insert(lines, line)
  end
  table.insert(lines, 1, align_center(info.name, max_width))
  table.insert(lines, 2, '')
  local opts = {
    border = options.border,
    height = #lines, -- Including top/bottom padding if necessary
    width = max_width,
    wrap = false,
    focusable = true,
    focus = true,
  }
  vim.lsp.util.open_floating_preview(lines, 'markdown', opts)
end

--[[ Show info for the current function point.

  There's probably a more efficient way to find the relevant node_info for
  the current cursor position.

  Note that vim.treesitter.get_node_at_pos() and ...get_node_at_cursor() are
  both deprecated in favor of vim.treesitter.get_node()!
  But I've been experimenting with `tsutils.get_node_at_cursors()` and then
  traveling up the tree via `node:parent()` but this gets quite hairy if you
  want to take some expected UI behavior into account:
  Consider this PHP method where '|' is the cursor:

    class Foo {
    |   public function foobar() {
        }
    }

  Upon `:KokwameInfo` this will travel up the tree and find no function point.
  So then one has to try the next node, etc... of course a lot of nil checking
  has to be done in between to check if we're still finding nodes; What if the
  cursor is at the end of the buffer, etc, etc, etc...
  It's quite ugly tbh. and I think more is gained by building a light weight
  structure of all the relevant nodes and gather metrics on a need-to-know
  basis.
  This together with tsutils.memoize_by_buf_tick should make fairly simple
  code that is performant enough to not worry about it.
  If not, we can still make it _very_ hairy ;-)
]]
function M.info()
  for _, info in ipairs(all_info()) do
    if info.has_cursor() then
      open_metrics_window(info)
      return
    end
  end
  print(PLUGIN_NAME .. ": Cannot gather metrics; cursor is not inside a function point.")
end

---@param opts table Options to which default options will be added if not set.
local function set_options(opts)
  opts = opts or {}
  for k, v in pairs(opts) do
    if options[k] == nil then
      error('Unknown option [' .. k .. ']')
    else
      options[k] = v
    end
  end
end

---@param opts table Options for Kokwame overriding the defaults.
---@see options
function M.setup(opts)
  set_options(opts)
  vim.api.nvim_command('command! KokwameInfo lua require("kokwame").info()')
  if options.is_diagnostic_producer then
    setup_diagnostic_producer()
  end
end

return M
