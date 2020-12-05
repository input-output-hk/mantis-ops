require "file_utils"

class Backup
  TASK_DIR = ENV["NOMAD_TASK_DIR"]

  property tag : String

  def initialize(@tag)
  end

  def run
    sync
    backup
  end

  def sync
    process = Process.new "mantis", error: STDERR, output: STDOUT, args: [
      "-Duser.home", TASK_DIR,
      "-Dconfig.file", "#{TASK_DIR}/mantis.conf"
    ]

    wait_for_tip
  ensure
    Process.kill Signal::INT, process.pid if process && process.exists?
  end

  def wait_for_tip
    params = HTTP::Params.encode({"query" => "max(app_sync_block_number_gauge_gauge)"})
    block_height_url = "#{ENV["MONITORING_URL"]}?" + params
    prometheus_url = "http://127.0.0.1:#{ENV["NOMAD_PORT_metrics"]}"

    loop do
      pp! block_height_url, prometheus_url

      response = HTTP::Client.get block_height_url
      if response.status_code != 200
        puts "couldn't fetch block height from VictoriaMetrics"
        pp! response
        next
      end

      body = HTTP::Client.get(block_height_url).body
      max_height = BlockHeight.from_json(response.body).data.result.first.value.last.to_s.to_i64

      pp! max_height

      body = HTTP::Client.get(prometheus_url).body
      current_height = body[/^app_sync_block_number_gauge\s+(\d+)/, 1].to_i64

      pp! current_height

      return if current_height >= (max_height - 2)

      sleep 30
    end
  end

  def backup
    FileUtils.mkdir_p "/tmp"

    Process.run "restic", output: STDOUT, error: STDERR, args: [
      "backup", "--verbose", "--tag", tag, "#{TASK_DIR}/db"
    ]

    Process.run "restic", output: STDOUT, error: STDERR, args: [
      "forget", "--prune", "--keep-last", "100"
    ]
  end
end

class BlockHeight
  include JSON::Serializable

  property status : String

  property data : Data
end

class Data
  include JSON::Serializable

  @[JSON::Field(key: "resultType")]
  property result_type : String

  property result : Array(Result)
end

class Result
  include JSON::Serializable

  property value : Array(ValueElement)
end

alias ValueElement = Int32 | String
