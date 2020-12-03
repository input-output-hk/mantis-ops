require "json"

ENV["VAULT_FORMAT"] = "json"

def find_paths(parent)
  paths = Array(String).from_json(`vault kv list "#{parent}"`)
  paths.map do |path|
    if path =~ /\/$/
      find_paths(parent + path).flatten
    else
      [parent + path]
    end
  end
end

keys = find_paths("kv/nomad-cluster/mantis-testnet/").flatten

keys.each do |key|
  system("vault", args: ["kv", "metadata", "delete", key]) || raise("couldn't delete #{key}")
end
