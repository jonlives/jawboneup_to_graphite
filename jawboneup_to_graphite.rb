#!/usr/bin/env ruby
require 'pathname'
require 'jawbone-up'
require 'date'
require 'choice'
require 'app_conf'

# Take an array of arrays and build up a set of data points to illustrate our sleep.
# Since the Jawbone simply takes snapshots of one's sleep state at (relatively) regular periods,
# fill in the blanks with the known sleep state until we encounter a sleep state change and
# continue in this way until the end of the given data set.
# Return a string that will be sent to Graphite
$sleep_state_types = [ 'awake', 'light', 'deep' ]
def extrapolate_sleeps( sleep_state_details )
    message = []
    # there may be more than one sleep period returned
    sleep_state_details.each {|sleep_period|
        # find the state change we're on now, and the next so that we know when
        # to start/stop extrapolating
        sleep_period.each_with_index {|item, index|
            current_sleep_state_change = sleep_period[index]
            next_sleep_state_change = sleep_period[index + 1]
            current_sleep_epoch, current_sleep_state = current_sleep_state_change
            next_sleep_epoch, next_sleep_state = next_sleep_state_change

            # if we've reached the last data point, artificially extend it 2 minutes so it's visible on the graph
            if next_sleep_state_change.nil?
                next_sleep_epoch = current_sleep_epoch + 120
            end

            until current_sleep_epoch >= next_sleep_epoch.to_i do
                current_sleep_epoch = current_sleep_epoch + 60
                message.push( "#{$metric_prefix}.details.#{$sleep_state_types[ current_sleep_state - 1 ]} #{current_sleep_state} #{current_sleep_epoch}" )
            end
        }
    }
    message = message.join("\n") + "\n"
end

# Load the config file
config = AppConf.new
config.load("#{File.expand_path(File.dirname(Pathname.new(__FILE__).realpath))}/config.yml")

Choice.options do
  header ""
  header "Specific options:"

  option :get_token, :required => false do
    long  '--get-token'
    desc  'Get a login token from Jawbone'
  end
  option :manual_date, :required => false do
    long  '--set-date=2013-09-29'
    desc  'Override yesterdays data for another date'
  end
end

if Choice.choices[:get_token]
  # Make sure we don't generate new tokens unless people actually want to.
  if not (config['jawbone']['xid'].empty? and config['jawbone']['token'].empty?)
    puts "Jawbone token or xid already found in your config.yml. Do you wish to generate new ones? y/N"
    choice = STDIN.gets.chomp.downcase
    if choice != "y"
      puts "You said #{choice} instead of y, exiting..."
      exit 1
    end
  end

  print "Jawbone Username: "
  username = STDIN.gets.chomp
  print "Jawbone Password: "
  system 'stty -echo'
  password = STDIN.gets.chomp
  system 'stty echo'
  up = JawboneUP::Session.new
  up.signin username, password
  puts "Token: #{up.token}"
  puts "Xid: #{up.xid}"
  puts "Please save these values to your config.yml file in this directory."
  exit
else
    if config['jawbone']['xid'].empty? or config['jawbone']['token'].empty?
      puts "Jawbone token or xid are missing. Please run the script with the --get-token option first, then save the values into config.yml"
      exit 1
    end
    up = JawboneUP::Session.new :auth => {
      :xid => config['jawbone']['xid'],
      :token => config['jawbone']['token']
    }

    if Choice.choices[:manual_date] then
      date_parts = Choice.choices[:manual_date].split('-')
      year = date_parts[0].to_i
      month = date_parts[1].to_i
      day = date_parts[2].to_i
      today = Time.new(year, month, day).to_i
    else
      today = Date.today.prev_day.to_time.to_i
    end

    # sleep detail
    sleep_detail_items = up.get_sleep_details
    sleep_xids = [] # we might have multiple sleeps to look at (think power naps!)
    sleep_detail_items['items'].each do |item|
        if today < item['time_created']
            sleep_xids.push( item['xid'] )
        end
    end

    sleep_xids = sleep_xids.sort
    sleep_state_details = []
    sleep_xids.each do |sleep_xid|
        sleep_state_details.push( up.get_sleep_snapshot( sleep_xid ) )
    end

    sleep_detail_message = extrapolate_sleeps( sleep_state_details )
    pretty_today = DateTime.strptime(today.to_s, '%s').to_s.split("T")[0]
    if sleep_detail_message.eql? "\n"
      puts "No sleep data found for #{pretty_today}, has band synced?"
    else
      puts sleep_detail_message
    end
    puts "Sending extrapolated sleep state data for #{pretty_today} to #{config['graphite']['host']}"
    socket = TCPSocket.open(config['graphite']['host'], config['graphite']['port'])
    socket.write(sleep_detail_message)

    # sleep summary
    sleep_info = up.get_sleep_summary
    sleep_info['items'].each do |item|
      if today < item['time_created']
        sleep_summary_message = []
        date = Time.at item['time_created']
        puts "\n"
        puts "Sleep Summary Data:"
        puts date.to_s + " " + item['title']
        puts "Timestamp: #{item['time_created']}"
        puts "Light Sleep: #{item['details']['light']/60}"
        puts "Deep Sleep: #{item['details']['sound']/60}"
        puts "Woke Up: #{item['details']['awakenings']} time(s)"
        puts "Sleep Quality: #{item['details']['quality']}"

        message = "#{$metric_prefix}.summary.light_minutes #{item['details']['light']/60} #{item['time_created']}\n"
        sleep_summary_message.push( message )

        message = "#{$metric_prefix}.summary.deep_minutes #{item['details']['sound']/60} #{item['time_created']}\n"
        sleep_summary_message.push( message )

        message = "#{$metric_prefix}.summary.awakenings #{item['details']['awakenings']} #{item['time_created']}\n"
        sleep_summary_message.push( message )

        message = "#{$metric_prefix}.summary.quality #{item['details']['quality']} #{item['time_created']}\n"
        sleep_summary_message.push( message )

        # send it all up to Graphite
        sleep_summary_message = sleep_summary_message.join( "\n" ) + "\n"
        socket = TCPSocket.open(config['graphite']['host'], config['graphite']['port'])
        socket.write(sleep_summary_message)
      end
  end
end
