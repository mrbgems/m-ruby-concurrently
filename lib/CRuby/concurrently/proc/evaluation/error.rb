module Concurrently
  class Proc::Evaluation
    module RescueableError
      # Ruby has additional error classes
      [SecurityError].each do |error_class|
        append_features error_class
      end
    end
  end
end
