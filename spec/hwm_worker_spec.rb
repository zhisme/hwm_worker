RSpec.describe HwmWorker do
  it "has a version number" do
    expect(HwmWorker::VERSION).not_to be nil
  end

  it "loads the module successfully" do
    expect(HwmWorker).to be_a(Module)
  end
end
