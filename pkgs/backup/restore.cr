class Restore
  TASK_DIR = ENV["NOMAD_TASK_DIR"]

  property tag : String

  def initialize(@tag)
  end

  def run
    Process.run "restic", error: STDERR, output: STDOUT, args: [
      "restore", "latest",
      "--tag", tag,
      "--target", "#{TASK_DIR}/db"
    ]
  end
end
