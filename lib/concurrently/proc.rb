module Concurrently
  if Object.const_defined? :MRUBY_VERSION
    # @api mruby_patches
    # @since 1.0.0
    #
    # mruby's Proc does not support instance variables. So, whe have to make
    # it a normal class that does not inherit from Proc :(
    class Proc; end
  else
    class Proc < ::Proc
      # @private
      # Calls the concurrent proc like a normal proc
      alias_method :__proc_call__, :call
    end
  end

  # @api public
  # @since 1.0.0
  #
  # @note Concurrent procs are **thread safe**.
  #
  # A `Concurrently::Proc` is like a regular Proc except its block of code is
  # evaluated concurrently. Its evaluation can wait for other stuff to happen
  # (e.g. result of another concurrent proc or readiness of an IO) without
  # blocking the execution of its thread.
  #
  # Errors raised inside concurrent procs are re-raised when getting their
  # result with {Evaluation#await_result}. They can also be watched by
  # registering callbacks for the `:error` event as shown in the example below.
  # This is useful as a central hook to all errors inside concurrent procs for
  # monitoring or logging purposes. Also, concurrent procs evaluated with
  # {Kernel#concurrently} resp. {Proc#call_and_forget} are run in the
  # background and will fail silently. The callbacks are the only way to be
  # notified about errors inside them.
  #
  # The callbacks can be registered for all procs or only for one specific
  # proc:
  #
  # @example Watching errors
  #   # Callbacks for all procs are registered for the `Concurrently::Proc` class:
  #   Concurrently::Proc.on(:error) do |error|
  #     puts "error in one of many procs: #{error}"
  #   end
  #
  #   concurrently do
  #     raise "eternal darkness"
  #   end
  #
  #   sunshine_proc = concurrent_proc do
  #     raise "eternal sunshine"
  #   end
  #
  #   # Callbacks for a single proc are registered for the instance:
  #   sunshine_proc.on(:error) do |error|
  #     puts "error in the sunshine proc: #{error}"
  #   end
  #
  #   # defer execution a little. This will make the concurrently block run in the
  #   # meantime.
  #   wait 0
  #   # the concurrently block will fail in the background and causes a printed
  #   # "error in one of many procs: eternal darkness"
  #
  #   sunshine_proc.call
  #   # prints "error in one of many procs: eternal sunshine"
  #   # prints "error in the sunshine proc: eternal sunshine"
  #   # raises RuntimeError: eternal sunshine
  class Proc
    include CallbacksAttachable

    # A new instance of {Proc}
    #
    # @param [Class] evaluation_class It can be given a custom class to create
    #   evaluation objects. This can be useful if all evaluations for this proc
    #   share some custom behavior and it makes sense to create a sub class of
    #   {Evaluation} for them.
    def initialize(evaluation_class = Evaluation)
      @evaluation_class = evaluation_class
    end

    # Evaluates the concurrent proc in a blocking manner.
    #
    # Evaluating the proc this way executes its block of code immediately
    # and blocks the current thread of execution until the result is available.
    #
    # @return [Object] the result of the evaluation.
    # @raise [Exception] if the evaluation raises an error.
    #
    # @example The proc can be evaluated without waiting
    #   add = concurrent_proc do |a, b|
    #     a + b
    #   end
    #   add.call 5, 8 # => 13
    #
    # @example The proc needs to wait to conclude evaluation
    #   time_in = concurrent_proc do |seconds|
    #     wait seconds
    #     Time.now
    #   end
    #
    #   Time.now.strftime('%H:%M:%S.%L')          # => "13:47:45.850"
    #   time_in.call(1.5).strftime('%H:%M:%S.%L') # => "13:47:47.351"
    def call(*args)
      case immediate_result = call_nonblock(*args)
      when Evaluation
        immediate_result.await_result
      else
        immediate_result
      end
    end

    alias [] call

    # Evaluates the concurrent proc in a non-blocking manner.
    #
    # Evaluating the proc this way executes its block of code immediately until
    # the result is available or the evaluation needs to wait.
    #
    # Dealing with this method is similar to dealing with `IO#*_nonblock`.
    #
    # @return [Object] the result of the evaluation if it can be executed
    #   without waiting.
    # @return [Evaluation] if the evaluation needs to wait.
    # @raise [Exception] if the evaluation raises an error.
    #
    # @example The proc can be evaluated without waiting
    #   add = concurrent_proc do |a, b|
    #     a + b
    #   end
    #
    #   case immediate_result = add.call_nonblock(5, 8)
    #   when Concurrently::Evaluation
    #     # won't happen here
    #   else
    #     immediate_result # => 13
    #   end
    #
    # @example The proc needs to wait to conclude evaluation
    #   time_in = concurrent_proc do |seconds|
    #     wait seconds
    #     Time.now
    #   end
    #
    #   Time.now.strftime('%H:%M:%S.%L') # => "15:18:42.439"
    #
    #   case immediate_result = time_in.call_nonblock(1.5)
    #   when Concurrently::Evaluation
    #     immediate_result.await_result.strftime('%H:%M:%S.%L') # => "15:18:44.577"
    #   else
    #     # won't happen here
    #   end
    def call_nonblock(*args)
      event_loop = EventLoop.current
      run_queue = event_loop.run_queue

      proc_fiber_pool = event_loop.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)
      evaluation_bucket = []

      result = begin
        previous_evaluation = run_queue.current_evaluation
        run_queue.current_evaluation = nil
        run_queue.evaluation_class = @evaluation_class
        proc_fiber.resume [self, args, evaluation_bucket]
      ensure
        run_queue.current_evaluation = previous_evaluation
        run_queue.evaluation_class = nil
      end

      case result
      when Evaluation
        # The proc fiber if the proc cannot be evaluated without waiting.
        # Inject the evaluation into it so it can be concluded later.
        evaluation_bucket << result
        result
      when Exception
        raise result
      else
        result
      end
    end

    # Evaluates the concurrent proc detached from the current execution thread.
    #
    # Evaluating the proc this way detaches the evaluation from the current
    # thread of execution and schedules its start during the next iteration of
    # the event loop.
    #
    # @return [Evaluation]
    #
    # @example
    #   add = concurrent_proc do |a, b|
    #     a + b
    #   end
    #   evaluation = add.call_detached 5, 8
    #   evaluation.await_result # => 13
    def call_detached(*args)
      event_loop = EventLoop.current
      proc_fiber_pool = event_loop.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)
      evaluation = @evaluation_class.new(proc_fiber)
      event_loop.run_queue.schedule_immediately evaluation, [self, args, [evaluation]]
      evaluation
    end

    # Fire and forget variation of {#call_detached}.
    #
    # Once called, there is no way to control the evaluation anymore. But,
    # because we save creating an {Evaluation} instance this is slightly faster
    # than {#call_detached}.
    #
    # To execute code this way you can also use the shortcut
    # {Kernel#concurrently}.
    #
    # @return [nil]
    #
    # @example
    #   add = concurrent_proc do |a, b|
    #     puts "detached!"
    #   end
    #   add.call_and_forget 5, 8
    #
    #   # we need to enter the event loop to see an effect
    #   wait 0 # prints "detached!"
    def call_and_forget(*args)
      event_loop = EventLoop.current
      proc_fiber_pool = event_loop.proc_fiber_pool
      proc_fiber = proc_fiber_pool.pop || Proc::Fiber.new(proc_fiber_pool)

      # run without creating an Evaluation object at first. It will be created
      # if the proc needs to wait for something.
      event_loop.run_queue.schedule_immediately proc_fiber, [self, args]

      nil
    end
  end
end