require 'socket'
require 'uri'
require 'pry-rails'
require 'rack'

WEB_ROOT = 'public'

# Security problem
# To avoid client request a file outside public folder
def requested_file(path)
  clean = []
  parts = path.split("/")
  parts.each do |part|
    next if part.empty? || part == "."
    part == '..' ? clean.pop : clean << part
  end
  path = File.join(WEB_ROOT, *clean)
  # Redirect root path to index page
  path = File.join(path, 'index.html') if File.directory?(path)
  path
end

# Handle by application
# Read ENVs then return @app object [status, headers, body]
app = Proc.new do |env|
  file_path = requested_file(env['PATH_INFO'])
  if File.exist?(file_path) && !File.directory?(file_path)
    ['200', { 'Content-Type' => 'text/html' }, [File.read(file_path)]]
  else
    ['404', { 'Content-Type' => 'text/plain' }, ['File not found']]
  end
end

server = TCPServer.new('localhost', 1234)

# Http ruby server
# Handle sockets then pass ENVs to app
# and print response from app to client
loop do
  begin
    socket = server.accept
    request_line = socket.gets

    STDOUT.puts request_line

    # Request
    method, full_path = request_line.split(' ')
    path, query = full_path.split('?')

    # Call app
    status, headers, body = app.call({
      'REQUEST_METHOD' => method,
      'PATH_INFO' => path
    })

    # Response
    socket.print "HTTP/1.1 #{status}\r\n"

    headers.each do |key, value|
      socket.print "#{key}: #{value}\r\n"
    end

    socket.print "\r\n"

    body.each do |part|
      socket.print part
    end
  ensure
    socket.close
  end
end
