-----------------------------------------------------------------------------------------------
-- Client Lua Script for VooProto
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- VooProto Module Definition
-----------------------------------------------------------------------------------------------
local VooProto = {} 

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")

local tinsert,tremove,min,max,type = table.insert,table.remove,math.min,math.max,type

local MAX_LINES = 36
local LINE_HEIGHT = 20
local HEIGHT = MAX_LINES*LINE_HEIGHT
local WIDTH = 500
local GTableSize = 10000

local COLORS={
	string="ffff8800",
	number="ff00aaff",
	["function"]="ffff00aa",
	table="ffffff00",
	["nil"]="ff888888",
	userdata="ff4444ff",
	boolean="ffff0000",
	error="ffff0000",
	blacklist="ff888888",
	__index="ffffffff"
}
setmetatable(COLORS,COLORS)

local safepairs = pairs

SPECIAL_FUNC_CALLS = {
	["^GetBlablabla"] = function(fun,data)
		--if IsShiftKeyDown() then  data.params={"reticleover"} elseif IsCapsLockOn() then data.params={"mouseover"} else  data.params={"player"}  end
	end,
	getparams = function(self,name,data)
		for spatt,sfun in pairs(self) do
			if name:find(spatt) then  sfun(name,data)  end
		end
	end
}

--DEREF
	VOO_ADDRESS_LOOKUP={}
	local function get_addr(obj)
		if type(obj)=="function" or type(obj)=="table" then
			return tostring(obj):match(": ([%u%d]+)")
		end
	end

	function dereference(obj)
		return VOO_ADDRESS_LOOKUP[get_addr(obj) or ""]
	end

	-- startup
	local safe=100000
	local function grab_derefs(source,name,deep)
		for k,v in safepairs(source) do
			if type(v)=="function" or type(v)=="table" then
				local addr=get_addr(v)
				if addr and not VOO_ADDRESS_LOOKUP[addr] then
					VOO_ADDRESS_LOOKUP[addr]=(name and name.."." or "") .. k
					if deep and type(v)=="table" and k:find("^ZO_") then
						grab_derefs(v,k,false)
					end
				end
			end
		end
	end
	grab_derefs(_G,nil,true)


local BLACKLIST = {
	GetNamedChild="BLACKLISTED",
	--IsChildOf="BLACKLISTED",
	--GetAnchor="BLACKLISTED",
	GetChild="BLACKLISTED",
	GetClass="BLACKLISTED",
	GetHandler="BLACKLISTED",
	GetTradingHouseSearchResultItemInfo="CRASHES",
}
local function WhyBlacklisted(funcname)
	return BLACKLIST[funcname]
	--[[
	or (type(funcname)=="string" and
		((IsPrivateFunction(funcname) and "PRIVATE")
	 or(IsProtectedFunction(funcname) and "PROTECTED")
	 )
	)
	--]]
end


local function color(col,text)
	return string.format("<T TextColor=\"%s\">%s</T>", col, text)
end



local function getusermetatable(tab)
	local meta = getmetatable(tab)

	local index = meta.__index

	return index
end


local function downcasesort(a,b)
	if type(a.index)=="number" and type(b.index)=="number" then return a.index<b.index end
	if type(a.index)=="number" and type(b.index)~="number" then return true end
	if type(a.index)~="number" and type(b.index)=="number" then return false end
	return a.index and b.index and tostring(a.index) < tostring(b.index)
end


local function tablesize(tab)
	local size,metasize=0
	if type(tab)=="table" or type(tab)=="userdata" then
		if type(tab)=="userdata" then
			local saved = tab
			tab = getusermetatable(tab)

			--[[
			if not tab.A__Zgoo_GetChildren then
				tab.A__Zgoo_GetChildren = tab.A__Zgoo_GetChildren or function(self)
					local children = {}
					local numc = self:GetNumChildren()
					for i=1,numc do
						local c = self:GetChild(i)
						if c then
							children[i] = c
						end
					end
					return children
				end
			end
			--]]

			-- Lazy... Bring it to the top
			tab.A__Voo_ToggleHidden = tab.A__Voo_ToggleHidden or tab.ToggleHidden

		end

		for k in safepairs(tab) do size=size+1 end

		local meta = getmetatable(tab)
		if meta and meta.__index and type(meta.__index)=="table" then
			metasize = 0
			for k in pairs(meta.__index) do metasize=metasize+1 end
		end

		return #tab,size,metasize
	end
