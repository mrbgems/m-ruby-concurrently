# Release Notes

## 1.2.0 (2017-12-12)

### Added [Concurrently::Debug](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Debug) interface 
* [.enable](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Debug#enable-class_method)

### Extended [Concurrently::Proc](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc) interface
* [.error_log_output=](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#error_log_output=-class_method)

## 1.1.0 (2017-07-10)

### Improvements
* Improved error reporting
* Improved benchmarks and profiling and made them work for mruby
* Improved documentation
* Improved overall performance

### Extended [IO](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO) interface
* [#await_read](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_read-instance_method)
* [#await_written](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_written-instance_method)

### Extended [Kernel](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel) interface
* [#await_fastest](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#await_fastest-instance_method)

## 1.0.0 (2017-06-26)

### Added Support for
* Ruby 2.2.7+
* mruby 1.3

### Extended [IO](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO) interface
* [#await_readable](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_readable-instance_method)
* [#await_writable](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#await_writable-instance_method)
* [#concurrently_read](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#concurrently_read-instance_method)
* [#concurrently_write](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/IO#concurrently_write-instance_method)

### Extended [Kernel](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel) interface
* [#concurrently](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrently-instance_method)
* [#concurrent_proc](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#concurrent_proc-instance_method)
* [#wait](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#wait-instance_method)
* [#await_resume!](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Kernel#await_resume!-instance_method)

### Added (Root) Evaluation ([Concurrently::Evaluation](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation))
* [.current](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation#current-class_method)
* [#waiting?](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation#waiting%3F-instance_method)
* [#resume!](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation#resume!-instance_method)
 
### Added Concurrent Proc ([Concurrently::Proc](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc))
* [#call, #[]](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call-instance_method)
* [#call_nonblock](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_nonblock-instance_method)
* [#call_detached](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_detached-instance_method)
* [#call_and_forget](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc#call_and_forget-instance_method)
 
### Added Proc Evaluation ([Concurrently::Proc::Evaluation](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation))
* [#await_result](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#await_result-instance_method)
* [#conclude_to](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#conclude_to-instance_method)
* [#concluded?](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#concluded%3F-instance_method)
* [#data](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Proc/Evaluation#data-instance_method)

### Added Event Loop ([Concurrently::EventLoop](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop))
* [.current](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop#current-class_method)
* [#lifetime](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop#lifetime-instance_method)
* [#reinitialize!](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/EventLoop#reinitialize!-instance_method)

### Added Errors
* [Concurrently::Error](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Error)
* [Concurrently::Evaluation::Error](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation/Error)
* [Concurrently::Evaluation::TimeoutError](http://www.rubydoc.info/github/christopheraue/m-ruby-concurrently/Concurrently/Evaluation/TimeoutError)


## 0.0.0 (~13.8 billion years ago)