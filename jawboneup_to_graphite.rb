#!/usr/bin/env ruby

require 'jawbone-up'
require 'date'
require 'choice'

# PARAMETERS

# Run this script with the --get-token option first
# Then copy the xid and token returned into the below parameters
# You can also customise the graphite host, port and metric prefix.

xid = ''
token = ''
graphite_host = "my.graphite.server"
graphite_port = "2003"
metric_prefix = "me.jawbone.sleep"

Choice.options do
  header ""
  header "Specific options:"

  option :get_token, :required => false do
    long  '--get-token'
    desc  'Get a login token from Jawbone'
  end
end

if Choice.choices[:get_token]
  print "Jawbone Username: "
  username = STDIN.gets.chomp
  print "Jawbone Password: "
  password = STDIN.gets.chomp
  up = JawboneUP::Session.new
  up.signin username, password
  puts "Token: #{up.token}"
  puts "Xid: #{up.xid}"
else
    if xid.empty? or token.empty?
      puts "Invalid token and xid. Please run the script with the --get-token option first, then paste the values into the parameters at the top of the script."
      exit 1
    end
    up = JawboneUP::Session.new :auth => {
      :xid => xid,
      :token => token
    }

    today = Date.today.prev_day.to_time.to_i

    sleep_info = up.get_sleep_summary
    sleep_info['items'].each do |item|
      if today < item['time_created']
        date = Time.at item['time_created']
        puts "\n"
        puts "Sleep Summary Data:"
        puts date.to_s + " " + item['title']
        puts "Timestamp: #{item['time_created']}"
        puts "Light Sleep: #{item['details']['light']/60}"
        puts "Deep Sleep: #{item['details']['deep']/60}"
        puts "Woke Up: #{item['details']['awakenings']} time(s)"
        puts "Sleep Quality: #{item['details']['quality']}"

        puts "Sending #{metric_prefix}.light_sleep to #{graphite_host}"
        message = "#{metric_prefix}.light_sleep #{item['details']['light']/60} #{item['time_created']}\n"
        socket = TCPSocket.open(graphite_host, graphite_port)
        socket.write(message)

        puts "Sending #{metric_prefix}.deep_sleep to #{graphite_host}"
        message = "#{metric_prefix}.deep_sleep #{item['details']['deep']/60} #{item['time_created']}\n"
        socket = TCPSocket.open(graphite_host, graphite_port)
        socket.write(message)

        puts "Sending #{metric_prefix}.awakenings to #{graphite_host}"
        message = "#{metric_prefix}.awakenings #{item['details']['awakenings']} #{item['time_created']}\n"
        socket = TCPSocket.open(graphite_host, graphite_port)
        socket.write(message)

        puts "Sending #{metric_prefix}.quality to #{graphite_host}"
        message = "#{metric_prefix}.quality #{item['details']['quality']} #{item['time_created']}\n"
        socket = TCPSocket.open(graphite_host, graphite_port)
        socket.write(message)


        puts "\n"
        puts "Getting Detailed Sleep Data.."
        user_xid = item['xid']
        detailed = up.get("/nudge/api/sleeps/#{user_xid}/snapshot")
        puts "Sending Detailed Sleep Data to metric #{metric_prefix}.detailed_sleep on #{graphite_host}"
        message = "#{metric_prefix}.detailed_sleep 0 #{detailed['data'].first.first-1}\n"
        socket = TCPSocket.open(graphite_host, graphite_port)
        socket.write(message)
        detailed['data'].each do |d|
          message = "#{metric_prefix}.detailed_sleep #{d.last-1} #{d.first}\n"
          socket = TCPSocket.open(graphite_host, graphite_port)
          socket.write(message)
        end
        message = "#{metric_prefix}.detailed_sleep 0 #{detailed['data'].last.first+1}\n"
        socket = TCPSocket.open(graphite_host, graphite_port)
        socket.write(message)
      end
  end
end