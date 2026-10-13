-- Запуск тестов ядра вне движка: luajit tests/run.lua (из корня проекта).
-- Каждый файл tests/**/*_test.lua возвращает таблицу: имя теста -> function(t).

local is_windows = package.config:sub(1, 1) == "\\"

package.path = "./?.lua;./?/init.lua;" .. package.path

local assertions = {}

function assertions.equal(actual, expected, msg)
	if actual ~= expected then
		error(string.format("%s: ожидалось %s, получено %s",
			msg or "equal", tostring(expected), tostring(actual)), 2)
	end
end

function assertions.true_(cond, msg)
	if not cond then
		error(msg or "ожидалось true", 2)
	end
end

function assertions.error_(fn, msg)
	local ok = pcall(fn)
	if ok then
		error(msg or "ожидалась ошибка", 2)
	end
end

local function list_test_files()
	local cmd
	if is_windows then
		cmd = 'dir /b /s /a-d "tests\\*_test.lua" 2>nul'
	else
		cmd = "find tests -name '*_test.lua' 2>/dev/null"
	end
	local pipe = assert(io.popen(cmd), "не удалось перечислить тесты")
	local files = {}
	for line in pipe:lines() do
		line = line:gsub("\\", "/")
		if line:match("_test%.lua$") then
			table.insert(files, line)
		end
	end
	pipe:close()
	table.sort(files)
	return files
end

local function module_name(path)
	local rel = path:gsub("^.*/tests/", "tests/")
	return (rel:gsub("%.lua$", ""):gsub("/", "."))
end

local passed, failed = 0, 0
local failures = {}

for _, file in ipairs(list_test_files()) do
	local ok, tests = pcall(dofile, file)
	if not ok then
		failed = failed + 1
		table.insert(failures, string.format("%s: ошибка загрузки: %s", file, tostring(tests)))
	else
		local names = {}
		for name in pairs(tests) do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in ipairs(names) do
			local ok_test, err = pcall(tests[name], assertions)
			if ok_test then
				passed = passed + 1
			else
				failed = failed + 1
				table.insert(failures, string.format("%s :: %s\n    %s", file, name, tostring(err)))
			end
		end
	end
end

for _, msg in ipairs(failures) do
	print("FAIL " .. msg)
end
print(string.format("\nпройдено: %d, упало: %d", passed, failed))

os.exit(failed == 0 and 0 or 1)
