begin
  Game.new(Screen, Dc2d).main
rescue => ex
  # Note backtrace is only available when you pass -g to mrbc at compile time
  p ex.backtrace
  p ex.inspect
  raise ex
end
