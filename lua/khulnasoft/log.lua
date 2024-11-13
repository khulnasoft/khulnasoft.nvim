local p_debug = vim.env.DEBUG_KHULNASOFT

return require("plenary.log").new({
	plugin = "khulnasoft/khulnasoft",
	level = p_debug or "info",
})
