-- DataRef 바인딩 - Flight Info
DataRef("df_gs_m_ps", "sim/flightmodel/position/groundspeed")
DataRef("df_fw_kgs", "sim/flightmodel/weight/m_fuel_total")
DataRef("df_gw_kgs", "sim/flightmodel/weight/m_total")
DataRef("df_qnh_air_inhg", "sim/weather/barometer_current_inhg")
DataRef("df_qnh_sea_inhg", "sim/weather/barometer_sealevel_inhg")
DataRef("df_y_agl_m", "sim/flightmodel/position/y_agl")
DataRef("df_y_msl_m", "sim/flightmodel/position/elevation")
DataRef("df_zulu_time_sec", "sim/time/zulu_time_sec")

-- DataRef 바인딩 - Trim
dataref("df_elevator_trim", "sim/cockpit2/controls/elevator_trim")
dataref("df_aileron_trim", "sim/cockpit2/controls/aileron_trim")
dataref("df_rudder_trim", "sim/cockpit2/controls/rudder_trim")

-- 화면 설정 - Flight Info
local PANEL_WIDTH = 450
local PANEL_PADDING = 15
local LINE_HEIGHT = 20
local HEADER_HEIGHT = 30
local SECTION_SPACING = 8
local PANEL_X = 20
local PANEL_Y_TOP = SCREEN_HEIGHT - 50

-- 화면 설정 - Trim Display
local TRIM_X = SCREEN_WIDTH - 320
local TRIM_Y = SCREEN_HEIGHT - 50
local TRIM_WIDTH = 300
local TRIM_HEIGHT = 250
local TRIM_BAR_WIDTH = 260
local TRIM_BAR_HEIGHT = 20

-- 색상 정의 - Flight Info
local COLOR_BG = { 0, 0, 0, 0.7 }
local COLOR_HEADER_BG = { 0.1, 0.3, 0.5, 0.8 }
local COLOR_HEADER_TEXT = { 1, 1, 1, 1 }
local COLOR_LABEL = { 0.7, 0.9, 1, 1 }
local COLOR_VALUE_PRIMARY = { 1, 1, 1, 1 }
local COLOR_VALUE_SECONDARY = { 0.8, 0.8, 0.8, 1 }
local COLOR_SEPARATOR = { 0.3, 0.5, 0.7, 0.6 }

-- 표시 여부
local show_flight_info = true
local show_trim_display = true

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

-- ============================================
-- 유틸리티 함수들
-- ============================================

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

-- ============================================
-- Flight Info 함수들
-- ============================================

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

-- Flight Info 화면 그리기
function draw_flight_info()
    if not show_flight_info then
        return
    end

    local x = PANEL_X
    local y = PANEL_Y_TOP
    local content_x = x + PANEL_PADDING
    local value_offset = 120

    -- 전체 패널 높이 계산
    local total_height = HEADER_HEIGHT + (LINE_HEIGHT * 10) + (SECTION_SPACING * 5) + (PANEL_PADDING * 3) + 30

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

    y = y - PANEL_PADDING * 2
end

-- ============================================
-- Trim Display 함수들
-- ============================================

-- 트림 바 그리기 함수
function draw_trim_bar(x, y, value, label, percentage)
    -- 레이블과 퍼센트 표시
    draw_string(x, y, string.format("%s: %s", label, percentage), "white")

    local bar_y = y - 22

    -- 배경 (어두운 회색)
    glColor4f(0.2, 0.2, 0.2, 0.8)
    glRectf(x, bar_y, x + TRIM_BAR_WIDTH, bar_y + TRIM_BAR_HEIGHT)

    -- 테두리
    graphics.set_color(0.5, 0.5, 0.5, 0.8)
    graphics.draw_rectangle(x, bar_y, x + TRIM_BAR_WIDTH, bar_y + TRIM_BAR_HEIGHT)

    -- 중앙선 (흰색)
    local center_x = x + TRIM_BAR_WIDTH / 2
    graphics.set_color(1.0, 1.0, 1.0, 0.8)
    graphics.draw_line(center_x, bar_y, center_x, bar_y + TRIM_BAR_HEIGHT)

    -- 트림 인디케이터 위치 계산 (value는 -1.0 ~ +1.0 범위)
    local indicator_x = center_x + (value * TRIM_BAR_WIDTH / 2)

    -- 트림 인디케이터 색상 (중립 근처는 녹색, 그 외는 주황색)
    if math.abs(value) < 0.1 then
        glColor4f(0.0, 1.0, 0.0, 0.9) -- 녹색
    else
        glColor4f(1.0, 0.6, 0.0, 0.9) -- 주황색
    end

    -- 인디케이터 그리기 (세로 막대)
    glRectf(indicator_x - 3, bar_y - 5, indicator_x + 3, bar_y + TRIM_BAR_HEIGHT + 5)

    -- 인디케이터 테두리
    if math.abs(value) < 0.1 then
        graphics.set_color(0.5, 1.0, 0.5, 1.0)
    else
        graphics.set_color(1.0, 0.8, 0.3, 1.0)
    end
    graphics.draw_rectangle(indicator_x - 3, bar_y - 5, indicator_x + 3, bar_y + TRIM_BAR_HEIGHT + 5)
