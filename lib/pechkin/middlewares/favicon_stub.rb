# frozen_string_literal: true

module Pechkin
  module Middleware
    # Stub for favicon requests
    class FaviconStub
      def initialize(app, status: 204, body: '', cache_control: 'public, max-age=86400')
        @app = app
        @status = status
        @body = body
        @cache_control = cache_control
      end

      def call(env)
        path = env['PATH_INFO'].to_s

        # покрывает и "/favicon.ico" и "/admin/favicon.ico"
        return @app.call(env) unless path.end_with?('/favicon.ico')

        headers = {
          'Content-Type' => 'image/x-icon',
          'Cache-Control' => @cache_control,
          'Content-Length' => @body.bytesize.to_s
        }

        [@status, headers, [@body]]
      end
    end
  end
end
