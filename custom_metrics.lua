-- DataRef 바인딩
DataRef("df_gs_m_ps", "sim/flightmodel/position/groundspeed")
DataRef("df_fw_kgs", "sim/flightmodel/weight/m_fuel_total")
DataRef("df_gw_kgs", "sim/flightmodel/weight/m_total")
DataRef("df_qnh_air_inhg", "sim/weather/barometer_current_inhg")
DataRef("df_qnh_sea_inhg", "sim/weather/barometer_sealevel_inhg")
DataRef("df_y_agl_m", "sim/flightmodel/position/y_agl")
DataRef("df_y_msl_m", "sim/flightmodel/position/elevation")
DataRef("df_zulu_time_sec", "sim/time/zulu_time_sec")

-- 화면 설정
local PANEL_WIDTH = 450
local PANEL_PADDING = 15
local LINE_HEIGHT = 20
local HEADER_HEIGHT = 30
local SECTION_SPACING = 8
local PANEL_X = 20
local PANEL_Y_TOP = SCREEN_HEIGHT - 50
local BOTTOM_PADDING = 40

-- 색상 정의
local COLOR_BG = { 0, 0, 0, 0.7 }
local COLOR_HEADER_BG = { 0.1, 0.3, 0.5, 0.8 }
local COLOR_HEADER_TEXT = { 1, 1, 1, 1 }
local COLOR_LABEL = { 0.7, 0.9, 1, 1 }
local COLOR_VALUE_PRIMARY = { 1, 1, 1, 1 }
local COLOR_VALUE_SECONDARY = { 0.8, 0.8, 0.8, 1 }
local COLOR_SEPARATOR = { 0.3, 0.5, 0.7, 0.6 }

-- 데이터 저장 (초기값 설정)
local display_data = {
    speed = { kts = "  0", kph = "   0" },
    altitude = {
        msl_ft = "    0",
        msl_m = "    0",
        agl_ft = "    0",
        agl_m = "    0"
    },
    pressure = {
        air_inhg = "0.00",
        air_hpa = "   0",
        sea_inhg = "0.00",
        sea_hpa = "   0"
    },
    weight = {
        gw = "     0", zfw = "     0", fw = "     0"
    },
    time = { utc = "00:00:00" }
}

-- 색상 설정 헬퍼
local function set_color(color)
    graphics.set_color(color[1], color[2], color[3], color[4])
end

-- 구분선 그리기
local function draw_separator(x, y, width)
    set_color(COLOR_SEPARATOR)
    graphics.set_width(1)
    graphics.draw_line(x, y, x + width, y)
end

-- 텍스트 그리기 헬퍼
local function draw_label(x, y, text, color)
    color = color or COLOR_LABEL
    draw_string(x, y, text, color[1], color[2], color[3])
end

local function draw_value(x, y, text, color)
    color = color or COLOR_VALUE_PRIMARY
    draw_string(x, y, text, color[1], color[2], color[3])
end

-- 데이터 업데이트 (덜 자주 호출)
function update_display_data()
    -- 속도
    local gs_kts = df_gs_m_ps * 1.94384
    local gs_kph = df_gs_m_ps * 3.6

    -- 고도
    local msl_ft = df_y_msl_m * 3.28084
    local msl_m = df_y_msl_m
    local agl_ft = df_y_agl_m * 3.28084
    local agl_m = df_y_agl_m

    -- 기압
    local qnh_air_inhg = df_qnh_air_inhg
    local qnh_air_hpa = df_qnh_air_inhg * 33.865
    local qnh_sea_inhg = df_qnh_sea_inhg
    local qnh_sea_hpa = df_qnh_sea_inhg * 33.865

    -- 무게
    local gw_kgs = df_gw_kgs
    local zfw_kgs = df_gw_kgs - df_fw_kgs
    local fw_kgs = df_fw_kgs

    -- 시간
    local utc_h = math.floor((df_zulu_time_sec / 3600) % 24)
    local utc_m = math.floor((df_zulu_time_sec / 60) % 60)
    local utc_s = math.floor(df_zulu_time_sec % 60)

    display_data = {
        speed = {
            kts = string.format("%3d", gs_kts),
            kph = string.format("%4d", gs_kph)
        },
        altitude = {
            msl_ft = string.format("%5d", msl_ft),
            msl_m = string.format("%5d", msl_m),
            agl_ft = string.format("%5d", agl_ft),
            agl_m = string.format("%5d", agl_m)
        },
        pressure = {
            air_inhg = string.format("%.2f", qnh_air_inhg),
            air_hpa = string.format("%4d", qnh_air_hpa),
            sea_inhg = string.format("%.2f", qnh_sea_inhg),
            sea_hpa = string.format("%4d", qnh_sea_hpa)
        },
        weight = {
            gw = string.format("%6d", gw_kgs),
            zfw = string.format("%6d", zfw_kgs),
            fw = string.format("%6d", fw_kgs)
        },
        time = {
            utc = string.format("%02d:%02d:%02d", utc_h, utc_m, utc_s)
        }
    }
