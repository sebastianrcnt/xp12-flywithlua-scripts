-- Written by JarekP 2022-09-27
-- See JPteleporter.pdf for instructions
local fuel_factor1 = 1.00
local max_jump = 40.0

FONTSIZE = 18

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("imgui not supported by your FlyWithLua version")
    return
end

local socket = require("socket")
-- first we need ffi module (variable must be declared local)
local ffi = require("ffi")
-- find the right lib to load
local XPLMlib = ""
if SYSTEM == "IBM" then
  -- Windows OS (no path and file extension needed)
  if SYSTEM_ARCHITECTURE == 64 then
    XPLMlib = "XPLM_64"  -- 64bit
  else
    XPLMlib = "XPLM"     -- 32bit
  end
elseif SYSTEM == "LIN" then
  -- Linux OS (we need the path "Resources/plugins/" here for some reason)
  if SYSTEM_ARCHITECTURE == 64 then
    XPLMlib = "Resources/plugins/XPLM_64.so"  -- 64bit
  else
    XPLMlib = "Resources/plugins/XPLM.so"     -- 32bit
  end
elseif SYSTEM == "APL" then
  -- Mac OS (we need the path "Resources/plugins/" here for some reason)
  XPLMlib = "Resources/plugins/XPLM.framework/XPLM" -- 64bit and 32 bit
else
  return -- this should not happen
end
-- load the lib and store in local variable
local XPLM = ffi.load(XPLMlib)
ffi.cdef("typedef void * XPLMDataRef;")
ffi.cdef("XPLMDataRef XPLMFindDataRef(const char * inDataRefName);")
ffi.cdef("double XPLMGetDatad(XPLMDataRef inDataRef);")
ffi.cdef("void XPLMSetDatad(XPLMDataRef inDataRef, double inValue);")
ffi.cdef("void XPLMWorldToLocal(double inLatitude, double inLongitude, double inAltitude, double * outX, double * outY, double * outZ);")

local JPTlatd = 43.0
local JPTlond = -77.0
local JPTaltd = 700.0

JPT_window = nil
JPT_windows_stat = 0

local JPTlon = 0.0
local JPTlat = 0.0
local JPTalt = 0.0
local loc_X = 0.0
local loc_Y = 0.0
local loc_Z = 0.0
local loc_Xout = 0.0
local loc_Yout = 0.0
local loc_Zout = 0.0

local fplan = 1
local fplanfile = ""
local fplanloaded = 0
local fplan_name = {}
local fplan_alt = {}
local fplan_lat = {}
local fplan_lon = {}
local fplan_fplanloadedlon = {}
local fplan_sel = 1
local fplan_error = 0
--local fplan_offset = 0.15
local fplan_offset = 5.0
local fplan_ident = 1.5

FUELFLOWTBL = dataref_table("sim/cockpit2/engine/indicators/fuel_flow_kg_sec")
DataRef( "CBARO", "sim/weather/barometer_current_inhg")
DataRef( "PBARO", "sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot")
DataRef( "SIMSPEED", "sim/time/sim_speed", "writable")
DataRef( "NUMENG", "sim/aircraft/engine/acf_num_engines")
DataRef( "GSPEED", "sim/flightmodel/position/groundspeed")
DataRef( "ZTIME", "sim/time/zulu_time_sec", "writable")
DataRef( "ETIME", "sim/time/timer_elapsed_time_sec", "writable")
DataRef( "FTOTALIZER", "sim/cockpit2/fuel/fuel_totalizer_sum_kg", "writable")
AFUEL = dataref_table("sim/flightmodel/weight/m_fuel")
RFUEL = dataref_table("sim/aircraft/overflow/acf_tank_rat")
DataRef( "MFUELT", "sim/aircraft/weight/acf_m_fuel_tot")
maxfuel1 = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0} 
uuset1 = {0, 0, 0, 0, 0, 0, 0, 0, 0} 
local uusetcount1 = 0
for i = 1, 9, 1 do
	if RFUEL[i-1] > 0.0 then
		maxfuel1[i] = RFUEL[i-1]*MFUELT;
	end
