-- Trim Display for X-Plane using FlyWithLua Graphics
-- graphics 라이브러리를 이용한 실시간 트림 디스플레이

-- DataRef 정의
dataref("df_elevator_trim", "sim/cockpit2/controls/elevator_trim")
dataref("df_aileron_trim", "sim/cockpit2/controls/aileron_trim")
dataref("df_rudder_trim", "sim/cockpit2/controls/rudder_trim")

-- 디스플레이 설정
local display_x = SCREEN_WIDTH - 320
local display_y = SCREEN_HEIGHT - 250
local display_width = 300
local display_height = 230
local bar_width = 260
local bar_height = 20

-- 표시 여부
local show_display = true

-- 트림 바 그리기 함수
function draw_trim_bar(x, y, value, label, percentage)
    -- 레이블과 퍼센트 표시
    draw_string(x, y, string.format("%s: %s", label, percentage), "white")
    
    local bar_y = y - 22
    
    -- 배경 (어두운 회색) - glRectf 사용
    glColor4f(0.2, 0.2, 0.2, 0.8)
    glRectf(x, bar_y, x + bar_width, bar_y + bar_height)
    
    -- 테두리
    graphics.set_color(0.5, 0.5, 0.5, 0.8)
    graphics.draw_rectangle(x, bar_y, x + bar_width, bar_y + bar_height)
    
    -- 중앙선 (흰색)
    local center_x = x + bar_width / 2
    graphics.set_color(1.0, 1.0, 1.0, 0.8)
    graphics.draw_line(center_x, bar_y, center_x, bar_y + bar_height)
    
    -- 트림 인디케이터 위치 계산 (value는 -1.0 ~ +1.0 범위)
    local indicator_x = center_x + (value * bar_width / 2)
    
    -- 트림 인디케이터 색상 (중립 근처는 녹색, 그 외는 주황색)
    if math.abs(value) < 0.1 then
        glColor4f(0.0, 1.0, 0.0, 0.9)  -- 녹색
    else
        glColor4f(1.0, 0.6, 0.0, 0.9)  -- 주황색
    end
    
    -- 인디케이터 그리기 (세로 막대) - glRectf 사용
    glRectf(indicator_x - 3, bar_y - 5, indicator_x + 3, bar_y + bar_height + 5)
    
    -- 인디케이터 테두리
    if math.abs(value) < 0.1 then
        graphics.set_color(0.5, 1.0, 0.5, 1.0)
    else
        graphics.set_color(1.0, 0.8, 0.3, 1.0)
    end
    graphics.draw_rectangle(indicator_x - 3, bar_y - 5, indicator_x + 3, bar_y + bar_height + 5)
end

-- 메인 그리기 함수
function draw_trim_display()
    if not show_display then
        return
    end
    
    -- OpenGL 상태 설정
    XPLMSetGraphicsState(0, 0, 0, 1, 1, 0, 0)
    
    -- 반투명 배경 - glRectf 사용
    glColor4f(0, 0, 0, 0.7)
    glRectf(display_x - 10, display_y - display_height - 10, 
            display_x + display_width + 10, display_y + 10)
    
    -- 테두리
    graphics.set_color(0.5, 0.5, 0.5, 0.8)
    graphics.draw_rectangle(display_x - 10, display_y - display_height - 10, 
                           display_x + display_width + 10, display_y + 10)
    
    -- 제목
    draw_string(display_x + 70, display_y, "TRIM DISPLAY", "white")
    
    -- 구분선
    graphics.set_color(0.5, 0.5, 0.5, 0.8)
    graphics.draw_line(display_x, display_y - 20, display_x + display_width, display_y - 20)
    
    -- Pitch Trim (엘리베이터)
    local pitch_percent = string.format("%+6.1f%%", df_elevator_trim * 100)
    draw_trim_bar(display_x + 20, display_y - 40, df_elevator_trim, "PITCH", pitch_percent)
    
    -- Roll Trim (에일러론)
    local roll_percent = string.format("%+6.1f%%", df_aileron_trim * 100)
    draw_trim_bar(display_x + 20, display_y - 100, df_aileron_trim, "ROLL ", roll_percent)
    
    -- Yaw Trim (러더)
    local yaw_percent = string.format("%+6.1f%%", df_rudder_trim * 100)
    draw_trim_bar(display_x + 20, display_y - 160, df_rudder_trim, "YAW  ", yaw_percent)
    
    -- 하단 구분선
    graphics.set_color(0.5, 0.5, 0.5, 0.8)
    graphics.draw_line(display_x, display_y - 190, display_x + display_width, display_y - 190)
    
    -- 상세 수치 표시
    draw_string(display_x + 20, display_y - 210, 
                string.format("P:%+.3f R:%+.3f Y:%+.3f", 
                             df_elevator_trim, df_aileron_trim, df_rudder_trim),
                "white")
end

-- 매 프레임마다 호출
do_every_draw("draw_trim_display()")

-- 토글 커맨드 생성
function toggle_trim_display()
    show_display = not show_display
    if show_display then
        logMsg("Trim Display: ON")
    else
        logMsg("Trim Display: OFF")
    end
end

-- 메뉴에 매크로 추가
add_macro("Toggle Trim Display", "toggle_trim_display()")

-- 커스텀 커맨드 생성
create_command("FlyWithLua/trim_display/toggle", "Toggle Trim Display", 
               "toggle_trim_display()", "", "")

-- 플러그인 로드 메시지
logMsg("========================================")
logMsg("Trim Display loaded successfully!")
logMsg("Use 'Toggle Trim Display' from menu")
logMsg("or assign key to FlyWithLua/trim_display/toggle")
logMsg("========================================")