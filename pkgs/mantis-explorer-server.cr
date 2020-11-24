require "http/server"
require "uri"
require "mime"
require "digest/md5"
require "option_parser"

class HTTP::ExplorerFileHandler
  include HTTP::Handler

  @public_dir : Path

  # Creates a handler that will serve files in the given *public_dir*, after
  # expanding it (using `File#expand_path`).
  #
  # If *fallthrough* is `false`, this handler does not call next handler when
  # request method is neither GET or HEAD, then serves `405 Method Not Allowed`.
  # Otherwise, it calls next handler.
  def initialize(public_dir : String, fallthrough = true)
    @public_dir = Path.new(public_dir).expand
    @fallthrough = !!fallthrough
  end

  def call(context)
    unless context.request.method.in?("GET", "HEAD")
      if @fallthrough
        call_next(context)
      else
        context.response.status = :method_not_allowed
        context.response.headers.add("Allow", "GET, HEAD")
      end
      return
    end

    original_path = context.request.path.not_nil!
    is_dir_path = original_path.ends_with?("/")
    request_path = URI.decode(original_path)

    # File path cannot contains '\0' (NUL) because all filesystem I know
    # don't accept '\0' character as file name.
    if request_path.includes? '\0'
      context.response.respond_with_status(:bad_request)
      return
    end

    request_path = Path.posix(request_path)
    expanded_path = request_path.expand("/")

    file_path = @public_dir.join(expanded_path.to_kind(Path::Kind.native))
    is_dir = Dir.exists? file_path
    is_file = !is_dir && File.exists?(file_path)

    if request_path != expanded_path || is_dir && !is_dir_path
      redirect_path = expanded_path
      if is_dir && !is_dir_path
        # Append / to path if missing
        redirect_path = expanded_path.join("")
      end
      redirect_to context, redirect_path
      return
    end

    unless is_file
      file_path = @public_dir.join(Path.posix("/index.html").to_kind(Path::Kind.native))
      is_file = File.exists?(file_path)
      is_dir = Dir.exists? file_path
    end

    if is_file
      hash = file_hash(file_path)
      add_cache_headers(context.response.headers, hash)

      if cache_request?(context, hash)
        context.response.status = :not_modified
        return
      end

      context.response.content_type = MIME.from_filename(file_path.to_s, "application/octet-stream")
      context.response.content_length = File.size(file_path)
      File.open(file_path) do |file|
        IO.copy(file, context.response)
      end
    else
      call_next(context)
    end
  end

  private def redirect_to(context, url)
    context.response.status = :found

    url = URI.encode(url.to_s)
    context.response.headers.add "Location", url
  end

  private def add_cache_headers(response_headers : HTTP::Headers, hash : String) : Nil
    response_headers["Etag"] = etag(hash)
  end

  private def cache_request?(context : HTTP::Server::Context, hash : String) : Bool
    # According to RFC 7232:
    # A recipient must ignore If-Modified-Since if the request contains an If-None-Match header field
    if if_none_match = context.request.if_none_match
      match = {"*", context.response.headers["Etag"]}
      if_none_match.any? { |etag| match.includes?(etag) }
    else
      false
    end
  end

  private def etag(file_hash)
    %{"#{file_hash}"}
  end

  private def file_hash(file_path)
    Digest::MD5.hexdigest(File.read(file_path))
  end
end

root = ENV["ROOT"]? || "."
host = ENV["HOST"]? || "127.0.0.1"
port = (ENV["PORT"]? || "3000").to_i

OptionParser.parse do |parser|
  parser.banner = "Usage: mantis-explorer-server [arguments]"
  parser.on("-r", "--root=ROOT", "directory root (default: #{root})") { |v| root = v }
  parser.on("-h", "--host=HOST", "Listening host (default: #{host})") { |v| host = v }
  parser.on("-p", "--port=PORT", "Listening port (default: #{port})") { |v| port = v.to_i }
  parser.on("--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

server = HTTP::Server.new([
  HTTP::ErrorHandler.new,
  HTTP::LogHandler.new,
  HTTP::CompressHandler.new,
  HTTP::ExplorerFileHandler.new(root),
])

server.bind_tcp host, port
puts "Listening at #{host}:#{port}"
server.listen
