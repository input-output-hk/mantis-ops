require "json"
require "http/client"
require "option_parser"

enum Action
  Backup
  Restore
end

action = Action::Backup
tag = ""

op = OptionParser.new do |o|
  o.banner = "backup NOMAD_TASK_DIR/storage using restic"
  o.on("-h", "--help", "Display this help"){ puts o; exit 0 }
  o.on("-b", "--backup", "Backup"){ action = Action::Backup }
  o.on("-r", "--restore", "Restore"){ action = Action::Restore }
  o.on("-t", "--tag=TAG", "Snapshot tag"){|v| tag = v }
end

op.parse

def fail(msg)
  STDERR.puts msg
  exit 1
end

fail "--tag must be set" if tag.empty?
%w[
  MONITORING_URL
  NOMAD_PORT_metrics
  NOMAD_TASK_DIR
  RESTIC_PASSWORD
  RESTIC_REPOSITORY
].each do |key|
  fail "#{key} must be set" unless ENV[key]?
end

require "./*"

case action
when Action::Backup
  Backup.new(tag).run
when Action::Restore
  Restore.new(tag).run
end
