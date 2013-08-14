#!/usr/bin/env ruby

require 'jawbone-up'
require 'date'
require 'choice'
require 'ap'

# PARAMETERS

# Run this script with the --get-token option first
# Then copy the xid and token returned into the below parameters
# You can also customise the graphite host, port and metric prefix.

token = ''
xid = ''
graphite_host = "my.graphite.com"
graphite_port = "2003"
$metric_prefix = "my.sleep"

Choice.options do
  header ""
  header "Specific options:"

  option :get_token, :required => false do
    long  '--get-token'
    desc  'Get a login token from Jawbone'
  end
end

# Ttake an array of arrays and build up a set of data points to illustrate our sleep.
# Since the Jawbone simply takes snapshots of one's sleep state at (relatively) regular periods,
# fill in the blanks with the known sleep state until we encounter a sleep state change and
# continue in this way until the end of the given data set.
# Return a string that will be sent to Graphite
$sleep_state_types = [ 'awake', 'light', 'deep' ]
def extrapolate_sleeps( sleep_state_details )
    sleep_state_details.flatten!(1)
    epoch_current = 0   # start fresh
    message = []
    sleep_state_details.each do |sleep|
        sleep_epoch, sleep_state = sleep
        # start building at the point our data starts
        if epoch_current == 0
            epoch_current = sleep_epoch
            next
        end

        until epoch_current > sleep_epoch.to_i do
            epoch_current = epoch_current + 60
            message.push( "#{$metric_prefix}.details.#{$sleep_state_types[ sleep_state - 1 ]} #{sleep_state} #{epoch_current}" )
        end
    end
    message = message.join("\n") + "\n"
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

    # sleep detail
    sleep_detail_items = up.get_sleep_details
    sleep_xids = [] # we might have multiple sleeps to look at (think power naps!)
    sleep_detail_items['items'].each do |item|
        if today < item['time_created']
            sleep_xids.push( item['xid'] )
        end
    end

    sleep_state_details = []
    sleep_xids.each do |sleep_xid|
        sleep_state_details.push( up.get_sleep_snapshot( sleep_xid ) )
    end
    sleep_detail_message = extrapolate_sleeps( sleep_state_details )
    puts "Sending extrapolated sleep state data to #{graphite_host}"
    socket = TCPSocket.open(graphite_host, graphite_port)
    socket.write(sleep_detail_message)

    # sleep summary
    sleep_summary_message = []
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

        message = "#{$metric_prefix}.summary.light_minutes#{item['details']['light']/60} #{item['time_created']}\n"
        sleep_summary_message.push( message )

        message = "#{$metric_prefix}.summary.deep_minutes #{item['details']['deep']/60} #{item['time_created']}\n"
        sleep_summary_message.push( message )

        message = "#{$metric_prefix}.summary.awakenings #{item['details']['awakenings']} #{item['time_created']}\n"
        sleep_summary_message.push( message )

        message = "#{$metric_prefix}.summary.quality #{item['details']['quality']} #{item['time_created']}\n"
        sleep_summary_message.push( message )

        # send it all up to Graphite
        sleep_summary_message = sleep_summary_message.join( "\n" ) + "\n"
        socket = TCPSocket.open(graphite_host, graphite_port)
        socket.write(sleep_summary_message)
      end
  end
end
