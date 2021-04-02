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
    puts File.read("#{TASK_DIR}/mantis.conf")
    process = Process.new "mantis", error: STDERR, output: STDOUT, args: [
      "-Duser.home=#{TASK_DIR}",
      "-Dconfig.file=mantis.conf"
    ]

    wait_for_tip process
  ensure
    process.kill(Signal::INT) if process && process.exists?
  end

  def wait_for_tip(process : Process)
    params = HTTP::Params.encode({"query" => %(max(app_sync_block_number_gauge_gauge{namespace="#{tag}"}[1h]))})
    block_height_url = "#{ENV["MONITORING_URL"]}?" + params

    old_height = 0
    current_height = 0
    loop do
      raise "mantis died #{process.wait.exit_status}" unless process.exists?

      response = HTTP::Client.get(block_height_url)
      if response.status_code != 200
        puts "couldn't fetch block height from VictoriaMetrics"
        pp! response
        next
      end

      body = HTTP::Client.get(block_height_url).body
      max_height = BlockHeight.from_json(response.body).data.result.first.value.last.to_s.to_i64
      old_height = current_height
      current_height = fetch_current_height

      pp! max_height, current_height, old_height

      if old_height == current_height && current_height > 0
        raise "Wasn't able to increase block height, abandoning backup"
      end

      return if current_height >= (max_height - 2)

      sleep 30
    end
  end

  def fetch_current_height : Int64
    prometheus_url = "http://127.0.0.1:#{ENV["NOMAD_PORT_metrics"]}"
    response = HTTP::Client.get(prometheus_url)
    if response.status_code == 200 && (body = response.body)
      if match = body.match(/^app_sync_block_number_gauge\s+(?<block>\d+)/m)
        match[1].to_i64
      else
        0i64
      end
    else
      pp! response
      0i64
    end
  rescue ex
    pp! ex
    0i64
  end

  def backup
    FileUtils.mkdir_p "/tmp"

    Process.run "restic", output: STDOUT, error: STDERR, args: [
      "backup", "--verbose", "--tag", tag, "#{TASK_DIR}/mantis"
    ]

    Process.run "restic", output: STDOUT, error: STDERR, args: [
      "forget", "--prune", "--keep-last", "100", "--group-by", "tag"
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
