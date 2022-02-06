
class Game
  KB_OFFSET_X = -2
  KB_OFFSET_Y = 9
  WORD_LENGTH = 5
  MAX_ATTEMPTS = 6

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
    buffers = []
    current_buffer = ""
    won_game = false
    answer = "mruby"

    previous_btn_state = dc2d_class::get_button_state
    while running do
      dc2d_class::waitvbl
      screen.draw_buffer(current_buffer, buffers.size)
      current_btn_state = dc2d_class::get_button_state
      draw_cursor

      # Moving cursor?
      if(dpad_any_down?(previous_btn_state, current_btn_state))
        erase_cursor
        prev_cursor_pos = cursor_pos
        move_cursor(previous_btn_state, current_btn_state)
      end

      # Letter selected?
      if(controller.a_down?(previous_btn_state, current_btn_state))
        current_letter = QWERTY[cursor_pos[:y]][cursor_pos[:x]]
        if(current_letter == "<")
          current_buffer.chop!
        elsif(current_letter == " ")
          if(current_buffer.size == WORD_LENGTH && buffers.size < MAX_ATTEMPTS)
            won_game = true if(current_buffer.downcase == answer.downcase)
            screen.draw_coloured_buffer(current_buffer, buffers.size, answer)
            buffers.push(current_buffer)
            draw_qwerty(buffers, answer)
            current_buffer = ""
          end
        else
          current_buffer.concat(current_letter) if current_buffer.size < WORD_LENGTH
        end
      end

      previous_btn_state = current_btn_state

      running = false if won_game || buffers.size == MAX_ATTEMPTS
    end

    if won_game
      screen.you_win
    else
      screen.game_over
    end

    waiting = true
    previous_btn_state = dc2d_class::get_button_state
    while waiting do
      dc2d_class::waitvbl
      current_btn_state = dc2d_class::get_button_state
      waiting = false if controller.a_down?(previous_btn_state, current_btn_state)
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
    (0..MAX_ATTEMPTS-1).each { |y|
      (0..WORD_LENGTH-1).each { |x|
        screen.draw_blank_letterbox(x, y)
      }
    }
  end

  QWERTY=[
    ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
    ["A", "S", "D", "F", "G", "H", "J", "K", "L", "<"],
    ["Z", "X", "C", "V", "B", "N", "M", " "]
  ]
  def draw_qwerty(buffers = [], answer = "")
    QWERTY.each_with_index { |qwerty_row, i|
      qwerty_row.each_with_index { |character, j|
        # for each character
        colours = buffers.map { |guess|
          guess.split('').each_with_index.map { |x, i|
            if x == character
              get_bg_colour(x, i, answer)
            else
              :none
            end
          }
        }.flatten

        colour = if colours.any? { |c| c == :green }
          :green
        elsif colours.any? { |c| c == :yellow }
          :yellow
        elsif buffers.flatten.join('').split('').any? { |ch| ch == character }
          :grey
        else
          :none
        end

        puts "char: #{character}, colour: #{colour}"

        bg_r, bg_g, bg_b = rgb(colour)
        r, g, b = 0, 0, 0
        r, g, b = 240, 240, 240 unless colour == :none

        screen.draw_coloured_boxed_letter(character,  j + KB_OFFSET_X, i + KB_OFFSET_Y, r, g, b, bg_r, bg_g, bg_b)
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

def rgb(colour_name)
  if colour_name == :green
    return 106, 170, 100
  elsif colour_name == :yellow
    return 201, 180, 88
  elsif colour_name == :grey
    return 120, 124, 126
  elsif colour_name = :none
    return 240, 240, 240
  end
end

def get_bg_colour(character, index, answer)
  puts "answer: #{answer}, character: #{character}, index: #{index}"
  if(character.downcase == answer[index].downcase)
    :green
  elsif contains?(answer.downcase, character.downcase)
    :yellow
  else
    :grey
  end
end

def contains?(answer, character)
  answer.split('').each { |c|
    return true if c == character
  }
  return false
end

class Screen
  LEFT_SPACE_PX=260
  TOP_SPACE_PX=20

  attr_reader :dc2d_class

  def initialize(dc2d_class)
    @dc2d_class = dc2d_class
  end

  def draw_buffer(buffer, y_idx)
    render_buffer(buffer, y_idx)
    render_trailing_space(buffer.size, y_idx)
  end

  def render_trailing_space(buffsize, y_idx)
    (buffsize..4).each { |x| draw_blank_letterbox(x, y_idx) }
  end

  def render_buffer(buffer, y_idx)
    buffer.split('').each_with_index { |c, idx|
      draw_boxed_letter(c, idx, y_idx)
    }
  end

  def draw_coloured_buffer(buffer, y_idx, answer)
    render_coloured_buffer(buffer, y_idx, answer)
  end

  def render_coloured_buffer(buffer, y_idx, answer)
    buffer.split('').each_with_index { |c, idx|
      r, g, b = rgb(get_bg_colour(c, idx, answer))
      puts("colour: #{r}, #{g}, #{b}")
      draw_coloured_boxed_letter(c, idx, y_idx, 240, 240, 240, r, g, b)
    }
  end

  def render_buffer(buffer, y_idx)
    buffer.split('').each_with_index { |c, idx|
      draw_boxed_letter(c, idx, y_idx)
    }
  end

  def draw_coloured_boxed_letter(letter, x, y, r, g, b, bg_r, bg_g, bg_b)
    draw_filled_letterbox(x, y, bg_r, bg_g, bg_b)
    dc2d_class::draw_string_640(letter[0..0], x*23+LEFT_SPACE_PX+4, y*34+TOP_SPACE_PX+5, r, g, b, 0)
  end

  def draw_boxed_letter(letter, x, y)
    draw_letterbox(x, y)
    dc2d_class::draw_string_640(letter[0..0], x*23+LEFT_SPACE_PX+4, y*34+TOP_SPACE_PX+5, 0, 0, 0, 0)
  end

  def draw_filled_letterbox(x, y, r, g, b)
    dc2d_class::fill_rectangle_640(x*23+LEFT_SPACE_PX, y*34+TOP_SPACE_PX, 18, 30, r, g, b)
    draw_letterbox(x, y)
  end

  def draw_blank_letterbox(x, y)
    dc2d_class::fill_rectangle_640(x*24+LEFT_SPACE_PX, y*33+TOP_SPACE_PX, 18, 30, 240, 240, 240)
    draw_letterbox(x, y)
  end

  # x, y are grid positions, not pixels
  def draw_letterbox(x, y)
    dc2d_class::draw_rectangle_640(x*23+LEFT_SPACE_PX, y*34+TOP_SPACE_PX, 20, 32, 0, 0, 0)
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

  def you_win
    dc2d_class::fill_rectangle_640(150, 150, 340, 180, 16, 160, 16)
    dc2d_class::draw_string_640("You Win!", 248, 224, 255, 255, 255, 0)
  end

  def game_over
    dc2d_class::fill_rectangle_640(150, 150, 340, 180, 16, 16, 16)
    dc2d_class::draw_string_640("Game Over!", 240, 224, 255, 255, 255, 0)
  end
end
