--[[

This file defines a few helper functions, in particular with respect to pandoc.

--]]

local Options = require("acronyms_options")


local Helpers = {}


-- Helper function to determine pandoc's version.
-- `version` must be a table of numbers, e.g., `{2, 17, 0, 1}`
function Helpers.isAtLeastVersion(version)
    -- `PANDOC_VERSION` exists since 2.1, but we never know...
    if PANDOC_VERSION == nil then
        return false
    end
    -- Loop up over the components
    -- e.g., `2.17.0.1` => [0]=2, [1]=17, [2]=0, [3]=1
    for k, v in ipairs(version) do
        if PANDOC_VERSION[k] == nil or PANDOC_VERSION[k] < version[k] then
            -- Examples: 2.17 < 2.17.0.1, or 2.16 < 2.17
            return false
        elseif PANDOC_VERSION[k] > version[k] then
            -- Example: 2.17 > 2.16.2 (we do not need to check the next!)
            return true
        end
    end
    -- At this point, all components are equal
    return true
end


-- Helper function to determine whether a metadata field is a list.
function Helpers.isMetaList(field)
    -- We want to know whether we have multiple values (MetaList).
    -- Pandoc 2.17 introduced a compatibility-breaking change for this:
    --  the `.tag` is no longer present in >= 2.17 ;
    --  the `pandoc.utils.type` function is only available in >= 2.17
    if Helpers.isAtLeastVersion({2, 17}) then
        -- Use the new `pandoc.utils.type` function
        return pandoc.utils.type(field) == "List"
    else
        -- Use the (old) `.tag` type attribute
        return field.t == "MetaList"
    end
end


-- Helper function to generate the ID (identifier) from an acronym key.
-- The ID can be used for, e.g., links.
function Helpers.key_to_id(key)
    -- Sanitize the key, i.e., replace non-ASCII characters with `-`
    local sanitized_key = string.gsub(key, "[^0-9A-Za-z]", "_")
    return Options["id_prefix"] .. sanitized_key
end


-- Similar helper but for the link itself (based on the ID).
function Helpers.key_to_link(key)
    return "#" .. Helpers.key_to_id(key)
end


-- Helper to print a Pandoc Metadata.
-- From a metadata (e.g., a YAML map), it returns a table-like string:
-- `{ key1: value1 ; key2: value2 ; ... }`.
function Helpers.metadata_to_str(metadata)
    -- We need to reformat a bit the table
    local t = {}
    for k, v in pairs(metadata) do
        table.insert(t, k .. ": " .. pandoc.utils.stringify(v))
    end
    return "{ " .. table.concat(t, " ; ") .. " }"
end


-- Helper to convert a (case-insensitive) string to a boolean
-- Recognized values: `true`, `false`, `yes`, `no`, `y`, `n`
function Helpers.str_to_boolean(value)
    if type(value) == "boolean" then
        return value
    end

    local converts = {
        ["true"] = true,
        ["false"] = false,
        ["yes"] = true,
        ["no"] = false,
        ["y"] = true,
        ["n"] = false,
    }
    local result = converts[string.lower(value)]
    if result == nil then
        quarto.log.warning(
            "[acronyms] Could not convert string to boolean, unrecognized value:",
            value,
            " ! Assuming `false`."
        )
        result = false
    end
    return result
end

-- Parse limited markdown snippet (currently for italics etc.) using pandoc.read for robustness
-- Returns list of Inlines
function Helpers.parse_markdown_snippet(text)
    local doc = pandoc.read(tostring(text) .. "\n", "markdown")
    local blocks = doc.blocks
    local inlines = {}
    for _, b in ipairs(blocks) do
        if b.t == "Para" or b.t == "Plain" then
            for _, il in ipairs(b.c) do table.insert(inlines, il) end
        end
    end
    return inlines
end

-- Normalize a value (string or Pandoc Inlines/list) to a plain string.
-- If v is an Inlines object (or a plain Lua array of inline nodes), we
-- stringify it using pandoc.utils.stringify; otherwise fallback to tostring.
function Helpers.inlines_to_string(v)
    if pandoc and pandoc.utils and pandoc.utils.type then
        local t = pandoc.utils.type(v)
        if t == "Inlines" then
            return pandoc.utils.stringify(v)
        elseif t == "List" then
            -- Heuristic: list whose elements are inline nodes (tables w/ .t)
            local is_inlines = true
            for _, il in ipairs(v) do
                if type(il) ~= "table" or il.t == nil then
                    is_inlines = false; break
                end
            end
            if is_inlines then
                return pandoc.utils.stringify(pandoc.Inlines(v))
            end
        end
    end
    return tostring(v)
end

-- Extract a metadata field (shortname/longname or plural variants) as either
-- raw Inlines (array) when parse_markdown is true and the field is MetaInlines/Inlines,
-- or as a plain string otherwise. Returns nil if the input is nil.
function Helpers.extract_meta_field(field, parse_markdown)
    if field == nil then return nil end
    if parse_markdown then
        local ptype = pandoc.utils.type and pandoc.utils.type(field)
        if ptype == "Inlines" or (type(field) == "table" and field.t == "MetaInlines") then
            if ptype == "Inlines" then
                return field
            else
                local arr = {}
                for i=1,#field do arr[#arr+1] = field[i] end
                return arr
            end
        else
            return pandoc.utils.stringify(field)
        end
    else
        return pandoc.utils.stringify(field)
    end
end

return Helpers
