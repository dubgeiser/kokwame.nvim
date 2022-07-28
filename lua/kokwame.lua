--[[ Kokwame - Code Quality Metrics

  Neovim lua module to calculate some code quality metrics on function points.

  A function point is basically a TSNode of a function, method, ...
  These function points are collected into a list, each element in following
  table structure:

     * 'name' = the name
     * 'node' = the node itself
     * 'range' = {line_start, col_start, line_end, col_end } of the name
     * 'metrics' = the metrics for that specific node

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

-- The default options, which can be overridden by passing an identically
-- structured table as argument to the setup() function.
local default_options = {
  -- Should Kokwame be a diagnostic producer?
  is_diagnostic_producer = false,
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


local CyclomaticComplexityMetric = {}
--[[ Create a new cyclomatic complexity metric.

  Return a new CyclomaticComplexityMetric for a given function point node.

  For every one of these operations 1 is added to the total value:
     * Every branch of a condition (if / elif / else)
     * Every iteration
     * Every logical operator
     * The entry point of the method or function

  @param TSNode node The node that this metric will be applied to.
]]
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

  --[[ Calculate this metric for a given node.

    @param TSNode node The function point node to calculate this metric for.
    @param boolean recursing Optional toggle indicating that we are calling from
      `calculate` itself.
  ]]
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

  --[[ Are we dealing with a problematic metric?

    @return boolean Whether or not we're dealing with a problematic result for
      this metric.
  ]]
  function self.is_problematic()
    return value > threshold_low
  end

  --[[ Convert this metric to a diagnostic structure.

    Build and return this metric as an LSP diagnostic structure.

    @param table info Information on the node that this metric belongs to.
  ]]
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


--[[ Is the node of a certain type?

  @param TSNode node The node to check agains a list of types.
  @param table types The list of node types to check against.
  @return boolean Whether or not the type of the given node is in the list of
    given node types.
]]
local function is_type(node, types)
  local t = node:type()
  for _, ctype in ipairs(types) do
    if t == ctype then
      return true
    end
  end
  return false
end


--[[ Get metrics for a given node representing a function point.

  Pre condition: is_function_point(node)

  @param TSNode node The function point node to get metrics on.
]]
local function get_metrics(node)
  local metrics = {
    CyclomaticComplexityMetric.new(node),
  }
  return metrics
end


--[[ Return a string representation of a given node.

  @param TSNode node The node to build a string representation for.
]]
local function node2str(node)
  local range = {node:range()}
  local start_row = range[1] + 1
  local start_col = range[2]
  local end_row = range[3] + 1
  local end_col = range[4]
  return node:type() ..
    ' (' .. start_row .. ', ' .. start_col .. ')' ..
    ' -> ' ..
  '(' .. end_row .. ', ' .. end_col .. ')'
end


--[[ Given a function point node, find and return its naming node (identifier)

  Return a TSNode that is the identifier node of the given node.

  @param TSNode node The node to get the naming node for.
  @return TSNode The node that is the identifier node for the given node, this
    node will contain the name of a function point.
]]
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
    'This probably means get_name_node() was called without checking the ' ..
    'result of is_function_point() on that same node.\n' ..
    'Or there is another type() of children of node that is not yet ' ..
    'accounted for in get_name_node()'
  )
end


--[[ Collect and return all info in the current buffer.

  @return table A list of all the info structs of per function point.
]]
local function all_info()

  if not parsers.has_parser() then return {} end

  --[[ Is the given node a function point node?

    Return `true` if the given node is considered to a function point.

    @param TSNode node The node to check for being a function point or not.
    @return boolean Is the given node a function point?
  ]]
  local function is_function_point(node)
    return is_type(node, node_types)
  end

  --[[ Build info for a function point node

    Pre condition: is_function_point(node)

    @param TSNode node Function point node to build an info struct for.
    @return table Info structure on the given function point node.
  ]]
  local function build_function_point_info(node)
    local info = {}
    local identifier = get_name_node(node)
    info.node = node
    info.name = vim.treesitter.query.get_node_text(identifier, currbuf())
    info.range = {identifier:range()}
    info.metrics = get_metrics(node)
    return info
  end

  --[[ Collect and return info about a function point node

    Return a table with info on each function point.
    Recursively traverse the whole node.

    @param TSNode node Node to collect info on.
    @param table info The list of info structures where info on the given node
           will be collected... but only if we're dealing with a function point.
    @return table List of info structures on each function point.
  ]]
  local function collect_function_point_info(node, info)
    if is_function_point(node) then
      table.insert(info, build_function_point_info(node))
    else
      for child in node:iter_children() do
        collect_function_point_info(child, info)
      end
    end
    return info
  end

  return collect_function_point_info(parsers.get_tree_root(), {})
end


--[[ Return a list of diagnostic structures.

  @return table Diagnostics for each function point that needs some attention.
]]
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


--[[ Handler for textDocument/publishDiagnostics

  @param err ???
  @pram result ???
  @param table ctx The context for the diagnostics.
  @param table config Extra config; this will contain the `original_handler`
]]
local function diagnostics(err, result, ctx, config)
  vim.diagnostic.set(ns_id, currbuf(), get_diagnostics())
 config.original_handler(err, result, ctx, config)
end


--[[ Set up Kokwame as diagnostic producer.
]]
local function setup_diagnostic_producer()
  local original_handler = vim.lsp.handlers['textDocument/publishDiagnostics']
  vim.lsp.handlers['textDocument/publishDiagnostics'] = vim.lsp.with(diagnostics, {
    original_handler = original_handler,
  })
end


--[[ Center a given text according to a given width.

  Return a string with givnen text centered.
  This will prepend the given text with spaces so that it will appear centered
  when displayed in a given width.

  @param string text The text that must be centered
  @param int width The width to which the text must be centered
  @return string The centered text
]]
local function align_center(text, width)
  if #text >= width then return text end
  return string.rep(' ', math.floor((width - #text) / 2)) .. text
end


--[[ Open a window displaying the given function point info

  @param table info Function point info containing the metrics to display.
]]
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


--[[ Is our cursor positioned in a given range?

  @param table range The range as {row_start, col_start, row_end, col_end}
  @return boolean Whether or not the cursor is currently in a given range.
]]
local function is_cursor_in_range(range)
  -- nvim_win_get_cursor() is 1-based, while ranges are 0-based
  local row_cursor = vim.api.nvim_win_get_cursor(0)[1] - 1
  local row_node_start = range[1]
  local row_node_end = range[3]
  return row_cursor >= row_node_start and row_cursor <= row_node_end
end


--[[ Show info for the current function point.

  There's probably a more efficient way to find the relevant node_info for
  the current cursor position.
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
local function info()
  for _, info in ipairs(all_info()) do
    if is_cursor_in_range({info.node:range()}) then
      open_metrics_window(info)
      break
    end
  end
end


--[[ Complete given options with defaults.

  @param table opts Options to which default values will be added.
  @return table Configuration with all required options set.
  @see default_options For a list of options that Kokwame uses.
]]
local function complete_options(opts)
  local opts = opts or {}
  for k, v in pairs(default_options) do
    if not opts[k] then opts[k] = v end
  end
  return opts
end


--[[ Setup Kokwame

  @param table opts Options for kokwame that will override the defaults.
  @see default_options
]]
local function setup(opts)
  opts = complete_options(opts)
  vim.api.nvim_command('command! KokwameInfo lua require("kokwame").info()')
  if opts.is_diagnostic_producer then
    setup_diagnostic_producer()
  end
end


local function test()
  local buf = currbuf()
  local language_tree = vim.treesitter.get_parser(buf, vim.bo.ft)
  local syntax_tree = language_tree:parse()
  local root = syntax_tree[1]:root()

  local q1 = vim.treesitter.parse_query(vim.bo.ft, '')
  local query = vim.treesitter.parse_query(vim.bo.ft, [[
    (method_declaration name: (name) @function.name) @function.definition
    (function_definition name: (name) @function.name) @function.definition
  ]])


  for _, captures, metadata in query:iter_matches(root, buf) do
    print(vim.inspect(vim.treesitter.query.get_node_text(captures[1], buf)))
  end
end


return {
  info = info,
  setup = setup,
  test = test,
}
