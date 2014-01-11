$main_binding = binding

require "logger"
require 'eventmachine'
require 'json'
require 'fileutils'

LOGFILE = "lt_client.log"
logger = Logger.new(LOGFILE)

class LtClient < EM::Connection

  def logger
    @_logger = Logger.new(LOGFILE)
  end

  def post_init
    logger.debug "Connection Initizlized"
  end

  def connection_completed
    logger.debug "Connection Established"
    client_info = JSON.generate({
      "name" => File.basename(FileUtils.pwd),
      "client-id" => ARGV[1],
      "dir" => FileUtils.pwd,
      "commands" => ["editor.eval.ruby"],
      "type" => "ruby"
    })
    send_data(client_info+"\n")
    logger.debug("Sent Client info")
    logger.debug(client_info)
  end

  def receive_data(data)
    logger.debug "Received Data:"
    logger.debug data
    begin
      id, cmd, args = JSON.parse(data)
    rescue JSON::ParserError => e
      puts "JSON Parser Error"
    end

    # Dispatch on cmd
    if id && cmd
      case cmd
      when "editor.eval.ruby"
        eval_ruby(id, args)
      when "client.close"
        logger.debug("Disconnecting")
        close_connection
        exit(0)
      end
    else
      puts "Ignoring invalid input"
    end
  end

  def send_response(id, cmd, args)
    data = (JSON.generate([id, cmd, args]))
    logger.debug("Sending data:")
    logger.debug(data)
    send_data(data)
    send_data("\n")
  end

  def eval_ruby(id, args)
    result = $main_binding.eval(args["code"])
    send_response(id, "editor.eval.ruby.result", {"result" => result, "meta" => args["meta"]})
  rescue Exception => e
    exception_and_backtrace = [e.inspect, e.backtrace].flatten.join("\n")
    send_response(id, "editor.eval.ruby.exception", {"ex" => exception_and_backtrace, "meta" => args["meta"]})
  end

end


EM.run do
  EM.connect '127.0.0.1', ARGV[0].to_i, LtClient
end