end

-- Trim Display 화면 그리기
function draw_trim_display()
    if not show_trim_display then
        return
    end

    local x = TRIM_X
    local y = TRIM_Y
    local content_x = x + 20

    -- 반투명 배경
    glColor4f(0, 0, 0, 0.7)
    glRectf(x - 10, y - TRIM_HEIGHT - 10, x + TRIM_WIDTH + 10, y + 10)

    -- 테두리
    graphics.set_color(0.5, 0.5, 0.5, 0.8)
    graphics.draw_rectangle(x - 10, y - TRIM_HEIGHT - 10, x + TRIM_WIDTH + 10, y + 10)

    -- 헤더
    set_color(COLOR_HEADER_BG)
    graphics.draw_rectangle(x - 10, y - HEADER_HEIGHT, x + TRIM_WIDTH + 10, y + 10)
    y = y - HEADER_HEIGHT + 7
    draw_string(content_x + 50, y, "TRIM DISPLAY", COLOR_HEADER_TEXT[1], COLOR_HEADER_TEXT[2], COLOR_HEADER_TEXT[3])
    y = y - PANEL_PADDING - 5

    -- 구분선
    y = y - SECTION_SPACING
    draw_separator(content_x, y, TRIM_WIDTH - 20)
    y = y - LINE_HEIGHT

    -- Pitch Trim (엘리베이터)
    local pitch_percent = string.format("%+6.1f%%", df_elevator_trim * 100)
    draw_trim_bar(content_x, y, df_elevator_trim, "PITCH", pitch_percent)

    -- Roll Trim (에일러론)
    y = y - 60
    local roll_percent = string.format("%+6.1f%%", df_aileron_trim * 100)
    draw_trim_bar(content_x, y, df_aileron_trim, "ROLL ", roll_percent)

    -- Yaw Trim (러더)
    y = y - 60
    local yaw_percent = string.format("%+6.1f%%", df_rudder_trim * 100)
    draw_trim_bar(content_x, y, df_rudder_trim, "YAW  ", yaw_percent)

    -- 하단 구분선
    y = y - 30
    draw_separator(content_x, y, TRIM_WIDTH - 20)

    -- 상세 수치 표시
    y = y - LINE_HEIGHT
    draw_string(content_x, y,
        string.format("P:%+.3f R:%+.3f Y:%+.3f",
            df_elevator_trim, df_aileron_trim, df_rudder_trim),
        "white")
end

-- ============================================
-- 메인 그리기 함수
-- ============================================

function draw_all_displays()
    -- OpenGL 상태 설정
    XPLMSetGraphicsState(0, 0, 0, 1, 1, 0, 0)

    -- Flight Info 그리기
    draw_flight_info()

    -- Trim Display 그리기
    draw_trim_display()
end

-- ============================================
-- 토글 함수들
-- ============================================

function toggle_flight_info()
    show_flight_info = not show_flight_info
    if show_flight_info then
        logMsg("Flight Information Display: ON")
    else
        logMsg("Flight Information Display: OFF")
    end
end

function toggle_trim_display()
    show_trim_display = not show_trim_display
    if show_trim_display then
        logMsg("Trim Display: ON")
    else
        logMsg("Trim Display: OFF")
    end
end

function toggle_all_displays()
    show_flight_info = not show_flight_info
    show_trim_display = show_flight_info
    if show_flight_info then
        logMsg("All Displays: ON")
    else
        logMsg("All Displays: OFF")
    end
end

-- ============================================
-- 초기화 및 콜백 등록
-- ============================================

-- 초기 데이터 업데이트
update_display_data()

-- 콜백 등록
do_often("update_display_data()")
do_every_draw("draw_all_displays()")

-- 메뉴에 매크로 추가
add_macro("Toggle Flight Info", "toggle_flight_info()")
add_macro("Toggle Trim Display", "toggle_trim_display()")
add_macro("Toggle All Displays", "toggle_all_displays()")

-- 커스텀 커맨드 생성
create_command("FlyWithLua/displays/toggle_flight_info", "Toggle Flight Information Display",
    "toggle_flight_info()", "", "")
create_command("FlyWithLua/displays/toggle_trim", "Toggle Trim Display",
    "toggle_trim_display()", "", "")
create_command("FlyWithLua/displays/toggle_all", "Toggle All Displays",
    "toggle_all_displays()", "", "")

-- 플러그인 로드 메시지
logMsg("========================================")
logMsg("Integrated Displays loaded successfully!")
logMsg("- Flight Information Display")
logMsg("- Trim Display")
logMsg("Use menu or assign keys to commands:")
logMsg("  FlyWithLua/displays/toggle_flight_info")
logMsg("  FlyWithLua/displays/toggle_trim")
logMsg("  FlyWithLua/displays/toggle_all")
logMsg("========================================")
