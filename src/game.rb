
class Game
  GRID_ROWS=6
  GRID_COLS=5
  KB_OFFSET_X = -2
  KB_OFFSET_Y = 9

  attr_reader :screen, :dc2d_class, :controller
  attr_accessor :cursor_pos, :prev_cursor_pos
  def initialize(screen_class, dc2d_class)
    @screen = screen_class.new(dc2d_class)
    @dc2d_class = dc2d_class
    @controller = Controller.new(dc2d_class)
    @x, @y = 0, 0
    @prev_cursor_pos = @cursor_pos = { x: 0, y: 0 }
  end

  def main
    while true do
      game_loop
    end
  end

  def game_loop
    running = true
    screen.draw_background
    draw_grid
    draw_qwerty

    previous_btn_state = dc2d_class::get_button_state
    while running do
      dc2d_class::waitvbl
      current_btn_state = dc2d_class::get_button_state
      draw_cursor

      if(dpad_any_down?(previous_btn_state, current_btn_state))
        erase_cursor
        prev_cursor_pos = cursor_pos
        move_cursor(previous_btn_state, current_btn_state)
      end


      puts "A pressed" if(controller.a_down?(previous_btn_state, current_btn_state))
      puts "B pressed" if(controller.b_down?(previous_btn_state, current_btn_state))
      puts "START pressed" if(controller.start_down?(previous_btn_state, current_btn_state))

      previous_btn_state = current_btn_state
    end
  end

  def move_cursor(previous_btn_state, current_btn_state)
    cursor_pos[:x] = cursor_pos[:x] + 1 if controller.right_down?(previous_btn_state, current_btn_state) && valid_cursor_pos?(cursor_pos[:x] + 1, cursor_pos[:y])
    cursor_pos[:x] = cursor_pos[:x] - 1 if controller.left_down?(previous_btn_state, current_btn_state) && valid_cursor_pos?(cursor_pos[:x] - 1, cursor_pos[:y])
    cursor_pos[:y] = cursor_pos[:y] + 1 if controller.down_down?(previous_btn_state, current_btn_state) && valid_cursor_pos?(cursor_pos[:x], cursor_pos[:y] + 1)
    cursor_pos[:y] = cursor_pos[:y] - 1 if controller.up_down?(previous_btn_state, current_btn_state) && valid_cursor_pos?(cursor_pos[:x], cursor_pos[:y] - 1)
  end

  def valid_cursor_pos?(x, y)
    x >= 0 && y >= 0 && QWERTY[y] && QWERTY[y][x]
  end

  def dpad_any_down?(previous_btn_state, current_btn_state)
    controller.right_down?(previous_btn_state, current_btn_state) ||
      controller.left_down?(previous_btn_state, current_btn_state) ||
      controller.down_down?(previous_btn_state, current_btn_state) ||
      controller.up_down?(previous_btn_state, current_btn_state)
  end

  def erase_cursor
    screen.erase_cursor(prev_cursor_pos[:x] + KB_OFFSET_X, prev_cursor_pos[:y] + KB_OFFSET_Y)
  end

  def draw_cursor
    screen.draw_cursor(cursor_pos[:x] + KB_OFFSET_X, cursor_pos[:y] + KB_OFFSET_Y)
  end

  def draw_grid
    (0..GRID_ROWS-1).each { |y|
      (0..GRID_COLS-1).each { |x|
        screen.draw_boxed_letter(" ", x, y)
      }
    }
  end

  QWERTY=[
    ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
    ["A", "S", "D", "F", "G", "H", "J", "K", "L", "<"],
    ["Z", "X", "C", "V", "B", "N", "M"]
  ]
  def draw_qwerty
    QWERTY.each_with_index { |qwerty_row, i|
      qwerty_row.each_with_index { |character, j|
        screen.draw_boxed_letter(character, j + KB_OFFSET_X, i + KB_OFFSET_Y)
      }
    }
  end
end

class Controller
  attr_reader :dc2d_class

  def initialize(dc2d)
    @dc2d_class = dc2d
  end

  def a_down?(previous_btn_state, current_btn_state)
    !dc2d_class::btn_a?(previous_btn_state) && dc2d_class::btn_a?(current_btn_state)
  end

  def b_down?(previous_btn_state, current_btn_state)
    !dc2d_class::btn_b?(previous_btn_state) && dc2d_class::btn_b?(current_btn_state)
  end

  def up_down?(previous_btn_state, current_btn_state)
    !dc2d_class::dpad_up?(previous_btn_state) && dc2d_class::dpad_up?(current_btn_state)
  end

  def down_down?(previous_btn_state, current_btn_state)
    !dc2d_class::dpad_down?(previous_btn_state) && dc2d_class::dpad_down?(current_btn_state)
  end

  def left_down?(previous_btn_state, current_btn_state)
    !dc2d_class::dpad_left?(previous_btn_state) && dc2d_class::dpad_left?(current_btn_state)
  end

  def right_down?(previous_btn_state, current_btn_state)
    !dc2d_class::dpad_right?(previous_btn_state) && dc2d_class::dpad_right?(current_btn_state)
  end

  def start_down?(previous_btn_state, current_btn_state)
    !dc2d_class::btn_start?(previous_btn_state) && dc2d_class::btn_start?(current_btn_state)
  end
end

class Screen
  LEFT_SPACE_PX=260
  TOP_SPACE_PX=20

  attr_reader :dc2d_class

  def initialize(dc2d_class)
    @dc2d_class = dc2d_class
  end

  def draw_boxed_letter(letter, x, y)
    draw_letterbox(x, y)
    dc2d_class::draw_letter_640(letter[0..0], x*23+LEFT_SPACE_PX+4, y*34+TOP_SPACE_PX+5, 0, 0, 0, 0)
  end

  # x, y are grid positions, not pixels
  def draw_letterbox(x, y)
    dc2d_class::draw_rectangle_640(x*23+LEFT_SPACE_PX, y*34+TOP_SPACE_PX, 20, 32, 0, 0, 0)
  end

  def fill_square(x, y, r, g, b)
    dc2d_class::fill20x20_640(x*20+LEFT_SPACE_PX, y*20+TOP_SPACE_PX, r, g, b)
  end

  def draw_background
    dc2d_class::fill_rectangle_640(0, 0, 640, 480, 240, 240, 240)
  end

  def erase_cursor(x, y)
    dc2d_class::draw_rectangle_640(x*23+LEFT_SPACE_PX-1, y*34+TOP_SPACE_PX-1, 22, 34, 240, 240, 240)
  end

  def draw_cursor(x, y)
    dc2d_class::draw_rectangle_640(x*23+LEFT_SPACE_PX-1, y*34+TOP_SPACE_PX-1, 22, 34, 0, 0, 255)
  end
end
