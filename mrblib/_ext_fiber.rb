class Fiber
  def send_to_background!(event_loop)
    event_loop.resume
  end

  def send_to_foreground!(result = nil)
    Fiber.yield result # yields to the fiber from the event loop
  end
end