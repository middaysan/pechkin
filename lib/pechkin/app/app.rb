module Pechkin
  # Rack application to handle requests
  class App
    DEFAULT_CONTENT_TYPE = { 'Content-Type' => 'application/json' }.freeze
    DEFAULT_HEADERS = {}.merge(DEFAULT_CONTENT_TYPE)

    attr_accessor :handler, :logger, :request_logger

    def initialize(logger, request_logger = nil)
      @logger = logger
      @request_logger = request_logger
    end

    def call(env)
      req = Rack::Request.new(env)

      # Stub for favicon.ico
      if req.path_info == '/favicon.ico'
        return response(405, '') # Return empty response 405 Method Not Allowed
      end

      result = RequestHandler.new(handler, req, logger).handle
      res = response(200, result)
      request_logger&.log(req, 200, result.to_json.size)
      res
    rescue AppError => e
      res = process_app_error(req, e)
      request_logger&.log(req, e.code, res[2].first.size)
      res
    rescue StandardError => e
      res = process_unhandled_error(req, e)
      request_logger&.log(req, 503, res[2].first.size)
      res
    end

    private

    def response(code, body)
      [code.to_s, DEFAULT_HEADERS.dup, [body.to_json]]
    end

    def process_app_error(req, err)
      data = { status: 'error', message: err.message }
      if req.body
        req.body.rewind
        body = req.body.read
      else
        body = ''
      end

      logger.error "Can't process message: #{err.message}. Body: '#{body}'"
      response(err.code, data)
    end

    def process_unhandled_error(req, err)
      data = { status: 'error', message: err.message }
      logger.error("#{err.message}\n\t" + err.backtrace.join("\n\t"))
      logger.error(req.body.read)
      response(503, data)
    end
  end
end
