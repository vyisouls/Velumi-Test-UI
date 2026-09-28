--[[
	Test entry point for Lune (https://lune-org.github.io/docs).

	    lune run tests/run

	Loads the mock engine, runs tests/suite.luau against the real source
	in src/ and examples/, and exits non-zero on failure.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local host = {}

function host.readfile(path: string): string?
	if fs.isFile(path) then
		return fs.readFile(path)
	end
	return nil
end

function host.listdir(path: string): { string }
	local entries = fs.readDir(path)
	table.sort(entries)
	return entries
end

function host.loadchunk(source: string, name: string, env: any?)
	local ok, result = pcall(luau.load, source, {
		debugName = name,
		environment = env,
	})
	if not ok then
		return nil, tostring(result)
	end
	return result
end

local function load(path: string, env: any?)
	local source = assert(host.readfile(path), "missing " .. path)
	local chunk = assert(host.loadchunk(source, path, env))
	return chunk()
end

local Mock = load("tests/mock/Roblox.luau")
Mock.setHost(host)

local suite = load("tests/suite.luau")
local failures = suite(Mock, host, load)
process.exit(if failures > 0 then 1 else 0)
