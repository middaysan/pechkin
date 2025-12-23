require 'logger'
require 'json'

module Pechkin
  # Request logger to log all incoming requests to DB and STDOUT
  class RequestLogger
    def initialize
      @logger = Logger.new($stdout)
    end

    def log(req, status, body_size)
      params = parse_body(req)

      # Save to DB
      DB::RequestLog.create!(
        ip: req.ip,
        method: req.request_method,
        path: req.path_info,
        status: status,
        body_size: body_size,
        params: params.to_json
      )

      # Cleanup old logs (keep only latest 1000)
      cleanup_logs

      # Log to STDOUT for visibility
      @logger.info("IP: #{req.ip} #{req.request_method} #{req.path_info} - #{status} (#{body_size} bytes)")
    end

    def self.recent_logs(limit = 100)
      DB::RequestLog.order(created_at: :desc).limit(limit).map do |log|
        {
          'timestamp' => log.created_at.iso8601,
          'ip' => log.ip,
          'method' => log.method,
          'path' => log.path,
          'status' => log.status,
          'body_size' => log.body_size,
          'params' => log.params_hash
        }
      end
    end

    private

    def cleanup_logs
      # Simple cleanup: delete logs that are not in the top 1000
      count = DB::RequestLog.count
      return unless count > 1000

      # Find the ID of the 1000th newest record
      oldest_to_keep = DB::RequestLog.order(created_at: :desc).offset(999).first
      return unless oldest_to_keep

      DB::RequestLog.where(DB::RequestLog.arel_table[:created_at].lt(oldest_to_keep.created_at)).delete_all
    end

    def parse_body(req)
      return {} unless req.post? || req.put?

      req.body.rewind
      body = req.body.read
      req.body.rewind

      JSON.parse(body)
    rescue StandardError
      { raw_body: body }
    end
  end

  # Helper class to write to multiple IO objects
  class MultiIO
    def initialize(*targets)
      @targets = targets
    end

    def write(*args)
      @targets.each { |t| t.write(*args) }
    end

    def close
      @targets.each { |t| t.close if t.respond_to?(:close) && t != $stdout && t != $stderr }
    end

    def flush
      @targets.each { |t| t.flush if t.respond_to?(:flush) }
    end
  end
end
