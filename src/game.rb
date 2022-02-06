
class Game
  attr_reader :screen, :dc2d_class
  def initialize(screen_class, dc2d_class)
    @screen = screen_class.new(dc2d_class)
    @dc2d_class = dc2d_class
  end

  def main
    while true do
      game_loop
    end
  end

  def game_loop
    running = true
    screen.draw_background
    while running do
      screen.draw_square(10, 10, 255, 255, 0)
      dc2d_class::waitvbl
    end
  end
end

class Screen
  LEFT_SPACE_PX=260
  TOP_SPACE_PX=20

  attr_reader :dc2d_class

  def initialize(dc2d_class)
    @dc2d_class = dc2d_class
  end

  def draw_square(x, y, r, g, b)
    dc2d_class::draw20x20_640(x*20+LEFT_SPACE_PX, y*20+TOP_SPACE_PX, r, g, b)
  end

  def draw_background
    dc2d_class::draw_rectangle_640(0, 0, 640, 480, 240, 240, 240)
  end
end
