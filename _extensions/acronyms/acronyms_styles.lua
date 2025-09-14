--[[

    This file defines the "styles" to replace acronyms.

    Such styles control how to use the acronym's short name,
    long name, whether one should be between parentheses, etc.

    Styles are largely inspired from the LaTeX package "glossaries"
    (and "glossaries-extra").
    A gallery of the their styles can be found at:
    https://www.dickimaw-books.com/gallery/index.php?label=sample-abbr-styles
    A more complete document (rather long) can be found at:
    https://mirrors.chevalier.io/CTAN/macros/latex/contrib/glossaries-extra/samples/sample-abbr-styles.pdf

    More specifically, this file defines a table of functions.
    Each function takes an acronym, and return one or several Pandoc elements.
    These elements will replace the original acronym call in the Markdown 
    document.

    Most styles will depend on whether this is the acronym's first occurrence,
    ("first use") or not ("next use"), similarly to the LaTeX "glossaries".

    For example, a simple (default) style can be to return the acronym's
    long name, followed by the short name between parentheses.
    When the parser encounters `\acr{RL}`, assuming that `RL` is correctly
    defined in the acronyms database, the corresponding function would 
    return a Pandoc Link, where the text is "Reinforcement Learning (RL)",
    and pointing to the definition of "RL" in the List of Acronyms.
    
    Note: the acronym's key MUST exist in the acronyms database.
    Functions to replace a non-existing key must be handled elsewhere.

--]]

local Helpers = require("acronyms_helpers")


local function capitalize_first(s)
  return (s:gsub("^%l", string.upper))
end

-- The table containing all styles, indexed by the style's name.
local styles = {}


-- Local helper function to create either a Str or a Link,
-- depending on whether we want to insert links.
local function ensure_inlines(obj)
    if type(obj) == "string" then return { pandoc.Str(obj) } end
    if pandoc and pandoc.utils and pandoc.utils.type then
        local t = pandoc.utils.type(obj)
        if t == "Inlines" then
            local arr = {}
            for i = 1, #obj do arr[#arr+1] = obj[i] end
            return arr
        elseif t == "List" then
            local ok = true
            for i = 1, #obj do
                local v = obj[i]
                if type(v) ~= "table" or v.t == nil then ok = false break end
            end
            if ok then
                local arr = {}
                for i = 1, #obj do arr[#arr+1] = obj[i] end
                return arr
            end
        end
    end
    if type(obj) == "table" and obj.t ~= nil then
        return { obj }
    end
    if type(obj) == "table" then
        local ok = true
        for _, v in ipairs(obj) do if type(v) ~= "table" or v.t == nil then ok = false break end end
        if ok then return obj end
    end
    return { pandoc.Str(pandoc.utils and pandoc.utils.stringify and pandoc.utils.stringify(obj) or tostring(obj)) }
end

-- Enhanced element creator (new logic) able to preserve existing rich inline
-- structures (Emph, Strong, etc.). Internal code now uses this.
local function create_rich_element(content, key, insert_links, is_longname)
    local inlines = ensure_inlines(content)
    if insert_links then
        return pandoc.Link(inlines, Helpers.key_to_link(key))
    else
        if #inlines == 1 then return inlines[1] else return inlines end
    end
end

-- Legacy create_element (unchanged original behavior): takes raw string content
-- and returns either a Link (with the content as inlines) or a Str.
local function create_element(content, key, insert_links)
    if insert_links then
        return pandoc.Link(content, Helpers.key_to_link(key))
    else
        return pandoc.Str(content)
    end
end


-- First use: long name (short name)
-- Next use: short name
styles["long-short"] = function(acronym, insert_links, is_first_use)
    if is_first_use then
    local longname_elem = ensure_inlines(acronym.longname)
    local shortname_elem = ensure_inlines(acronym.shortname)
        local all = {}
        for _, v in ipairs(longname_elem) do table.insert(all, v) end
        table.insert(all, pandoc.Str(" ("))
        for _, v in ipairs(shortname_elem) do table.insert(all, v) end
        table.insert(all, pandoc.Str(")"))
        if insert_links then
            return { pandoc.Link(all, Helpers.key_to_link(acronym.key)) }
        else
            return all
        end
    else
    local elem = create_rich_element(acronym.shortname, acronym.key, insert_links, false)
        if type(elem) == "table" then return elem else return {elem} end
    end
end


-- First use: short name (long name)
-- Next use: short name
styles["short-long"] = function(acronym, insert_links, is_first_use)
    if is_first_use then
    local shortname_elem = ensure_inlines(acronym.shortname)
        local longname_elem = ensure_inlines(acronym.longname)
        local all = {}
        for _, v in ipairs(shortname_elem) do table.insert(all, v) end
        table.insert(all, pandoc.Str(" ("))
        for _, v in ipairs(longname_elem) do table.insert(all, v) end
        table.insert(all, pandoc.Str(")"))
        if insert_links then
            return { pandoc.Link(all, Helpers.key_to_link(acronym.key)) }
        else
            return all
        end
    else
        local elem = create_element(acronym.shortname, acronym.key, insert_links, false)
        if type(elem) == "table" then return elem else return {elem} end
    end
end

-- First use: long name
-- Next use: long name
styles["long-long"] = function(acronym, insert_links)
    local elem = create_rich_element(acronym.longname, acronym.key, insert_links, true)
    if type(elem) == "table" then return elem else return {elem} end
end