end
local fuel_adj_armed1 = 0
local Mtrc = false
local coef1 = 2.20462
local unit1 = "lb"
local tot_time = 0
local ctime1 = 0.0
local fueltotcorr1 = 0.0 --in kgs
local timetotcorr1 = 0.0
local last_jump_time = 0.0
local last_jump_time0 = 0.0
local keep_alt = true
local hide_prior = true
local full_jump = true
local autoapply1 = false
local tot_fuel_corr = 0.0
local last_waypoint_dist = 999.0
local fuel_adj1_delay = 0
local fuel_adj1_pause = 0
local fuel_adj1_verify = 0
local fueladjust1_verify = 0.0
local fuel_adj1_onboard_verify = 0.0
local fueladj1fail=0

local loc_X_ptr = XPLM.XPLMFindDataRef("sim/flightmodel/position/local_x")	
local loc_Y_ptr = XPLM.XPLMFindDataRef("sim/flightmodel/position/local_y")	
local loc_Z_ptr = XPLM.XPLMFindDataRef("sim/flightmodel/position/local_z")	

function show_JPT_window()
	if JPT_windows_stat  == 1 then 
		float_wnd_destroy(JPT_window)
		JPT_window = nil
		JPT_windows_stat = 0
	end
	if JPT_windows_stat == 0 then 
		JPT_window = float_wnd_create(FONTSIZE * 31, FONTSIZE * 25, 1, true);
		float_wnd_set_title(JPT_window, "JP Teleporter");
		float_wnd_set_imgui_builder(JPT_window, "build_JPT_window");
		float_wnd_set_onclose(JPT_window, "on_close_JPT_window")
		JPT_windows_stat = 1
	end
end

function on_close_JPT_window(wnd)
	JPT_windows_stat = 0
end

