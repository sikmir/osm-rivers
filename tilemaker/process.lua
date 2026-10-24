-- River relations (type=waterway, waterway=river) as multilinestrings

function relation_scan_function()
	if Find("type") == "waterway" and Find("waterway") == "river" then
		Accept()
	end
end

function relation_function()
	Layer("rivers", false)
	AttributeNumeric("id", tonumber(Id()))
	local name = Find("name")
	if name ~= "" then
		Attribute("name", name)
	end
end

function way_function()
end
