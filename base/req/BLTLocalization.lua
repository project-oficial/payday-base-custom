---@class BLTLocalization : BLTModule
---@field new fun(self):BLTLocalization
BLTLocalization = BLTLocalization or blt_class(BLTModule)
BLTLocalization.__type = "BLTLocalization"
BLTLocalization.default_language_code = "en"
BLTLocalization.directory = "project/base/loc/"

function BLTLocalization:init()
	BLTLocalization.super.init(self)

	self._languages = {}
	self._current = "en"
end

function BLTLocalization:_init_legacy_support()
	-- Add legacy support, otherwise lots of mods will crash on start-up immediately
	LuaModManager = LuaModManager or {}

	-- Insert language codes into the _languages table
	LuaModManager._languages = {}
	for _, lang in ipairs(self._languages) do
		table.insert(LuaModManager._languages, lang.language)
	end

	-- Create helper functions
	LuaModManager.GetLanguageIndex = function(lmm)
		local lang, idx = self:_get_language_from_code(self._current)
		return idx
	end

	LuaModManager.GetIndexOfDefaultLanguage = function(lmm)
		local lang, idx = self:_get_language_from_code(self.default_language_code)
		return idx
	end
end

function BLTLocalization:load_languages()
	-- Clear languages
	self._languages = {}

	-- Add all localisation files
	local loc_files = file.GetFiles(self.directory)
	for i, file_name in ipairs(loc_files) do
		local data = {
			file = Application:nice_path(self.directory .. file_name, false),
			language = string.gsub(file_name, ".txt", "")
		}
		table.insert(self._languages, data)
	end

	-- Sort languages alphabetically by code to ensure we always have the same order
	table.sort(self._languages, function(a, b)
		if a.language == self.default_language_code then
			return true
		end
		if b.language == self.default_language_code then
			return false
		end
		return a.language < b.language
	end)

	-- Load legacy support
	self:_init_legacy_support()

	self._languages_loaded = true

	local lang_code = BLT.save_data.language
	if lang_code then
		self:set_language(lang_code)
	end
end

function BLTLocalization:languages()
	return self._languages
end

function BLTLocalization:_get_language_from_code(lang_code)
	for idx, lang in ipairs(self._languages) do
		if lang.language == lang_code then
			return lang, idx
		end
	end
end

function BLTLocalization:get_language()
	return self:_get_language_from_code(self._current)
end

function BLTLocalization:set_language(lang_code)
	if not self._languages_loaded then
		return false
	end

	local lang = self:_get_language_from_code(lang_code)
	if lang then
		self._current = lang.language
		return true
	else
		return false
	end
end

function BLTLocalization:load_localization(loc_manager)
	local localization_manager = loc_manager or managers.localization
	if not localization_manager then
		BLT:Log(LogLevel.ERROR, "Can not load localization without a valid localization manager!")
		return false
	end

	local default_lang = self:_get_language_from_code(self.default_language_code)
	if default_lang then
		localization_manager:load_localization_file(default_lang.file)
	else
		BLT:Log(LogLevel.ERROR, "Could not load localization file for language: " .. tostring(self.default_language_code))
	end

	local lang = self:get_language()
	if lang then
		if lang.language ~= self.default_language_code then
			localization_manager:load_localization_file(lang.file)
		end
	else
		BLT:Log(LogLevel.ERROR, "Could not load localization file for language: " .. tostring(self._current))
	end
end

Hooks:Add("BLTOnSaveData", "BLTOnSaveData.BLTLocalization", function(save_data)
	local lang = BLT.Localization:get_language()
	if lang then
		save_data.language = lang.language
	end
end)

--------------------------------------------------------------------------------
-- Load languages once the game's localization manager has been created

Hooks:Add("LocalizationManagerPostInit", "BLTLocalization.LocalizationManagerPostInit", function(loc_manager)
	BLT.Localization:load_languages()
	BLT.Localization:load_localization(loc_manager)
end)
