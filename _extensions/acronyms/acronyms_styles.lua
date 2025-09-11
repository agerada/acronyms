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
    -- String -> single Str
    if type(obj) == "string" then return { pandoc.Str(obj) } end
    -- Pandoc Inlines userdata
    if pandoc and pandoc.utils and pandoc.utils.type and pandoc.utils.type(obj) == "Inlines" then
        local arr = {}
        for i = 1, #obj do arr[#arr+1] = obj[i] end
        return arr
    end
    -- Single inline element (table with .t)
    if type(obj) == "table" and obj.t ~= nil then
        return { obj }
    end
    -- Array of inline elements?
    if type(obj) == "table" then
        local ok = true
        for _, v in ipairs(obj) do if type(v) ~= "table" or v.t == nil then ok = false break end end
        if ok then return obj end
    end
    -- Fallback: stringify
    return { pandoc.Str(pandoc.utils and pandoc.utils.stringify and pandoc.utils.stringify(obj) or tostring(obj)) }
end

local function create_element(content, key, insert_links, is_longname)
    local inlines = ensure_inlines(content)

    if insert_links then
        -- pandoc.Link expects a list of inlines as first argument
        return pandoc.Link(inlines, Helpers.key_to_link(key))
    else
        if #inlines == 1 then
            return inlines[1]
        else
            return inlines
        end
    end
end


-- First use: long name (short name)
-- Next use: short name
styles["long-short"] = function(acronym, insert_links, is_first_use)
    if is_first_use then
        local longname_elem = create_element(acronym.longname, acronym.key, insert_links, true)
        local shortname_elem = create_element(acronym.shortname, acronym.key, insert_links, false)
        local result = {}
        if type(longname_elem) == "table" then for _, v in ipairs(longname_elem) do table.insert(result, v) end else table.insert(result, longname_elem) end
        table.insert(result, pandoc.Str(" ("))
        if type(shortname_elem) == "table" then for _, v in ipairs(shortname_elem) do table.insert(result, v) end else table.insert(result, shortname_elem) end
        table.insert(result, pandoc.Str(")"))
        return result
    else
        local elem = create_element(acronym.shortname, acronym.key, insert_links, false)
        if type(elem) == "table" then return elem else return {elem} end
    end
end


-- First use: short name (long name)
-- Next use: short name
styles["short-long"] = function(acronym, insert_links, is_first_use)
    if is_first_use then
        local shortname_elem = create_element(acronym.shortname, acronym.key, insert_links, false)
        local longname_elem = create_element(acronym.longname, acronym.key, insert_links, true)
        local result = {}
        if type(shortname_elem) == "table" then for _, v in ipairs(shortname_elem) do table.insert(result, v) end else table.insert(result, shortname_elem) end
        table.insert(result, pandoc.Str(" ("))
        if type(longname_elem) == "table" then for _, v in ipairs(longname_elem) do table.insert(result, v) end else table.insert(result, longname_elem) end
        table.insert(result, pandoc.Str(")"))
        return result
    else
        local elem = create_element(acronym.shortname, acronym.key, insert_links, false)
        if type(elem) == "table" then return elem else return {elem} end
    end
end

-- First use: long name
-- Next use: long name
styles["long-long"] = function(acronym, insert_links)
    local elem = create_element(acronym.longname, acronym.key, insert_links, true)
    if type(elem) == "table" then return elem else return {elem} end
end

-- First use: short name [^1]
-- [^1]: short name: long name
-- Next use: short name
styles["short-footnote"] = function(acronym, insert_links, is_first_use)
    if is_first_use then
        local text = pandoc.Str(acronym.shortname)
        local longname_elem = create_element(acronym.longname, acronym.key, insert_links, true)
        local shortname_elem = create_element(acronym.shortname, acronym.key, insert_links, false)
        local plain = {}
        if type(shortname_elem) == "table" then for _, v in ipairs(shortname_elem) do table.insert(plain, v) end else table.insert(plain, shortname_elem) end
        table.insert(plain, pandoc.Str(": "))
        if type(longname_elem) == "table" then for _, v in ipairs(longname_elem) do table.insert(plain, v) end else table.insert(plain, longname_elem) end
        local note = pandoc.Note(pandoc.Plain(plain))
        return { text, note }
    else
        local elem = create_element(acronym.shortname, acronym.key, insert_links, false)
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
        acronym.shortname = acronym.plural.shortname
        acronym.longname = acronym.plural.longname
    end

    local function map_longname(transform)
        if pandoc.utils.type and pandoc.utils.type(acronym.longname) == "Inlines" then
            local txt = pandoc.utils.stringify(acronym.longname)
            return transform(txt)
        else
            return transform(acronym.longname)
        end
    end

    if case == "upper" then
        if case_target == "short" or case_target == "both" then
            acronym.shortname = string.upper(acronym.shortname)
        end
        if case_target == "long" or case_target == "both" then
            acronym.longname = map_longname(string.upper)
        end
    elseif case == "lower" then
        if case_target == "short" or case_target == "both" then
            acronym.shortname = string.lower(acronym.shortname)
        end
        if case_target == "long" or case_target == "both" then
            acronym.longname = map_longname(string.lower)
        end
    elseif case == "sentence" then
        if case_target == "short" or case_target == "both" then
            acronym.shortname = capitalize_first(acronym.shortname)
        end
        if case_target == "long" or case_target == "both" then
            acronym.longname = map_longname(capitalize_first)
        end
    end

    -- Call the style on this acronym
    local rendered = styles[style_name](acronym, insert_links, is_first_use, case_target)
    return rendered
end
