-- mkdnflow.nvim (Tools for personal markdown notebook navigation and management)
-- Copyright (C) 2022 Jake W. Vincent <https://github.com/jakewvincent>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either vervim.show_pos()sion 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local M = {}

-- M.getHeadingLevel = function(line, current_line)
--   local level
--   if line then
--     -- level = line:match('^%s-(#+)')
--     level = line:match('^(#+)%s')
--   end
--   return (level and string.len(level)) or 99
-- end


local ts_success, ts_result_or_error = pcall(require, 'nvim-treesitter.ts_utils')


M.getHeadingLevel = function(line, current_line)
  local current_line = current_line - 1
  local function getCapture(current_line)
    -- return vim.inspect_pos(0, current_line).treesitter[1].capture
    return vim.inspect_pos(0, current_line, 0, nil).treesitter[1].capture
  end
  ---[[
  local success, capture = pcall(getCapture, current_line)
  if success and capture then
    local num = capture:match('text.title.(%d).marker')
    if num then
      -- level = tonumber(num)
      level = line:match('^(#+)%s')
      -- print(level)
    end
  else
    if ts_success then
      level = nil
    else
      level = line:match('^(#+)%s')
    end
  end
  local level_v = (level and string.len(level)) or 99
  if level_v == 1 and not capture:match('text.title') then
    level_v = 99
  end
  local matched = line:match('^(#+)%s')
  if matched then
  else
    level_v = 99
  end
  -- print(line, level_v)
  return level_v
end

local get_section_range = function(start_row)
  start_row = start_row or vim.api.nvim_win_get_cursor(0)[1]
  local line, n_lines = vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, false)[1], vim.api.nvim_buf_line_count(0)
  local current_line = start_row
  local heading_level = M.getHeadingLevel(line, current_line)
  if heading_level > 0 then
    local continue = true
    local end_row = start_row + 1
    while continue do
      local next_line = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, false)
      if next_line[1] then
        if M.getHeadingLevel(next_line[1], end_row) <= heading_level then
          continue = false
        else
          end_row = end_row + 1
        end
      elseif end_row <= n_lines then -- Line might just be empty; make sure we're not at end of buffer
        end_row = end_row + 1
      else                           -- End of buffer reached
        continue = false
      end
    end
    return { start_row, end_row - 1 }
  end
end

local get_nearest_heading = function()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local continue = true
  while continue and row > 0 do
    local prev_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    if M.getHeadingLevel(prev_line, row) < 99 then
      continue = false
      return row
    else
      row = row - 1
    end
  end
end

-- M.foldSection = function()
--     local line = vim.api.nvim_get_current_line()
--     if M.getHeadingLevel(line) < 99 then
--         local range = get_section_range()
--         if range then
--             vim.cmd(tostring(range[1])..','..tostring(range[2])..'fold')
--         end
--     else
--         local start_row = get_nearest_heading()
--         if start_row then
--             local range = get_section_range(start_row)
--             if range then
--                 vim.cmd(tostring(range[1])..','..tostring(range[2])..'fold')
--             end
--         end
--     end
-- end

M.foldSection = function()
  local line = vim.fn.line('.')
  vim.cmd("set foldmethod=manual")
  local is_fold_closed = vim.fn.foldclosed(line) ~= -1
  if is_fold_closed then
    return vim.cmd([[silent! norm!zo]])
  end

  local line_content = vim.api.nvim_get_current_line()
  if M.getHeadingLevel(line_content, line) < 99 then
    local range = get_section_range()
    if range then
      vim.cmd(tostring(range[1]) .. ',' .. tostring(range[2]) .. 'fold')
    end
  else
    local start_row = get_nearest_heading()
    if start_row then
      local range = get_section_range(start_row)
      if range then
        vim.cmd(tostring(range[1]) .. ',' .. tostring(range[2]) .. 'fold')
      end
    end
  end
end


M.unfoldSection = function(row)
  row = row or vim.api.nvim_win_get_cursor(0)[1]
  vim.cmd("set foldmethod=manual")
  local foldstart = vim.fn.foldclosed(tostring(row))
  if foldstart > -1 then
    local foldend = vim.fn.foldclosedend(tostring(row))
    vim.cmd(tostring(foldstart) .. ',' .. tostring(foldend) .. 'foldopen')
  end
end

M.global_cycle_mode = 'Overview' -- Initial state

-- Function to get capture using treesitter
local function getCapture(line_number)
  return vim.inspect_pos(0, line_number, 0, nil).treesitter[1].capture
end

-- Check if a line is a markdown header
local function isMarkdownHeader(line)
  return string.find(line, '^#+%s') ~= nil
end

-- Check if a line starts with 4 spaces or a tab
local function isIndented(line)
  return line:match("^    ") or line:match("^\t")
end

-- Check if a line is a header using treesitter
local function isTreesitterHeader(capture)
  return capture:match('text.title.(%d).marker') ~= nil
end

_G.mkdnflowFoldFunction = function(line_number)
  local success, capture = pcall(getCapture, line_number - 1) -- Adjusting for 0-based index
  local next_line_success, next_capture = pcall(getCapture, line_number)
  local line = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)[1]
  local next_line = vim.api.nvim_buf_get_lines(0, line_number, line_number + 1, false)[1]

  if success and isTreesitterHeader(capture) then
    return 1 -- Header level
  elseif not success and isMarkdownHeader(line) then
    return 1
  elseif line == '' and success then
    return 1
  elseif line == '' and (isMarkdownHeader(next_line) or (next_line_success and isTreesitterHeader(next_capture))) then
    return 0
  elseif isIndented(line) or (next_line and isIndented(next_line)) then
    return 2 -- Contents level
  else
    return 1
  end

  return 2 -- Default fold level
end

M.foldCycle = function()
  -- Set the fold method to expression and use the foldFunction to determine fold levels
  vim.cmd("set foldmethod=expr")
  vim.cmd("set foldexpr=v:lua._G.mkdnflowFoldFunction(v:lnum)")

  -- Now, based on the current cycle mode, perform the folding operation
  if M.global_cycle_mode == 'Show All' then
    M.global_cycle_mode = 'Overview'
    vim.api.nvim_out_write("[mkdnflow] Overview\n")
    vim.cmd([[silent! norm!zMzX]])
  elseif M.global_cycle_mode == 'Overview' then
    M.global_cycle_mode = 'Contents'
    vim.api.nvim_out_write("[mkdnflow] Contents\n")
    vim.wo.foldlevel = 1
    vim.cmd([[silent! norm!zx]])
  else -- Contents
    M.global_cycle_mode = 'Show All'
    vim.api.nvim_out_write("[mkdnflow] Show All\n")
    vim.cmd([[silent! norm!zR]])
  end
end

return M
