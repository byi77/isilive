---@diagnostic disable: undefined-global
local io = io
local ipairs = ipairs
local pairs = pairs
local string = string
local table = table
local tonumber = tonumber
local tostring = tostring
local type = type

local Validator = {}

local VALID_STATUSES = {
  active = true,
  draft = true,
  deprecated = true,
  disabled = true,
}

local STATUS_ALIASES = {
  active = "active",
  aktiv = "active",
  draft = "draft",
  entwurf = "draft",
  deprecated = "deprecated",
  veraltet = "deprecated",
  disabled = "disabled",
  deaktiviert = "disabled",
}

local function Trim(value)
  local text = tostring(value or "")
  text = text:gsub("^%s+", "")
  text = text:gsub("%s+$", "")
  return text
end

local function NormalizeStatus(value)
  local normalized = string.lower(Trim(value))
  return STATUS_ALIASES[normalized] or normalized
end

local function NormalizeTestReference(value)
  local normalized = Trim(value)
  normalized = normalized:gsub("^`", "")
  normalized = normalized:gsub("`$", "")
  normalized = normalized:gsub('^"', "")
  normalized = normalized:gsub('"$', "")
  normalized = Trim(normalized)
  return normalized
end

local function NormalizeSummarySignature(value)
  local normalized = string.lower(Trim(value))
  normalized = normalized:gsub("%s+", " ")
  return normalized
end

local function ParseRulesFile(path)
  local file, openErr = io.open(path, "rb")
  if not file then
    return nil, { string.format("rules: cannot read %s: %s", path, tostring(openErr)) }, {}
  end

  local rules = {}
  local errors = {}
  local warnings = {}
  local currentRule = nil
  local inRequiredTests = false
  local lineNumber = 0

  local function PushCurrentRule()
    if currentRule then
      table.insert(rules, currentRule)
      currentRule = nil
    end
  end

  for rawLine in file:lines() do
    lineNumber = lineNumber + 1

    local ruleID = rawLine:match("^###%s+([%w%-%._]+)%s*$")
    if ruleID then
      PushCurrentRule()
      currentRule = {
        id = Trim(ruleID),
        status = "draft",
        summary = nil,
        requiredTests = {},
        line = lineNumber,
      }
      inRequiredTests = false
    elseif currentRule then
      local statusValue = rawLine:match("^%-%s*[Ss]tatus:%s*(.-)%s*$")
      if statusValue then
        currentRule.status = NormalizeStatus(statusValue)
        inRequiredTests = false
      else
        local summaryValue = rawLine:match("^%-%s*[Ss]ummary:%s*(.-)%s*$")
        if summaryValue == nil then
          summaryValue = rawLine:match("^%-%s*[Zz]usammenfassung:%s*(.-)%s*$")
        end
        if summaryValue == nil then
          summaryValue = rawLine:match("^%-%s*[Bb]eschreibung:%s*(.-)%s*$")
        end
        if summaryValue ~= nil then
          local normalizedSummary = Trim(summaryValue)
          if normalizedSummary ~= "" then
            currentRule.summary = normalizedSummary
          end
          inRequiredTests = false
        elseif
          rawLine:match("^%-%s*[Rr]equired Tests:%s*$")
          or rawLine:match("^%-%s*[Ee]rforderliche Tests:%s*$")
          or rawLine:match("^%-%s*[Pp]flichttests:%s*$")
        then
          inRequiredTests = true
        elseif inRequiredTests then
          local nestedTest = rawLine:match("^%s+%-%s+(.+)$")
          if nestedTest then
            local normalizedTest = NormalizeTestReference(nestedTest)
            if normalizedTest ~= "" then
              table.insert(currentRule.requiredTests, normalizedTest)
            end
          elseif not rawLine:match("^%s*$") then
            inRequiredTests = false
          end
        end
      end
    end
  end

  file:close()
  PushCurrentRule()

  if #rules == 0 then
    table.insert(warnings, string.format("rules: no rule blocks found in %s (add headings like '### RULE-ID').", path))
  end

  return rules, errors, warnings
end

local function CollectDeterministicTests(scenarioFiles)
  local testsByName = {}
  local errors = {}

  for _, scenarioPath in ipairs(scenarioFiles) do
    local scenarioFile, openErr = io.open(scenarioPath, "rb")
    if not scenarioFile then
      table.insert(
        errors,
        string.format("rules: cannot read scenario file %s: %s", tostring(scenarioPath), tostring(openErr))
      )
    else
      local lineNumber = 0
      for line in scenarioFile:lines() do
        lineNumber = lineNumber + 1
        local testName = line:match('^%s*test%(%s*"(.-)"%s*,')
        if not testName then
          testName = line:match("^%s*test%(%s*'(.-)'%s*,")
        end
        if testName and testName ~= "" then
          if testsByName[testName] then
            table.insert(
              errors,
              string.format(
                "rules: duplicate deterministic test name '%s' in %s:%d and %s:%d",
                testName,
                testsByName[testName].file,
                testsByName[testName].line,
                scenarioPath,
                lineNumber
              )
            )
          else
            testsByName[testName] = {
              file = scenarioPath,
              line = lineNumber,
            }
          end
        end
      end
      scenarioFile:close()
    end
  end

  return testsByName, errors
end

