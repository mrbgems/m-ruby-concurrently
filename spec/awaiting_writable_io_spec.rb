describe "using #await_writable in concurrent procs" do
  let(:loop) { IOEventLoop.new }
  let(:concurrent_proc) { loop.concurrent_proc(&wait_proc) }

  let(:wait_proc) { proc do
    loop.await_writable writer
    @result = writer.write 'test'
  end }

  let(:pipe) { IO.pipe }
  let(:reader) { pipe[0] }
  let(:writer) { pipe[1] }

  # jam pipe: default pipe buffer size on linux is 65536
  before { writer.write('a' * 65536) }

  before { loop.concurrent_proc do
    reader.read 65536 # clears the pipe
  end }

  context "when originating inside a concurrently block" do
    subject { @result }
    before { loop.concurrently(&wait_proc) }

    # We need a reference concurrent block whose result we can await to
    # ensure we wait long enough for the concurrently block to finish.
    before { loop.concurrent_proc{ loop.wait 0.0001 }.await_result }

    it { is_expected.to be 4 }
  end

  context "when originating inside a concurrent proc" do
    subject { concurrent_proc.await_result }
    it { is_expected.to be 4 }
  end

  context "when originating outside a concurrent proc" do
    subject { wait_proc.call }
    it { is_expected.to be 4 }
  end

  describe "evaluating the concurrent proc while it is waiting" do
    subject { concurrent_proc.await_result }

    before do # make sure the concurrent proc is started before evaluating it
      concurrent_proc
    end

    before { loop.concurrent_proc do
      # cancel the concurrent proc  right away
      concurrent_proc.evaluate_to :intercepted

      # Wait after the reader is readable to make sure the concurrent proc
      # is not resumed then (i.e. watching the reader is properly cancelled)
      loop.wait 0.0001
    end.await_result }

    it { is_expected.to be :intercepted }
  end
end