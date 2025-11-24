DataRef("df_gs_m_ps", "sim/flightmodel/position/groundspeed")
DataRef("df_fw_kgs", "sim/flightmodel/weight/m_fuel_total")
DataRef("df_gw_kgs", "sim/flightmodel/weight/m_total")
DataRef("df_qnh_air_inhg", "sim/weather/barometer_current_inhg")
DataRef("df_qnh_sea_inhg", "sim/weather/barometer_sealevel_inhg")
DataRef("df_y_agl_m", "sim/flightmodel/position/y_agl")
DataRef("df_y_msl_m", "sim/flightmodel/position/elevation")
dataref("df_zulu_time_sec", "sim/time/zulu_time_sec")

rows = {}
CURSOR_Y_INIT = SCREEN_HEIGHT - 200
cursor_x = 20
cursor_y = CURSOR_Y_INIT
cursor_ystep = 16
font_size = 16

function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end


function every_draw_cb()
    graphics.set_color(0,0,0,0.25)
    graphics.draw_rectangle(0, SCREEN_HEIGHT - 220, 400, CURSOR_Y_INIT + cursor_ystep * tablelength(rows) + font_size)
    cursor_y = CURSOR_Y_INIT
    for k, v in pairs(rows) do
        draw_string(cursor_x, cursor_y, v)
        cursor_y = cursor_ystep + cursor_y
    end
end

function often_cb()
    rows = {
        string.format("SPD: GS(%3dKTS/%4dKPH)", df_gs_m_ps * 1.94384, df_gs_m_ps * 3.6),
        string.format("ALT: MSL(%5dFT/%5dM) AGL(%5dFT/%5dM)", df_y_msl_m * 3.28084, df_y_msl_m, df_y_agl_m * 3.28084, df_y_agl_m),
        string.format("QNH: AIR(%2.2fINHG/%4dHPA) GND(%2.2fINHG/%4dHPA)", df_qnh_air_inhg, df_qnh_air_inhg * 33.865, df_qnh_sea_inhg, df_qnh_sea_inhg * 33.865),
        string.format("WGT: GW(%6dKGS) ZFW(%6dKGS) FW(%6dKGS)", df_gw_kgs, df_gw_kgs - df_fw_kgs, df_fw_kgs),
        string.format(
            "TIME: UTC(%2d:%2d:%2d)",
            (df_zulu_time_sec / 3600) % 24,
            (df_zulu_time_sec / 60) % 60,
            df_zulu_time_sec % 60
        )
    }
end

do_every_draw("every_draw_cb()")
do_often("often_cb()")