function Validator.Run(opts)
  opts = opts or {}
  local rulesPath = opts.rulesPath or "RULES_LOGIC.md"
  local scenarioFiles = opts.scenarioFiles or {}
  local printFn = type(opts.printFn) == "function" and opts.printFn or print

  local errors = {}
  local warnings = {}

  if type(scenarioFiles) ~= "table" then
    table.insert(errors, "rules: scenarioFiles must be a table")
    scenarioFiles = {}
  end

  local testsByName, testErrors = CollectDeterministicTests(scenarioFiles)
  for _, err in ipairs(testErrors) do
    table.insert(errors, err)
  end

  local rules, parseErrors, parseWarnings = ParseRulesFile(rulesPath)
  for _, err in ipairs(parseErrors) do
    table.insert(errors, err)
  end
  for _, warning in ipairs(parseWarnings) do
    table.insert(warnings, warning)
  end

  local activeCount = 0
  local draftCount = 0
  local deprecatedCount = 0
  local disabledCount = 0
  local seenRuleIDs = {}
  local seenSummarySignatures = {}

  if type(rules) == "table" then
    for _, rule in ipairs(rules) do
      local normalizedID = string.upper(Trim(rule.id))
      if normalizedID == "" then
        table.insert(errors, string.format("%s:%d rule id must not be empty", rulesPath, tonumber(rule.line) or 0))
      else
        local previousLine = seenRuleIDs[normalizedID]
        if previousLine then
          table.insert(
            errors,
            string.format(
              "%s:%d duplicate rule id '%s' (already declared at line %d)",
              rulesPath,
              tonumber(rule.line) or 0,
              rule.id,
              previousLine
            )
          )
        else
          seenRuleIDs[normalizedID] = tonumber(rule.line) or 0
        end
      end

      if not VALID_STATUSES[rule.status] then
        table.insert(
          errors,
          string.format(
            "%s:%d rule %s has invalid status '%s' "
              .. "(allowed: active|draft|deprecated|disabled; "
              .. "de: aktiv|entwurf|veraltet|deaktiviert)",
            rulesPath,
            tonumber(rule.line) or 0,
            tostring(rule.id),
            tostring(rule.status)
          )
        )
      elseif rule.status == "active" then
        activeCount = activeCount + 1
      elseif rule.status == "draft" then
        draftCount = draftCount + 1
      elseif rule.status == "deprecated" then
        deprecatedCount = deprecatedCount + 1
      elseif rule.status == "disabled" then
        disabledCount = disabledCount + 1
      end

      local summaryText = Trim(rule.summary or "")
      if summaryText ~= "" then
        local summarySignature = NormalizeSummarySignature(summaryText)
        local previousSummary = seenSummarySignatures[summarySignature]
        if previousSummary then
          table.insert(
            warnings,
            string.format(
              "%s:%d rule %s has duplicate summary text as %s:%d (%s)",
              rulesPath,
              tonumber(rule.line) or 0,
              tostring(rule.id),
              rulesPath,
              tonumber(previousSummary.line) or 0,
              tostring(previousSummary.id)
            )
          )
        else
          seenSummarySignatures[summarySignature] = {
            id = tostring(rule.id),
            line = tonumber(rule.line) or 0,
          }
        end
      end

      if rule.status == "active" then
        if summaryText == "" then
          table.insert(
            errors,
            string.format(
              "%s:%d active rule %s requires a non-empty Summary/Zusammenfassung field",
              rulesPath,
              tonumber(rule.line) or 0,
              tostring(rule.id)
            )
          )
        end

        if type(rule.requiredTests) ~= "table" or #rule.requiredTests == 0 then
          table.insert(
            errors,
            string.format(
              "%s:%d active rule %s requires at least one Required Tests/Erforderliche Tests entry",
              rulesPath,
              tonumber(rule.line) or 0,
              tostring(rule.id)
            )
          )
        else
          local seenRuleTests = {}
          for _, testName in ipairs(rule.requiredTests) do
            local normalizedTestName = NormalizeTestReference(testName)
            if normalizedTestName == "" then
              table.insert(
                errors,
                string.format(
                  "%s:%d active rule %s has an empty Required Tests/Erforderliche Tests entry",
                  rulesPath,
                  tonumber(rule.line) or 0,
                  tostring(rule.id)
                )
              )
            else
              if seenRuleTests[normalizedTestName] then
                table.insert(
                  warnings,
                  string.format(
                    "%s:%d active rule %s references duplicate test '%s'",
                    rulesPath,
                    tonumber(rule.line) or 0,
                    tostring(rule.id),
                    normalizedTestName
                  )
                )
              end
              seenRuleTests[normalizedTestName] = true

              if not testsByName[normalizedTestName] then
                table.insert(
                  errors,
                  string.format(
                    "%s:%d active rule %s references unknown deterministic test '%s'",
                    rulesPath,
                    tonumber(rule.line) or 0,
                    tostring(rule.id),
                    normalizedTestName
                  )
                )
              end
            end
          end
        end
      end
    end
  end

  local indexedTests = 0
  for _ in pairs(testsByName) do
    indexedTests = indexedTests + 1
  end

  if activeCount == 0 then
    table.insert(
      warnings,
      "rules: no active rules configured; set Status: active (or aktiv) on rule blocks to enforce runtime contracts."
    )
  end

  printFn(
    string.format(
      "Rules logic validation: %d rules (%d active, %d draft, %d deprecated, %d disabled) "
        .. "| %d deterministic tests indexed",
      type(rules) == "table" and #rules or 0,
      activeCount,
      draftCount,
      deprecatedCount,
      disabledCount,
      indexedTests
    )
  )

  for _, warning in ipairs(warnings) do
    printFn("[WARN] " .. warning)
  end

  if #errors > 0 then
    printFn("Rules logic validation failed:")
    for _, err in ipairs(errors) do
      printFn("[FAIL] " .. err)
    end
    return false
  end

  printFn("Rules logic validation passed.")
  return true
end

return Validator
