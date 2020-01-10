load "vendor/bundle/bundler/setup.rb"

require 'json'
require 'aws-sdk-sqs'
require 'arthropod'
require 'rack'

def main(event:, context:)
  client = Aws::SQS::Client.new({
    access_key_id: ENV["ARTHROPOD_ACCESS_KEY_ID"],
    secret_access_key: ENV["ARTHROPOD_SECRET_ACCESS_KEY"],
    region: ENV["ARTHROPOD_REGION"]
  })

  headers = event['headers']

  # Base Rack env
  env = {
    'CONTENT_TYPE' => headers['Content-Type'] || "text/html; charset=utf-8",
    'REMOTE_ADDR' => headers['X-Forwarded-For'],
    'REMOTE_HOST' => headers['Host'],
    'REQUEST_METHOD' => event['httpMethod'] || 'GET',
    'REQUEST_PATH' => event['path'],
    'PATH_INFO' => event['path'],
    'SCRIPT_NAME' => "",
    'SERVER_NAME' => headers['Host'],
    'SERVER_PORT' => headers['X-Forwarded-Port'],
    'SERVER_PROTOCOL' => "HTTP/1.1",
    'SERVER_SOFTWARE' => "WEBrick/1.3.1 (Ruby/2.2.2/2015-04-13)",
  }

  # Build query string
  query_string = Rack::Utils.build_query(event["queryStringParameters"] || {})
  env['QUERY_STRING'] = query_string

  # Build REQUEST_URI
  host =
    if headers['X-Forwarded-For'] == 'https' && headers['X-Forwarded-Port'] != '443' or
       headers['X-Forwarded-For'] == 'http'  && headers['X-Forwarded-Port'] != '80'
      "#{headers['Host']}:#{headers['X-Forwarded-Port']}"
    else
      headers['Host']
    end
  env['REQUEST_URI'] = "#{headers['X-Forwarded-Port']}://#{host}#{event['path']}#{query_string}"

  # Build body stuff
  env['rack.input'] =
    if event['isBase64Encoded']
      Base64.decode64(event['body'])
    else
      event['body']
    end.to_s
  env['CONTENT_LENGTH'] = headers['Content-Length'] || env['rack.input'].bytesize.to_s

  # Add headers
  headers.each do |key, value|
    env["HTTP_#{key.gsub('-','_').upcase}"] = value
  end

  status, headers, body = Arthropod::Client.push(queue_name: ENV["QUEUE_NAME"], client: client, body: env).body

  {
    statusCode: status,
    headers: headers,
    body: body
  }
end