end


function pcallhelper(success, ...)
	if success then
		if select('#',...)<=1 then return success, ... else return success, {...} end
	else
		return success, ...
	end
end

function safeFunctionCallV(v,k,data,orig)
	local was_func
	local ok,err
	if type(v)=="function" and type(k)=="string"
	and not WhyBlacklisted(k)
	and Voo.CALL_FUNCTIONS
	and ((k:find("^Is")
		 or k:find("^Can[A-Z]")
		 or k:find("^Get[A-Z]")
		 or k:find("^Did[A-Z]")
		 or k:find("^Does[A-Z]")
		 or k:find("^Has[A-Z]")
		) and not k:find("By[A-Z]")) then

		if orig and orig[k] then
			ok,v = pcallhelper(pcall(orig[k],orig))
		elseif data then
			--if data and data._is_global then data=nil end
			ok,v = pcallhelper(pcall(v,data))
		else
			local tab={params={}}
			SPECIAL_FUNC_CALLS:getparams(k,tab)
			ok,v = pcallhelper(pcall(v,unpack(tab.params)))
		end

		if not ok then
			err=v
			v=nil
		end
		was_func=true
	end

	if k and WhyBlacklisted(k) then
		was_func=true
	end

	return v,was_func,err
end



VooProto.UiTypes = {
	[-1] = "CT_INVALID_TYPE",
	[0] = "CT_CONTROL",
	"CT_LABEL",
	"CT_DEBUGTEXT",
	"CT_TEXTURE",
	"CT_TOPLEVELCONTROL",
	"CT_ROOT_WINDOW",
	"CT_TEXTBUFFER",
	"CT_BUTTON",
	"CT_STATUSBAR",
	"CT_EDITBOX",
	"CT_COOLDOWN",
	"CT_TOOLTIP",
	"CT_SCROLL",
	"CT_SLIDER",
	"CT_BACKDROP",
	"CT_MAPDISPLAY",
	"CT_COLORSELECT",
	"CT_LINE",
	"CT_BROWSER",
	"CT_COMPASS",
}
setmetatable(VooProto.UiTypes,{__index = "NO_TYPE"})

