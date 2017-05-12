class IOEventLoop
  class ConcurrentBlock < Fiber
    def initialize(loop)
      super() do |future, block|
        # The fiber is started right away after creation to inject the future
        # and then yields back to where it was created.
        start_argument = Fiber.yield

        if start_argument == self
          # If we are given with this very fiber when starting the fiber for
          # real it means this fiber is already evaluated right now before its
          # start. In this case just yield back to the cancelling fiber.
          Fiber.yield

          # When this fiber is started when it is the next on schedule it will
          # just finish without running the block.
        else
          begin
            result = block.call
            future.evaluate_to result if future
          rescue Exception => e
            loop.trigger :error, e
            future.evaluate_to e if future
          end

          # yields back to the event loop fiber from where it was started
        end
      end
    end

    def cancel
      if Fiber.current != self
        # Cancel fiber by resuming it with itself as argument
        resume self
      end
      :cancelled
    end
  end
end