shared_examples_for "#resume!" do
  before { concurrent_proc do
    @resume_result = evaluation.resume! *result
  end.call_nonblock }

  let(:result) { nil }
  after { expect(@resume_result).to be :resumed }

  context "when given no result" do
    let(:result) { nil }
    it { is_expected.to eq result }
  end

  context "when given a result" do
    let(:result) { :result }
    it { is_expected.to eq result }
  end

  context "if it has already been manually scheduled to be resumed" do
    subject { evaluation.resume! }
    it { is_expected.to raise_error Concurrently::Evaluation::Error, "already scheduled to resume" }
  end
end