function VooProto:FormatType(data,t,expandtable,index)
	local s
	t = t or type(data)
	
	if t=="string" then
		local len=#data
		data=data:gsub("\n","")
		data=data:gsub("\r","")
		data=data:gsub("|n","")
		data=data:gsub("\"","\\\"")
		data=data:sub(1,100)
		s=color(COLORS['string'],"\""..data.."\"")

		if len>100 then s=s.."... ("..len..")" end

	elseif t=="number" then
		s = ('%s'):format(tostring(data))
		s = color(COLORS['number'],s)

	elseif t=="nil" then
		s = color(COLORS['nil'],"nil")

	elseif t=="table" then
		local csize,size,metasize = tablesize(data)
		s = tostring(data) .. " " .. color("ffbb9900","["..
																	color("ffbb9900","#".. (csize or "?") .."," .. (size or "?") .. (metasize and ",+"..metasize or ""))
																	.."]")

		if not self.SHOW_ADDRESSES then s=s:gsub(": [0-9A-F]+","") end

		local derefname = dereference(data)
		if index and derefname and index~=derefname then  s = s .. " ".. color("ff6688ee","(global ".. color("ff88aaff",derefname))  end

		if expandtable then
			local nt={}
			local ntlimit=0
			for k,v in safepairs(data) do tinsert(nt,self:FormatType(v)) ntlimit=ntlimit+1 if ntlimit>=expandtable then break end end
			s = s .. " : " .. table.concat(nt,",")
		end

		s = color(COLORS['table'],s)

	elseif t=="function" then
		s = ('%s'):format(tostring(data):gsub("%[",""):gsub("%]",""))
		s = color(COLORS['function'],s)
		if not self.SHOW_ADDRESSES then s=s:gsub(": [0-9A-F]+","") end

	elseif t=="boolean" then
		s = color(COLORS['boolean'],tostring(data))

	elseif t=="userdata" then
		local csize,size,metasize = tablesize(data)	-- Just put our GetChildren and A_Toggle in the userdata.

		s = tostring(data) .. " " .. color("ff886600","["..
																	color("ffbb9900","#".. (csize or "?") .."," .. (size or "?") .. (metasize and ",+"..metasize or ""))
																	.."]")

	else
		s = ('%s'):format(tostring(data):gsub("%[",""):gsub("%]",""))
		if COLORS[t] then s = color(COLORS[t], s) end
	end

	--[[
	local objtype = t=="userdata" and type(data.GetType)=="function" and data:GetType() or nil
	if objtype then
		-- widget!
		local objname = t=="userdata" and type(data.GetName)=="function" and "\"|cff0000"..data:GetName().."|r\"" or "(anon)"
		s = "|r  < "..objname.." - |c00ffff"..((data.class and "Class-"..data.class) or self.UiTypes[objtype]).. " |r>"
	end
	--]]


	return s
end








function VooProto:Update()
	local frame = self.Frame
	self.offset = self.offset or 0
	if self.offset < 0 then self.offset = 0 end	-- offset can go negative someplace.... HACKED

	if not self.lines then return end

	for i=1,MAX_LINES do
		local line=self.framelines[i]

		if self.offset+i <= #self.lines then
			local dat = self.lines[self.offset+i]
			if not dat then break end	--??

			local v = dat.data

			local err

			v,was_func,err = safeFunctionCallV(v,dat.index,dat.parent)

			local s = self:FormatType(err or v,nil, self.EXPAND_TABLES and 20 or nil,dat.index) or ""

			if self.find then
				if (type(dat.index)=="string" and dat.index:find(self.find))
				or (type(dat.data)=="string" and dat.data:find(self.find))
				or (s and s:find(self.find)) then
					d(dat.index.." = "..s)
				end
			end

			if err then s = color(COLORS.error,s) end

			if dat.index then
				local blacklist = WhyBlacklisted(dat.index)
				if blacklist then  s = color(COLORS.blacklist, blacklist)  end

				local metaprefix = dat.meta and "(m) " or ""

				if type(dat.index)=="string" and not dat.parent then
					SPECIAL_FUNC_CALLS:getparams(dat.index,dat)
				end
				local param = dat.params and color("ffff8800","\"".. (dat.params[1] or "") .."\"") or ""  -- TODO:UGLY

				if type(dat.data)=="function" or dat.func then
					s = metaprefix .. color("ff88ff00",tostring(dat.index) .. color("ff44aa00","(".. param ..")")) .. " = "..s
				else
					s = metaprefix .. color("ff888888","[".. self:FormatType(dat.index).."]") .. " = " .. s
				end
			end

			local meta = getmetatable(dat.data)
			meta = meta and meta.__index

			-- append tostring of table
			if dat.data and type(dat.data)=="table"
			and ( rawget(dat.data,"tostring")		-- Don't want to run into __index that is a function.
						or ( meta and type(meta)=="table" and rawget(meta,"tostring") ) -- Really only want :tostring that are suppose to be there. No need to dick around with __indexs just rawget the metatable too
					)
			and type(dat.data.tostring)=="function" then
				-- Note: a __index = function() end will trigger this error.
				local ok,txt = pcall(dat.data.tostring,dat.data)
				if not ok then txt="ERR: "..txt end
				txt = txt:gsub("\n","@LINEBREAK@")					-- Don't allow multiple lines because it makes it ugly
				s = s .. " \"".. txt .."\""
			end

			local textfield = line:FindChild("Text")
			textfield:SetText("<P>"..s.."</P>")

			local expandbut = line:FindChild("ExpandButton")

			if type(dat.data)=="table" or type(dat.data)=="userdata" then
				expandbut:Show(true)
				expandbut:SetCheck(dat.expanded)
				expandbut:ChangeArt("BK3:btnHolo_ExpandCollapseSmall")
			elseif dat.func and not WhyBlacklisted(dat.index) then
				expandbut:Show(true)
				expandbut:SetCheck(dat.parent) --TODO: . :
				expandbut:ChangeArt("BK3:btnHolo_Options_DragRight")
			elseif dat.parent==_G.Sound then
				expandbut:Show(true)
				expandbut:SetCheck(true)
				expandbut:ChangeArt("BK3:btnHolo_Options_DragRight")
			else
				expandbut:Show(false)
			end

			local l,t,r,b = expandbut:GetAnchorOffsets()
			l = dat.indent*15 - 4
			expandbut:SetAnchorOffsets(l,t,l+28,b)
			local l2,t2,r2,b2 = textfield:GetAnchorOffsets()
			l2=l+28
			textfield:SetAnchorOffsets(l2,t2,0,b2)

			line:SetData(self.offset+i)

			line:Show(true)
		else
			line:Show(false)
		end

	end

	if #self.lines < MAX_LINES then
		--frame.slider:SetHidden(true)
	else
		--frame.slider:SetHidden(false)
	end
