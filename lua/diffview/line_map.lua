-- Nvim 0.12 added `vim.text.diff`. `vim.diff` still works, but LuaLS marks
-- it deprecated. Alias once, as `inline_diff` does.
---@diagnostic disable-next-line: deprecated
local diff = vim.diff

---Following a line of code from one revision of a file into another.
---
---This is pure text work: it takes lines and hunks and gives back a line,
---touching no window, buffer, or view state. It lives on its own because both
---the cursor carry and the change-here walk need it, and neither should have to
---reach through the other's view class to get at it.
local M = {}

---Lines as `vim.diff` input. Without the trailing newline `vim.diff` reports
---an addition or deletion at EOF as a modification of the adjacent line.
---`inline_diff` terminates its input the same way.
---@param lines string[]
---@return string
local function lines_text(lines)
  return table.concat(lines, "\n") .. "\n"
end

---Map a line number from the `a` side of a diff onto the `b` side. A line
---following a hunk shifts by that hunk's size delta. A line inside a hunk has
---no single counterpart, so it maps to the hunk's start in `b`.
---@param hunks integer[][] # `vim.diff` "indices" hunks: `{ start_a, count_a, start_b, count_b }`, ascending.
---@param lnum integer
---@return integer
---@return boolean # `true` when `lnum` fell inside a hunk, i.e. the diff rewrote the code it pointed at.
function M.map(hunks, lnum)
  local delta = 0

  for _, hunk in ipairs(hunks) do
    local start_a, count_a, start_b, count_b = hunk[1], hunk[2], hunk[3], hunk[4]

    if count_a == 0 then
      -- Pure insertion, anchored *after* `start_a`.
      if lnum <= start_a then
        break
      end
      delta = delta + count_b
    else
      local last_a = start_a + count_a - 1
      if lnum < start_a then
        break
      elseif lnum <= last_a then
        -- `start_b` is the hunk's first line in `b`. When the hunk only
        -- deletes, it is the last surviving line before the hunk.
        return math.max(1, start_b), true
      end
      delta = delta + count_b - count_a
    end
  end

  return math.max(1, lnum + delta), false
end

---Diff two revisions of a file and map `lnum` from the first onto the second.
---Takes lines rather than buffers so the history walk can read a revision
---without opening it.
---@param from_lines string[]
---@param to_lines string[]
---@param lnum integer
---@return integer
---@return boolean # `true` when the two revisions differ over `lnum`.
function M.between(from_lines, to_lines, lnum)
  local ok, hunks =
    pcall(diff, lines_text(from_lines), lines_text(to_lines), { result_type = "indices" })

  if not (ok and type(hunks) == "table") then
    return lnum, false
  end

  return M.map(hunks, lnum)
end

return M
