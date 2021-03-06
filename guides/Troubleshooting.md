# Troubleshooting

To get an idea about the inner workings of Concurrently have a look at the
[Flow of control][] section in the overview.

## An evaluation is scheduled but never run

Consider the following script:

```ruby
#!/bin/env ruby

concurrently do
  puts "I will be forgotten, like tears in the rain."
end

puts "Unicorns!"
```

Running it will only print:

```
Unicorns!
```

`concurrently{}` is a shortcut for `concurrent_proc{}.call_detached`
which in turn does not evaluate its code right away but schedules it to run
during the next iteration of the event loop. But, since the main evaluation did
not await anything the event loop has never been entered and the concurrent
evaluation has never been started.

A more subtle variation of this behavior occurs in the following scenario:

```ruby
#!/bin/env ruby

concurrently do
  puts "Unicorns!"
  wait 2
  puts "I will be forgotten, like tears in the rain."
end

wait 1
```

Running it will also only print:

```
Unicorns!
```

This time, the main evaluation does await something, namely the end of a one
second time frame. Because of this, the evaluation of the `concurrently` block
is indeed started and immediately waits for two seconds. After one second the
main evaluation is resumed and exits. The `concurrently` block is never awoken
again from its now eternal beauty sleep.

## A call is blocking the entire execution.

```ruby
#!/bin/env ruby

r,w = IO.pipe

concurrently do
  w.write 'Wake up!'
end

r.readpartial 32
```

Here, although we are practically waiting for `r` to be readable we do so in a
blocking manner (`IO#readpartial` is blocking). This brings the whole process
to a halt, the event loop will not be entered and the `concurrently` block will
not be run. It will not be written to the pipe which in turn creates a nice
deadlock.

You can use blocking calls to deal with I/O. But you should await readiness of
the IO before. If instead of just `r.readpartial 32` we write:

```ruby
r.await_readable
r.readpartial 32
```

we suspend the main evaluation, switch to the event loop which runs the
`concurrently` block and once there is something to read from `r` the main
evaluation is resumed.

This approach is not perfect. It is not very efficient if we do not need to
await readability at all and could read from `r` immediately. But it is still
better than blocking everything by default.

The most efficient way is doing a non-blocking read and only await readability
if it is not readable:

```ruby
begin
  r.read_nonblock 32
rescue IO::WaitReadable
  r.await_readable
  retry
end
```

## The event loop is jammed by too many or too expensive evaluations

Let's talk about a concurrent evaluation with an infinite loop:

```ruby
evaluation = concurrently do
  loop do
    puts "To infinity! And beyond!"
  end
end

concurrently do
  evaluation.conclude_to :cancelled
end
```

When the loop evaluation is scheduled to run it runs and runs and runs and
never finishes. The event loop is never entered again and the other evaluation
concluding the evaluation is never started.

A less extreme example is something like:

```ruby
concurrently do
  loop do
    wait 0.1
    puts "timer triggered at: #{Time.now.strftime('%H:%M:%S.%L')}"
    concurrently do
      sleep 1 # defers the entire event loop
    end
  end
end.await_result

# => timer triggered at: 16:08:17.704
# => timer triggered at: 16:08:18.705
# => timer triggered at: 16:08:19.705
# => timer triggered at: 16:08:20.705
# => timer triggered at: 16:08:21.706
```

This is a timer that is supposed to run every 0.1 seconds and creates another
evaluation that takes a full second to complete. But since it takes so long the
loop also only gets a chance to run every second leading to a delay of 0.9
seconds between the time the timer is supposed to run and the time it actually
ran.

## Forking the process causes issues

A fork inherits the main thread and with it the event loop with all its
internal state from the parent. This is a problem since fibers created in
the parent process cannot be resume in the forked process. Trying to do so
raises a "fiber called across stack rewinding barrier" error. Also, we
probably do not want to continue watching the parent's IOs.

To fix this, the event loop has to be [reinitialized][Concurrently::EventLoop#reinitialize!]
directly after forking:

```ruby
fork do
  Concurrently::EventLoop.current.reinitialize!
  # ...
end

# ...
```

While reinitializing the event loop clears its list of IOs watched for
readiness, the IOs themselves are left untouched. You are responsible for
managing IOs (e.g. closing them).

## Errors tear down the event loop
  
Every evaluation rescues the following errors: `NoMemoryError`, `ScriptError`,
`SecurityError`, `StandardError` and `SystemStackError`. These are all errors
that should not have an immediate influence on other evaluations or the
application as a whole. They will be rescued and do not leak to the event loop
and thus will not tear it down.

All other errors happening during an evaluation *will* tear down the event
loop. These error types are: `SignalException`, `SystemExit` and the general
`Exception`. In such a case the event loop exits by re-raising the causing
error.

If your application rescues the error when the event loop is teared down
and continues running (irb does this, for example) it will do so with a
[reinitialized event loop][Concurrently::EventLoop#reinitialize!].

## Using Plain Fibers

In principle, you can safely use plain ruby fibers alongside concurrent procs.
Just make sure you are exclusively operating on these fibers to not
accidentally interfere with the fibers managed by Concurrently. Be
especially careful with `Fiber.yield` and `Fiber.current` inside a concurrent
evaluation.

## Fiber-local variables are treated as thread-local

In Ruby, `Thread#[]`, `#[]=`, `#key?` and `#keys` operate on variables local
to the current fiber and not the current thread. This behavior is not noticed
most of the time because people rarely work explicitly with fibers. Then, each
thread has exactly one fiber and thread-local and fiber-local variables behave
the same way.

But if fibers come into play and a single thread starts switching between them,
these methods cause errors instantly. Since Concurrently is built upon fibers
it needs to sail around those issues. Most of the time the real intention is to
set variables local to the current thread; just like the receiver of said
methods suggests. For this reason, `Thread#[]`, `#[]=`, `#key?` and `#keys` are
boldly redirected to `Thread#thread_variable_get`, `#thread_variable_set`,
`#thread_variable?` and `#thread_variables`.

If you belong to the ones using fibers with variables indeed intended to be
fiber-local, you have two options: 1) Don't use Concurrently or 2) change all
these fibers to concurrent procs and use their evaluation's [data store]
[Concurrently::Proc::Evaluation#brackets] to store the variables.

```ruby
fiber = Fiber.new do
  Thread.current[:key] = "I intend to be fiber-local!"
  puts Thread.current[:key]
end

fiber.resume
```

becomes:

```ruby
conproc = concurrent_proc do
  Concurrently::Evaluation.current[:key] = "I'm evaluation-local!"
  puts Concurrently::Evaluation.current[:key]
end

conproc.call
```

## FiberError: mprotect failed

Each concurrent evaluation runs in a fiber. If your application creates more
concurrent evaluations than are concluded, more and more fibers need to be
created. At some point the creation of additional fibers fails with
"FiberError: mprotect failed". This is caused by hitting the limit for the the
number of distinct memory maps a process can have. The corresponding linux
kernel parameter is `/proc/sys/vm/max_map_count` and has default value of 64k.
Each fiber creates two memory maps leading to a default maximum of around 30k
fibers. To create more fibers the `max_map_count` needs to be increased.

```
$ sysctl -w vm.max_map_count=65530
```

See also: https://stackoverflow.com/a/11685165/3323185

[Flow of control]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/file/guides/Overview.md#Flow+of+control
[Concurrently::EventLoop#reinitialize!]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop#reinitialize!-instance_method
[Concurrently::Error]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Error
[Concurrently::Proc::Evaluation#brackets]: http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#%5B%5D-instance_method