-- First use: short name [^1]
-- [^1]: short name: long name
-- Next use: short name
styles["short-footnote"] = function(acronym, insert_links, is_first_use)
    if is_first_use then
        -- Main text: plain shortname (no link)
        local text = pandoc.Str(acronym.shortname)
        -- Footnote: [shortname](link): longname
        local shortname_link = create_element(acronym.shortname, acronym.key, insert_links, false)
        local longname_elem = ensure_inlines(acronym.longname)
        local plain = {}
        if type(shortname_link) == "table" then for _, v in ipairs(shortname_link) do table.insert(plain, v) end else table.insert(plain, shortname_link) end
        table.insert(plain, pandoc.Str(": "))
        for _, v in ipairs(longname_elem) do table.insert(plain, v) end
        local note = pandoc.Note(pandoc.Plain(plain))
        return { text, note }
    else
    local elem = create_rich_element(acronym.shortname, acronym.key, insert_links, false)
        if type(elem) == "table" then return elem else return {elem} end
    end
end


-- The "public" API of this module, the function which is returned by
-- require.
return function(acronym, style_name, insert_links, is_first_use, plural, 
    case_target, case)
    -- Check that the requested strategy exists
    assert(style_name ~= nil,
        "[acronyms] The parameter style_name must not be nil!")
    assert(styles[style_name] ~= nil,
        "[acronyms] Style " .. tostring(style_name) .. " does not exist!")

    -- Check that the acronym exists
    assert(acronym ~= nil,
        "[acronyms] The acronym must not be nil!")

    -- Determine if it is the first use (if left unspecified)
    if is_first_use == nil then
        is_first_use = acronym:isFirstUse()
    end

    -- Transform this acronym prior to rendering
    -- e.g., for plural form; and for sentence case
    acronym = acronym:clone()
    if plural then
        -- Conditional strictness: if markdown parsing is enabled for a part, require an explicit plural for that part.
        local need_long_strict = acronym._parse_markdown_longname and not acronym._explicit_plural_longname
        local need_short_strict = acronym._parse_markdown_shortname and not acronym._explicit_plural_shortname
        if need_long_strict then
            quarto.log.error("[acronyms] Plural form requested for '" .. tostring(acronym.key) .. "' but 'plural.longname' was not explicitly provided while markdown parsing is enabled for its longname. Define it under plural: { longname: ... } to use \\acrs{" .. tostring(acronym.key) .. "} .")
            assert(false)
        end
        if need_short_strict then
            quarto.log.error("[acronyms] Plural form requested for '" .. tostring(acronym.key) .. "' but 'plural.shortname' was not explicitly provided while markdown parsing is enabled for its shortname. Define it under plural: { shortname: ... } to use \\acrs{" .. tostring(acronym.key) .. "} .")
            assert(false)
        end
        -- Apply plural forms (explicit provided parts already present; fallbacks safe for non-markdown components).
        acronym.shortname = acronym.plural.shortname
        acronym.longname = acronym.plural.longname
    end

    -- Functional case transformation that preserves inline formatting.
    local function transform_case(value, case_kind)
        -- String values
        if type(value) == "string" then
            if case_kind == "upper" then return value:upper()
            elseif case_kind == "lower" then return value:lower()
            elseif case_kind == "sentence" then return capitalize_first(value)
            else return value end
        end

        -- Detect a list/array of inline nodes even if it's a plain Lua table
        local function is_inline_array(tbl)
            if type(tbl) ~= "table" then return false end
            -- Quick check: all numeric indices contain tables with a .t tag
            for i, v in ipairs(tbl) do
                if type(v) ~= "table" or v.t == nil then return false end
            end
            return #tbl > 0
        end

        if not is_inline_array(value) then
            -- Maybe it's a Pandoc list-like object
            if pandoc.utils and pandoc.utils.type then
                local t = pandoc.utils.type(value)
                if t == "Inlines" or t == "List" then
                    -- acceptable – let code continue using value as array
                else
                    return value
                end
            else
                return value
            end
        end

        local done_first = false
        local simple_containers = {
            Emph=true, Strong=true, Span=true, Strikeout=true,
            SmallCaps=true, Superscript=true, Subscript=true, Underline=true
        }

        local function transform_inlines(src)
            local dest = {}
            for _, il in ipairs(src) do
                if il.t == "Str" and (il.text or il.c) then
                    local txt = il.text or il.c
                    if case_kind == "upper" then
                        txt = txt:upper()
                    elseif case_kind == "lower" then
                        txt = txt:lower()
                    elseif case_kind == "sentence" and not done_first then
                        local i = txt:find("%a")
                        if i then
                            txt = txt:sub(1,i-1)..txt:sub(i,i):upper()..txt:sub(i+1)
                            done_first = true
                        end
                    end
                    dest[#dest+1] = pandoc.Str(txt)
                elseif simple_containers[il.t] and type(il.c) == "table" then
                    local inner = transform_inlines(il.c)
                    if il.t == "Span" then
                        dest[#dest+1] = pandoc.Span(inner, il.attr)
                    else
                        local ctor = pandoc[il.t]
                        if ctor then
                            dest[#dest+1] = ctor(inner)
                        else
                            local copy = {}
                            for k, v in pairs(il) do copy[k] = v end
                            copy.c = inner
                            dest[#dest+1] = copy
                        end
                    end
                else
                    dest[#dest+1] = il
                end
            end
            return dest
        end

        return transform_inlines(value)
    end

    if case == "upper" or case == "lower" or case == "sentence" then
        if case_target == "short" or case_target == "both" then
            acronym.shortname = transform_case(acronym.shortname, case)
        end
        if case_target == "long" or case_target == "both" then
            acronym.longname = transform_case(acronym.longname, case)
        end
    end

    local rendered = styles[style_name](acronym, insert_links, is_first_use, case_target)
    return rendered
end