end


local FUNCTIONGROUPS={}

function VooProto:Main(insertpoint,indent,data,orig,mode,command)
	if not data then return end
	if not insertpoint then self.lines={} insertpoint=1 end

	indent = indent or 1
	local s,expand,isUserdata
	local added=0

	if mode=="global" then		-- Examine the global table

		--local PFC = 1
		local categories = {
			ZO_ = {}
		}
		--categories.ZO_={"ZO_Achievements","ZO_Alchemy","ZO_Campaign","ZO_KeepWindow","ZO_MapPin","ZO_Provisioner","ZO_QuickSlot","ZO_StablePanel","ZO_TradingHouse","ZO_WorldMap","ZO_Smithing","ZO_PlayerInventory","ZO_Guild","ZO_Enchanting","ZO_Character"}
		local GData = {
			[1] = {_is_global=true},
			ZO_ = {},
			SI_ = {["_Voo"]="si"},
			CT_ = {},
			['zz EVENTS'] = {},
			['zz OTHER CONSTS']= {},
			['zz UI'] = {},
		}
		--for k,v in pairs(FUNCTIONGROUPS_) do GData[k]={_is_global=true} end
		local curDataTable = GData[1]
		local curTableSize, totalSize = 0,0
		local MAX_GLOBAL = 25000
		--local copyCount, legitAfterCopy = 0,0

		for index,value in safepairs(data) do while(1) do
			-- private or protected funcs have already been replaced with harmless strings by safepairs

			if type(value)=="userdata" and BLOCK_USERDATA then break end
			if index:match("^[%u_%d]*$") and BLOCK_CAPS then break end
			if index:find("ZO_") and BLOCK_ZO then break end

			-- Helpful for finding things in _G
			if PRINT_GLOBALS then
				printfromglobal(index,value)
			end

			--if not (index:find("Action") and index:find("Layer")) then break end

			if false and self.Events.eventListR[index] then				GData['zz EVENTS'][index]=value
			elseif index:find("^EVENT") and not EVENTBLACKLIST[index] then		d("New Event :"..index)		GData['zz EVENTS'][index]=value
			elseif index:find("^SI_") then			GData.SI_[index]=value
			elseif index:find("^CT_") then			GData.CT_[index]=value
			elseif type(value)=="number" and index:find("^%u+_[%u%d]+") then	GData['zz OTHER CONSTS'][index]=value
			elseif index:find("^ZO_") then
				local found
				for k,v in pairs(categories.ZO_) do
					if index:find("^"..v) then
						v=v.."___"
						local where=GData.ZO_[v]
						if not where then where={} GData.ZO_[v]=where end
						where[index]=value
						found=true
						break
					end
				end
				if not found then GData.ZO_[index]=value end
			elseif type(value)=="userdata" and type(value.GetType)=="function" then
				GData['zz UI'][index]=value
			else
				-- use an else here so only a single FUNCTIONGROUPS[index] is indexed. It got metatabled
				local fugr = FUNCTIONGROUPS[index] or (type(value)=="string" and FUNCTIONGROUPS[value])	-- TODO could not force only strings
				if fugr then
					GData[fugr][index]=value
				else
					curDataTable[index] = value
					curTableSize = curTableSize + 1
				end
			end

			-- 1 table of 16000 crashes the game. Whoda thunk
			if curTableSize >= GTableSize then
				GData[#GData + 1] = {}
				curDataTable = GData[#GData]
				curTableSize=0
			end

			MAX_GLOBAL = MAX_GLOBAL - 1
			if MAX_GLOBAL <= 0 then d("FOR LOOP WENT TOO LONG FOR _G PLEASE REPORT TO @Errc") end
		break end end

		data = GData

		data['Voo Utilities'] = Voo.Utils
	end

	local meta = getmetatable(data)
	local meta_safe = not meta or type(meta.__index)~="function" -- If the __index of a table is a function, then lets not index it because we can't safely say what will happen.

	if type(data)=="table" then
		local tab={}
		if meta_safe and data["_Voo"]=="si" then
			for k,v in pairs(data) do
				tinsert(tab,{
					index=k,
					data=GetString(v),
					indent=indent,
					}
				)
			end
		else
			for k,v in safepairs(data) do
				local parent = orig or data
				local p_meta = getmetatable(parent)
				local p_meta_safe = not p_meta or type(p_meta.__index)~="function" -- If the __index of a table is a function, then lets not index it because we can't safely say what will happen.

				if (type(parent)~="table" and type(parent)~="userdata") or (p_meta_safe and parent._is_global) then parent=nil end
				tinsert(tab,{
					data=v,
					index=k,
					func=(type(v)=="function" or WhyBlacklisted(k)),
					indent=indent,
					parent=parent,
					userdata = type(v)=="userdata" and getusermetatable(v),
					}
				)
			end
		end


		if meta and meta.__index and type(meta.__index)=="table" then
			for k,v in pairs(meta.__index) do
				tinsert(tab,{index=k,data=v,meta=true,func=(type(v)=="function" or WhyBlacklisted(k)),indent=indent,parent=orig or data,userdata = type(v)=="userdata" and getusermetatable(v)})
			end
		end
		if meta then
			tinsert(tab,{index="__z_metatable",data=meta,indent=indent,parent=data})
		end

		table.sort(tab,downcasesort)

		for _,v in ipairs(tab) do
			tinsert(self.lines,insertpoint,v)
			insertpoint=insertpoint+1
		end

	elseif type(data)=="userdata" then
		tablesize(data)	-- Stick GetChildren into the userdata
		self:Main(insertpoint,indent,getusermetatable(data),data)
		return
	else
		tinsert(self.lines,insertpoint,{data=data,indent=indent})
		insertpoint=insertpoint+1
	end

	self.fakelist:FindChild("FakeWindow"):SetAnchorOffsets(0,0,0,LINE_HEIGHT*#self.lines)
	self.fakelist:RecalculateContentExtents()

	self.Frame:Show(true,true)
	self:Update()

	--SCENE_MANAGER:Show("zgoo")
end







-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function VooProto:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tItems = {} -- keep track of all the list items
	o.wndSelectedListItem = nil -- keep track of which list item is currently selected

    return o
end

function VooProto:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
	Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- VooProto OnLoad
-----------------------------------------------------------------------------------------------
function VooProto:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("Voo.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- VooProto OnDocLoaded
-----------------------------------------------------------------------------------------------
function VooProto:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.Frame = Apollo.LoadForm(self.xmlDoc, "VooForm", nil, self)
		if self.Frame == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		-- item list
		self.wndItemList = self.Frame:FindChild("ItemList")

		self.Frame:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("voo", "CmdVoo", self)

		self:PrepareUserDataMetatables()
		self:PrepareItemList()

		self.fakelist = self.Frame:FindChild("ItemFakeList")
		
		-- Do additional Addon initialization here
		--self:OnVooOn()
	end
end

-----------------------------------------------------------------------------------------------
-- VooProto Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/event"
local firsttime=true
function VooProto:CmdVoo(cmd,text)
	Print(text)
	self.Frame:Invoke() -- show the window

	if (not text or text=="") and firsttime then text="global" firsttime=false end
	
	if not text or text=="" then
		--if not self.Frame then self:CreateFrame() end
		--self.Frame:Invoke()
	elseif text=="global" or text=="_G" or text=="GLOBAL" then
		self:Main(nil,1,_G,nil,"global") -- indicate global mode explicitly
	elseif text.find and text:find("^find") then
		self.find = text:match("^find (.*)")
		Print("Finding "..(self.find and self.find or "(nothing)")..", keep scrolling around...")
		self:Update()
	--[[
	elseif text=="events" or text=="EVENTS" then
		if not self.Events.EventTracker then self.Events:CreateEventTracker() end
		-- Reset defaults
		self.Events.curBotEvent = 0
		self.Events.eventsTable = {}
		Zgoo.ChainCall(self.Events.EventTracker.slider)
			:SetMinMax(0,0)
			:SetValue(0)
		self.Events.EventTracker:SetHidden(not self.Events.EventTracker:IsHidden())
	--]]
	elseif text=="mouse" then
		local control = Apollo:GetMouseTargetWindow()
		-- TODO maybe find a way to do all controls under the mouse.
		self:Main(nil,1,control)
	elseif type(text)=="table" or type(text)=="userdata" then
		self:Main(nil,1,text)
	elseif type(text)=="string" then
		local s = ("Voo:Main(nil,1,%s)"):format(text)
		local f,err = loadstring( s )
		if f then f() else Print("Error: "..err) end
	else
		error("Invalid Voo Param: "..tostring(text))
	end

	-- populate the item list
	--self:PopulateItemList()

end


-----------------------------------------------------------------------------------------------
-- ItemList Functions
-----------------------------------------------------------------------------------------------
-- populate item list
function VooProto:PrepareItemList()
	-- make sure the item list is empty to start with
	
	-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	self.framelines = {}
	for i=1,MAX_LINES do
		tinsert(self.framelines,self:CreateRow(i))
	end
	self.wndItemList:ArrangeChildrenVert()  -- inefficient, but screw it
end

-- add an item into the item list
function VooProto:CreateRow(n)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ListItem", self.wndItemList, self)

	wnd:Show(true, true)

	wnd:SetName("Line"..n)

	return wnd
end


function VooProto:ExpandLine(linei)
	Print("Expanding "..tostring(linei))
	local data = self.lines[linei]
	--local func = data[but.index and "index" or "data"]
	local func = data.data
	--local indexi = but.index and "expandedi" or "expanded"
	local expandcheck = "expanded"

	--if WhyBlacklisted(data.index) then return end

	local result

	if data.parent==_G.Sound and type(data)=="number" then _G.Sound.Play(data.data) return end
	
	if func and type(func)=="function"
	and not data[expandcheck]  -- don't call when we're about to COLLAPSE
	then
		--d(data.index .. " = ")
		local tab={params={}}
		SPECIAL_FUNC_CALLS:getparams(data.index,tab)

		
		--if IsShiftKeyDown() then
		local ok,res = pcallhelper(pcall(func,data.parent or unpack(tab.params)))
		if ok then result=res end
		--else
		--	result={func(data.parent or unpack(tab.params))}
		--end


		--d(Zgoo.FormatType(result))
		if result then
			if #result==1 then
				result=result[1]
			elseif #result==0 then
				result=nil
			end
		end

		if not result then return end
	end

	--if IsShiftKeyDown() then Zgoo(result or (but.index and data.parent --[[or data.userdata--]] or data.data)) return end

	-- expand or collapse?

	if not data[expandcheck] then
		-- expand
		data[expandcheck]=true
		self:Main(
			linei+1,
			data.indent+1,
			--result or (but.index and data.parent --[[or data.userdata--]] or data.data),
			result or data.data --[[or data.userdata--]],
			--result or (type(data.data=="table") and data.data)
			result or (type(data.data=="table") and data.data)
		)
	else
		-- collapse
		while self.lines[linei+1] and self.lines[linei+1].indent > data.indent do
			tremove(self.lines,linei+1)
		end
		data[expandcheck]=nil
		self:Update()
	end

end



---------------------------------------------------------------------------------------------------
-- ListItem Functions
---------------------------------------------------------------------------------------------------
function VooProto:EventExpand2( wndHandler, wndControl, eMouseButton )
	self:EventExpand(wndHandler,wndControl,eMouseButton)
end

function VooProto:EventExpand( wndHandler, wndControl, eMouseButton )
	local line = wndControl:GetParent()
	local data = line:GetData()
	if not data then return end
	self:ExpandLine(data)

	--[[
	if data.expanded then
		local txt = ""
		text:SetText(data.event .. "\n" .. data.text)
	else
		text:SetText(data.label)
	end
	local nTextWidth, nTextHeight = text:SetHeightToContentHeight()
	nTextHeight = math.max(27,nTextHeight)
	local nLeft, nTop, nRight, nBottom = item:GetAnchorOffsets()
	item:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nTextHeight)
	wndControl:SetCheck(data.expanded)
	self.wndItemList:ArrangeChildrenVert()
	--]]
end

function VooProto:Analyze(data)
	if type(data)=="userdata" then return self:AnalyzeUserData(data)
	else return tostring(data) end
end

local metatables = {}

function VooProto:PrepareUserDataMetatables()
	local metatable_src = {
		UNIT = GameLib.GetPlayerUnit(),
		VECTOR3 = Vector3.New(0,0,0)
	}
	for k,v in pairs(metatable_src) do metatables[getmetatable(v)]=k end
end

function VooProto:AnalyzeUserData(ud)
	local class = metatables[getmetatable(ud)]
	if class=="UNIT" then
		return "<UNIT "..ud:GetName()..">"
	elseif class=="VECTOR3" then
		local s = tostring(ud)
		local x,y,z = s:match("Vector3%((.*), (.*), (.*)%)")
		if z then return ("Vector3(%.2f,%.2f,%.2f)"):format(tonumber(x),tonumber(y),tonumber(z))
		else return s end
	else
		return tostring(ud)
	end
end




function VooProto:EventExpandFromRow( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	local expand = wndControl:FindChild("ExpandButton")
	if expand and expand:IsShown() then self:EventExpand(wndHandler,expand,eMouseButton) end
end


---------------------------------------------------------------------------------------------------
-- VooForm Functions
---------------------------------------------------------------------------------------------------
function VooProto:OnOK( wndHandler, wndControl, eMouseButton )
	self.Frame:Close()
end

function VooProto:OnConfig( wndHandler, wndControl, eMouseButton )
	self.CALL_FUNCTIONS = self.Frame:FindChild("FuncButton"):IsChecked()
end

local lastscroll = 0
function VooProto:UpdateOffsetFromScroll( wndHandler, wndControl, nLastRelativeMouseX, nLastRelativeMouseY, fScrollAmount, bConsumeMouseWheel )
	local scroll = self.fakelist:GetVScrollPos()
	if lastscroll~=scroll then
		lastscroll=scroll
		self.offset = math.floor(scroll/LINE_HEIGHT)
		self:Update()
	end
end



-----------------------------------------------------------------------------------------------
-- VooProto Instance
-----------------------------------------------------------------------------------------------
Voo = VooProto:new()
Voo:Init()