function build_JPT_window(wnd, x, y)
	if fuel_adj1_verify == 1 then
		fuel_adj1_delay = fuel_adj1_delay + 1
		if fuel_adj1_delay < 3 then return end
		fuel_adj1_delay = 0
		local fuel1_onb = fuel_total_JPT()
		if fuel1_onb > fuel_adj1_onboard_verify then
			--fuel adjustment failed -> restore values
			fueltotcorr1 = fueltotcorr1 + fueladjust1_verify
			tot_fuel_corr = tot_fuel_corr - fueladjust1_verify
			fueladj1fail = 1
		else
			fueladj1fail = 0
		end
		fuel_adj1_verify = 0
	end
	if fuel_adj_armed1 == 1 and fplan == 1 and fueladj1fail == 0 then
	-- fuel adjustment
		fuel_adj1_delay = fuel_adj1_delay + 1
		if fuel_adj1_delay < 3 then return end
		fuel_adj1_delay = 0
		local fadjust = fueltotcorr1
		local fadjust1 = fadjust 
		local cntn = true
		while (fadjust1>0.0 and fadjust1 < fadjust) or cntn
		do
			cntn = false
			fadjust = fadjust1
			fadjust1 = fuel_adjust_JPT(fadjust)
		end
		fueladjust1_verify = fueltotcorr1 - fadjust1
		FTOTALIZER = FTOTALIZER + fueltotcorr1 - fadjust1
		tot_fuel_corr = tot_fuel_corr + fueltotcorr1 - fadjust1
		fueltotcorr1 = fadjust1
		if fuel_adj1_pause == 1 then SIMSPEED = 1 end
		fuel_adj_armed1 = 0
		fuel_adj1_onboard_verify = fuel_total_JPT()
		fuel_adj1_verify = 1
	end
	if last_jump_time0 > 0.0 then
		last_jump_time = socket.gettime() - last_jump_time0
		last_jump_time0 = 0.0
	--	if fplanloaded == 1 and full_jump then
	--		fplan_sel = fplan_sel + 1
	--		if fplan_sel>#fplan_name then fplan_sel=#fplan_name end
	--	end
	end
	if fplanloaded == 1 then
		--if closer that fplan_ident to a selected waypoint, and dist growing, advance
		local cur_waypoint_dist = distanceH(LATITUDE, LONGITUDE, fplan_lat[fplan_sel]*1.000, fplan_lon[fplan_sel]*1.000)
		if 0.000539957*cur_waypoint_dist < fplan_ident then
			if cur_waypoint_dist > last_waypoint_dist then
				fplan_sel = fplan_sel + 1
				if fplan_sel > #fplan_name then fplan_sel=#fplan_name end
			end
		end
		last_waypoint_dist = cur_waypoint_dist
	end
	imgui.TextUnformatted("Current Lat:" .. string.format("%.03f",LATITUDE) .. " Lon:" .. string.format("%.03f",LONGITUDE) .. " TrueAlt:" .. string.format("%.0f",ELEVATION*3.28084) .. "ft ground speed:" .. string.format("%.0f",GSPEED*1.94384) .. "kt")
	imgui.SameLine()
	imgui.SetCursorPosX(475)
	local changed, newVal = imgui.Checkbox("Metric", Mtrc)
	if changed then 
		Mtrc = newVal
	end
	if Mtrc then 
		coef1 = 1.0 
		unit1 = "kg"
	else
		coef1 = 2.20462 
		unit1 = "lb"
	end
	if JPTlon == 0.0 and JPTlat == 0.0 and JPTalt == 0.0 then
		JPTlon = LONGITUDE
		JPTlat = LATITUDE
		JPTalt = ELEVATION*3.28084
	end
	if XPLM then
		if fplan >= 1 and fplanloaded == 0 then
			imgui.TextUnformatted("Flight plan not loaded ... cannot jump")
		elseif fplan == 2 then
			imgui.TextUnformatted("In fuel management ... cannot jump")
		else
			ldstr = ""
			if fplanloaded == 1 then ldstr = "Flight plan loaded " end
			if fplanloaded == 1 and 0.000539957*distanceH(LATITUDE, LONGITUDE, fplan_lat[fplan_sel]*1.000, fplan_lon[fplan_sel]*1.000)<fplan_offset then
				imgui.TextUnformatted("Close waypoint ... cannot jump")
			else
				imgui.TextUnformatted(ldstr .. "XPLM loaded  ")
				imgui.SameLine()
				imgui.SetCursorPosX(250)
				if imgui.Button("Jump!", 60, 18) then
					local loc_Xout_ptr = ffi.new("double[1]")
					local loc_Yout_ptr = ffi.new("double[1]")
					local loc_Zout_ptr = ffi.new("double[1]")
					loc_X = XPLM.XPLMGetDatad(loc_X_ptr)
					loc_Y = XPLM.XPLMGetDatad(loc_Y_ptr)
					loc_Z = XPLM.XPLMGetDatad(loc_Z_ptr)
					if fplan == 1 then
						fueladj1fail = 0
						JPTlatd = fplan_lat[fplan_sel]*1.000
						JPTlond = fplan_lon[fplan_sel]*1.000
						-- approximate correction for difference in baro settings
						local fplan_true_alt = fplan_alt[fplan_sel]*1.000 + 1000.0*(CBARO-PBARO)
						JPTaltd = fplan_true_alt/3.28084
						if keep_alt then JPTaltd = ELEVATION end
						local dist = distanceH(LATITUDE, LONGITUDE, JPTlatd, JPTlond)
						full_jump = true
						if 0.000539957*dist-fplan_offset>max_jump then
							JPTlatd, JPTlond = partialH(LATITUDE, LONGITUDE, JPTlatd, JPTlond, max_jump)
							full_jump = false
							dist = distanceH(LATITUDE, LONGITUDE, JPTlatd, JPTlond)
						else
							JPTlatd, JPTlond = partialH(LATITUDE, LONGITUDE, JPTlatd, JPTlond, 0.000539957*dist-fplan_offset)
							dist = distanceH(LATITUDE, LONGITUDE, JPTlatd, JPTlond)
						end
						if GSPEED>0.1 then
							timetotcorr1 = timetotcorr1 + dist/GSPEED
							fueltotcorr1 = fueltotcorr1 + fuel_factor1*fuel_flow_total_JPT()*dist/GSPEED
						end
					else
						JPTlatd = JPTlat*1.000
						JPTlond = JPTlon*1.000
						JPTaltd = JPTalt/3.28084
					end
					XPLM.XPLMWorldToLocal(JPTlatd, JPTlond, JPTaltd, loc_Xout_ptr, loc_Yout_ptr, loc_Zout_ptr)
					XPLM.XPLMSetDatad(loc_X_ptr, loc_Xout_ptr[0])
					XPLM.XPLMSetDatad(loc_Y_ptr, loc_Yout_ptr[0])
					XPLM.XPLMSetDatad(loc_Z_ptr, loc_Zout_ptr[0])
					imgui.SameLine()
					imgui.SetCursorPosX(350)
					imgui.TextUnformatted("  [jump in progress ...]")
					last_jump_time0 = socket.gettime()
					last_jump_time = 0.0
				end
			end
			if last_jump_time > 0.0 then
				local zmn =math.floor((last_jump_time)/60) 
				local zsc =last_jump_time-zmn*60
				imgui.SameLine()
				imgui.SetCursorPosX(370)
				imgui.TextUnformatted("[" .. string.format("%.0f", zmn) .. "min " .. string.format("%02.01f", zsc) .. "sec]") 
			end
		end
	else
		imgui.TextUnformatted("XPLM NOT loaded  ... cannot jump")
	end
	local fplan0 = fplan
	if fplan0 == 1 then imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00) end
	if imgui.RadioButton("Flight Plan", fplan == 1) then
		fplan=1	
	end
	if fplan0 == 1 then imgui.PopStyleColor() end
	imgui.SameLine()
	imgui.SetCursorPosX(150)
	if fplan0 == 2 then imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00) end
	if imgui.RadioButton("Fuel Management", fplan == 2) then
		fplan=2	
	end
	if fplan0 == 2 then imgui.PopStyleColor() end
	imgui.SameLine()
	imgui.SetCursorPosX(330)
	if fplan0 == 0 then imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00) end
	if imgui.RadioButton("Manual jump", fplan == 0) then
		if fplan0 == 1 then
			JPTlon = LONGITUDE
			JPTlat = LATITUDE
			JPTalt = ELEVATION*3.28084
		end
		fplan=0	
	end
	if fplan0 == 0 then imgui.PopStyleColor() end
	imgui.PushStyleColor(imgui.constant.Col.Separator, 0xFFFFFFFF)
	imgui.Separator()
	imgui.PopStyleColor()
	if fplan == 2 then
		imgui.TextUnformatted("Choose tanks to subtract fuel from with APPLY FUEL button on Flight Plan page")
		imgui.TextUnformatted("Typically only tanks feeding engines should be selected")
		imgui.TextUnformatted("APPLY FUEL button will not be displayed unless tank(s) are selected")
		for i = 1, 9, 1 do
			if RFUEL[i-1] > 0.0 then
				if AFUEL[i-1] > 0.0 then
					local uuu = false
					if uuset1[i] == 1 then uuu=true end
					local changed1, newVal1 = imgui.Checkbox("Tank " .. i, uuu)
					if changed1 then 
						if uuset1[i] == 1 then 
							uuset1[i]=0 
							uusetcount1 = uusetcount1 - 1
						else 
							uuset1[i]=1 
							uusetcount1 = uusetcount1 + 1
						end
					end
				else
					imgui.TextUnformatted("   ");
					imgui.SameLine()
					imgui.SetCursorPosX(31)
					imgui.TextUnformatted("Tank " .. i);
				end
				imgui.SameLine()
				imgui.SetCursorPosX(70)
				imgui.TextUnformatted(": " .. string.format("%6.0f",math.floor(coef1*AFUEL[i-1]+0.5)) .. " " .. unit1 .. " [" .. string.format("%5.1f",math.floor(100*AFUEL[i-1]/maxfuel1[i]+0.5)) .. "%]")
			else
				uuset1[i]=0 
			end
		end
		imgui.PushStyleColor(imgui.constant.Col.Separator, 0xFF00FF00)
		imgui.Separator()
		imgui.PopStyleColor()
		imgui.BeginTable("table1", 4)
		imgui.TableNextRow()
       		imgui.TableNextColumn()
		imgui.TextUnformatted("Fuel burn factor:")
       		imgui.TableNextColumn()
		local changed, newVal = imgui.InputText("   ", string.format("%.02f", fuel_factor1), 20)
		if changed then
			newVal=string.match(newVal, "%d*%.?%d+")
			if newVal == nil then
			else
				fuel_factor1=1.00*newVal
			end
		end
		imgui.EndTable()
		local uuu = false
		if fuel_adj1_pause == 1 then uuu=true end
		local changed1, newVal1 = imgui.Checkbox("Pause for fuel adjustment ", uuu)
		if changed1 then 
			if newVal1 == true then
				fuel_adj1_pause = 1
			else
				fuel_adj1_pause = 0
			end
		end
	elseif fplan == 0 then
		local changed, newVal = imgui.InputText("New Lat (deg)", string.format("%.03f", JPTlat), 50)
		if changed then
			newVal=string.match(newVal, "%d*%.?%d+")
			if newVal == nil then
			else
				JPTlat=1.00*newVal
			end
		end
		local changed, newVal = imgui.InputText("New Lon (deg)", string.format("%.03f", JPTlon), 50)
		if changed then
			newVal=string.match(newVal, "%d*%.?%d+")
			if newVal == nil then
			else
				JPTlon=newVal
			end
		end
		local changed, newVal = imgui.InputInt("New True Alt (ft)", JPTalt)
		if changed then
			JPTalt=newVal
		end
	else
		imgui.BeginTable("table1", 4)
		imgui.TableNextRow()
		imgui.TableNextColumn()
		imgui.TextUnformatted("Jump offset (nm)")
       		imgui.TableNextColumn()
		local changed, newVal = imgui.InputText(" ", string.format("%.03f", fplan_offset), 20)
		if changed then
			newVal=string.match(newVal, "%d*%.?%d+")
			if newVal == nil then
			else
				fplan_offset=1.00*newVal
			end
		end
		imgui.TableNextColumn()
		imgui.TextUnformatted("Max jump (nm)")
		imgui.TableNextColumn()
		local changed, newVal = imgui.InputText("  ", string.format("%.01f", max_jump), 20)
		if changed then
			newVal=string.match(newVal, "%d*%.?%d+")
			if newVal == nil then
			else
				max_jump=1.00*newVal
			end
		end
		imgui.EndTable()
		imgui.TextUnformatted("Flight plan file is loaded from <X-Plane root>/Output/FMS plans/")
		local changed, newTxt = imgui.InputText("Flight plan file (.fms)", fplanfile, 255)
		if changed then
			local extstr = GetFileExtension(newTxt)
			if extstr == ".fms" then
				fplanfile=newTxt 
			else
				fplanfile=newTxt .. ".fms"
			end
			fplan_error = 0
		end
		local fplanpath = SYSTEM_DIRECTORY .. "Output" .. DIRECTORY_SEPARATOR .. "FMS plans" .. DIRECTORY_SEPARATOR
		if imgui.Button("Load Flight Plan", 150, 18) then
			local file = io.open(fplanpath .. fplanfile, "r");
			if file == nil then
				fplan_error = 1
			else
				fplan_error = 0
				for line in file:lines() do
					line_arr = Split(line, " ")
					if #line_arr >= 6 then
						fplan_name[#fplan_name + 1] = line_arr[2]
						fplan_alt[#fplan_alt + 1] = 1.00*line_arr[4]
						fplan_lat[#fplan_lat + 1] = 1.00*line_arr[5]
						fplan_lon[#fplan_lon + 1] = 1.00*line_arr[6]
					end
				end
				file:close()
				fplanloaded = 1
			end
		end
		imgui.SameLine()
		imgui.SetCursorPosX(230)
		local changed, newVal = imgui.Checkbox("Autoapply corrections", autoapply1)
		if changed then 
			autoapply1 = newVal
		end
		if PLANE_ICAO == "MD11" then
			imgui.TextUnformatted("NOTE: For Rotate MD11 don't use Autoapply, apply fuel changes when");
			imgui.TextUnformatted("      larger that 750lb or 500kg (depneding on plane weight units).");
			imgui.TextUnformatted("      Elapsed time fixes can be applied anytime.");
		end
		local changed, newVal = imgui.Checkbox("Hide prior waypoints", hide_prior)
		if changed then 
			hide_prior = newVal
		end
		imgui.SameLine()
		imgui.SetCursorPosX(230)
		local changed, newVal = imgui.Checkbox("Keep current altitude in jump", keep_alt)
		if changed then 
			keep_alt = newVal
		end
		if fplan_error == 1 then imgui.TextUnformatted("Cannot open file " .. fplanpath .. fplanfile) end
		if fplanloaded == 1 then
			if timetotcorr1>0 or ctime1>0 or fueltotcorr1>0.0 then
				imgui.PushStyleColor(imgui.constant.Col.Separator, 0xFF00FF00)
				imgui.Separator()
				imgui.PopStyleColor()
			end
			if timetotcorr1>0 then
				imgui.TextUnformatted("Time Correction To Apply (sec): " .. string.format("%.0f",math.floor(timetotcorr1+0.5)))
				imgui.SameLine()
				imgui.SetCursorPosX(300)
				if imgui.Button("APPLY TIME", 120, 18) or autoapply1 then
					ZTIME = ZTIME + timetotcorr1
					ETIME = ETIME + timetotcorr1
					ctime1 = ctime1 + timetotcorr1
					timetotcorr1 = 0.0
				end
			end
			if ctime1>0 then
				local zhr =math.floor(ctime1/3600) 
				local zmn =math.floor((ctime1-zhr*3600)/60) 
				local zsc =math.floor(ctime1-zhr*3600-zmn*60+0.5)
				imgui.TextUnformatted("Skipped time: " .. string.format("%.0f", zhr) .. "hrs " .. string.format("%02.0f", zmn) .. "min " .. string.format("%02.0f", zsc) .. "sec")
			end
			if fueltotcorr1>0.0 then
				imgui.TextUnformatted("Fuel Correction To Apply (" .. unit1 .. "): " .. string.format("%.0f",math.floor(fueltotcorr1*coef1+0.5)))
				imgui.SameLine()
				imgui.SetCursorPosX(300)
				if imgui.Button("ZERO", 60, 18) then
					fueltotcorr1=0.0 
				end
				if uusetcount1>0 then
					imgui.SameLine()
					imgui.SetCursorPosX(400)
					if autoapply1 and fueladj1fail==0 then
						fuel_adj_armed1 = 1
						if fuel_adj1_pause == 1 then SIMSPEED = 0 end
					elseif imgui.Button("APPLY FUEL", 120, 18) then
						fuel_adj_armed1 = 1
						fueladj1fail = 0
						if fuel_adj1_pause == 1 then SIMSPEED = 0 end
					end
				end
			end
			if tot_fuel_corr>0.0 then
				imgui.TextUnformatted("Fuel Correction Applied (" .. unit1 .. "): " .. string.format("%.0f",math.floor(tot_fuel_corr*coef1+0.5)))
			end
			imgui.PushStyleColor(imgui.constant.Col.Separator, 0xFF00FF00)
			imgui.Separator()
			imgui.PopStyleColor()
			for i=1,#fplan_name,1 do
				local skip_p = false
				if hide_prior and i<fplan_sel then skip_p = true end
				if not skip_p then
					local calt = string.format("%7.0f",fplan_alt[i])
					if keep_alt then calt = "current" end
					local diststr = ""
					if fplan_sel == i then 
						local JPTlatd1 = fplan_lat[fplan_sel]*1.000
						local JPTlond1 = fplan_lon[fplan_sel]*1.000
						local dist1 = distanceH(LATITUDE, LONGITUDE, JPTlatd1, JPTlond1)
						diststr = " dist=" .. string.format("%7.01f", 0.000539957*dist1) .. " nm"
					end
					if imgui.RadioButton(string.format("%6s",fplan_name[i]) .. " lat=" .. string.format("%8.03f",fplan_lat[i]) .. " lon=" .. string.format("%8.03f",fplan_lon[i]) .. " alt=" .. calt .. diststr, fplan_sel == i) then
						fplan_sel=i	
					end
				end
			end
		end
	end
end

function fuel_adjust_JPT(fffadj)
	local fuel_left = 0.0
	local fuel_cnt = 0
	for i = 1, 9, 1 do
		if uuset1[i] == 1 and AFUEL[i-1] > 0.0 then
			fuel_cnt = fuel_cnt + 1
			local aaa = fffadj / uusetcount1 
			if aaa > AFUEL[i-1] then
				fuel_left = fuel_left + aaa - AFUEL[i-1]
				AFUEL[i-1] = 0.0
				uuset1[i] = 0
				uusetcount1 = uusetcount1 - 1
			else
				AFUEL[i-1] = AFUEL[i-1] - aaa
			end
		end
	end
	if fuel_cnt  == 0 then
		return fffadj
	else
		return fuel_left
	end
end

function fuel_total_JPT()
	local fuel_ttt = 0.0
	for i = 1, 9, 1 do
		fuel_ttt = fuel_ttt + AFUEL[i-1]
	end
	return fuel_ttt
end

function GetFileExtension(filename)
  return filename:match("^.+(%..+)$")
end

function Split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function distanceH(lat1, lon1, lat2, lon2)
	local R = 6371000
	local f1 = lat1 * math.pi/180
	local f2 = lat2 * math.pi/180
	local df = (lat2-lat1) * math.pi/180
	local l1 = lon1 * math.pi/180
	local l2 = lon2 * math.pi/180
	local dl = (lon2-lon1) * math.pi/180

	local a = math.sin(df/2) * math.sin(df/2) + math.cos(f1) * math.cos(f2) * math.sin(dl/2) * math.sin(dl/2)
	local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

	local d = R * c
	return d
end

function partialH(lat1d, lon1d, lat2d, lon2d, distp)
	--distp is distance in nm
	--dR is angular distance vs Earth radius
	local dR = distp/3443.92
	lat1 = lat1d*math.pi/180
	lat2 = lat2d*math.pi/180
	lon1 = lon1d*math.pi/180
	lon2 = lon2d*math.pi/180
	--first compute bearing
	local y = math.sin(lon2-lon1) * math.cos(lat2);
	local x = math.cos(lat1)*math.sin(lat2) - math.sin(lat1)*math.cos(lat2)*math.cos(lon2-lon1);
	local th = math.atan2(y, x);
	--local brng = (th*180/math.pi + 360) % 360; -- in degrees
	--now new lat3, lon3 on the bearing at distance
	local lat3 = math.asin( math.sin(lat1)*math.cos(dR) + math.cos(lat1)*math.sin(dR)*math.cos(th) );
	local lon3 = lon1 + math.atan2(math.sin(th)*math.sin(dR)*math.cos(lat1), math.cos(dR)-math.sin(lat1)*math.sin(lat3));
	return 180.0*lat3/math.pi, 180*lon3/math.pi
end

function fuel_flow_total_JPT()
	local ffl = 0.0
	for ii=1,NUMENG,1 do
		ffl = ffl +FUELFLOWTBL[ii-1] 
	end
	return ffl
end


add_macro("JP Teleporter", "show_JPT_window()");
