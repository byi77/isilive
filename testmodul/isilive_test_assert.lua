local Assert = {}

local function fail(message)
  error(message or "assertion failed", 2)
end

function Assert.Fail(message)
  fail(message)
end

function Assert.Equal(actual, expected, message)
  if actual ~= expected then
    fail(string.format("%s (got=%s expected=%s)", message or "expected equal", tostring(actual), tostring(expected)))
  end
end

function Assert.True(value, message)
  if value ~= true then
    fail(message or "expected true")
  end
end

function Assert.False(value, message)
  if value ~= false then
    fail(message or "expected false")
  end
end

function Assert.Nil(value, message)
  if value ~= nil then
    fail((message or "expected nil") .. " (got=" .. tostring(value) .. ")")
  end
end

function Assert.NotNil(value, message)
  if value == nil then
    fail(message or "expected non-nil value")
  end
end

return Assert