end

-- 화면 그리기
function draw_flight_info()
    local x = PANEL_X
    local y = PANEL_Y_TOP
    local content_x = x + PANEL_PADDING
    local value_offset = 120 -- 값 시작 위치

    -- 전체 패널 높이 계산
    local total_height = HEADER_HEIGHT + (LINE_HEIGHT * 10) + (SECTION_SPACING * 5) + (PANEL_PADDING * 3) +
    BOTTOM_PADDING

    -- 배경
    set_color(COLOR_BG)
    graphics.draw_rectangle(x, y - total_height, x + PANEL_WIDTH, y)

    -- 헤더
    set_color(COLOR_HEADER_BG)
    graphics.draw_rectangle(x, y - HEADER_HEIGHT, x + PANEL_WIDTH, y)
    y = y - HEADER_HEIGHT + 7
    draw_string(content_x, y, "FLIGHT INFORMATION", COLOR_HEADER_TEXT[1], COLOR_HEADER_TEXT[2], COLOR_HEADER_TEXT[3])
    y = y - PANEL_PADDING - 5

    -- 속도 섹션
    y = y - SECTION_SPACING
    draw_separator(content_x, y, PANEL_WIDTH - PANEL_PADDING * 2)
    y = y - LINE_HEIGHT
    draw_label(content_x, y, "GROUND SPEED")
    draw_value(content_x + value_offset, y, display_data.speed.kts .. " KTS")
    draw_value(content_x + value_offset + 90, y, display_data.speed.kph .. " KPH", COLOR_VALUE_SECONDARY)

    -- 고도 섹션
    y = y - LINE_HEIGHT - SECTION_SPACING
    draw_separator(content_x, y + 5, PANEL_WIDTH - PANEL_PADDING * 2)
    y = y - LINE_HEIGHT
    draw_label(content_x, y, "ALTITUDE MSL")
    draw_value(content_x + value_offset, y, display_data.altitude.msl_ft .. " FT")
    draw_value(content_x + value_offset + 90, y, display_data.altitude.msl_m .. " M", COLOR_VALUE_SECONDARY)

    y = y - LINE_HEIGHT
    draw_label(content_x, y, "ALTITUDE AGL")
    draw_value(content_x + value_offset, y, display_data.altitude.agl_ft .. " FT")
    draw_value(content_x + value_offset + 90, y, display_data.altitude.agl_m .. " M", COLOR_VALUE_SECONDARY)

    -- 기압 섹션
    y = y - LINE_HEIGHT - SECTION_SPACING
    draw_separator(content_x, y + 5, PANEL_WIDTH - PANEL_PADDING * 2)
    y = y - LINE_HEIGHT
    draw_label(content_x, y, "QNH (AIR)")
    draw_value(content_x + value_offset, y, display_data.pressure.air_inhg .. " inHg")
    draw_value(content_x + value_offset + 90, y, display_data.pressure.air_hpa .. " hPa", COLOR_VALUE_SECONDARY)

    y = y - LINE_HEIGHT
    draw_label(content_x, y, "QNH (SEA)")
    draw_value(content_x + value_offset, y, display_data.pressure.sea_inhg .. " inHg")
    draw_value(content_x + value_offset + 90, y, display_data.pressure.sea_hpa .. " hPa", COLOR_VALUE_SECONDARY)

    -- 무게 섹션
    y = y - LINE_HEIGHT - SECTION_SPACING
    draw_separator(content_x, y + 5, PANEL_WIDTH - PANEL_PADDING * 2)
    y = y - LINE_HEIGHT
    draw_label(content_x, y, "GROSS WEIGHT")
    draw_value(content_x + value_offset, y, display_data.weight.gw .. " KG")

    y = y - LINE_HEIGHT
    draw_label(content_x, y, "ZERO FUEL")
    draw_value(content_x + value_offset, y, display_data.weight.zfw .. " KG")
    draw_label(content_x + 235, y, "FUEL")
    draw_value(content_x + value_offset + 170, y, display_data.weight.fw .. " KG", COLOR_VALUE_SECONDARY)

    -- 시간 섹션
    y = y - LINE_HEIGHT - SECTION_SPACING
    draw_separator(content_x, y + 5, PANEL_WIDTH - PANEL_PADDING * 2)
    y = y - LINE_HEIGHT
    draw_label(content_x, y, "UTC TIME")
    draw_value(content_x + value_offset, y, display_data.time.utc)

    y = y - PANEL_PADDING -- 하단 여백
end

-- 초기 데이터 업데이트 (스크립트 로드 시 즉시 실행)
update_display_data()

-- 콜백 등록
do_often("update_display_data()")
do_every_draw("draw_flight_info()")
