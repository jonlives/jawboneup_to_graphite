jawboneup_to_graphite
=====================

A little script for sending Sleep metrics from your Jawbone Up to Graphite

##Installation

This script requires a couple of gems to function. You can use bundler to install the necessary gems:

```
gem install bundler
bundle install
```

##Instructions

Before using the script, you'll need to get a XID and Token from Jawbone to use with the script. To do this, run the script with the ```--get-token``` option and enter your Jawbone Up username and password as below. The script will then return an XID and Token.

```
$> ./jawboneup_to_graphite.rb --get-token
Jawbone Username: me@mydomain.com
Jawbone Password: mypassword
Token: bhdoijfoijdoipjfdspad
Xid: sdsajdosajdioaj
```

The next step is to copy your XID and Token into the ```xid``` and ```token``` variables specified in the ```config.yml``` file (you can copy ```config.yml.example``` to get you started). ```config.yml``` should be in the same directory as the ```jawbone_to_graphite.rb``` script. You'll also want to set your graphite host, port, and the prefix you want to give your metrics:

```
jawbone:
  xid: 'bhdoijfoijdoipjfdspad'
  token: 'sdsajdosajdioaj'
graphite:
  host: "my.graphite.server"
  port: "2003"
  metric_prefix: "me.jawbone.sleep"
```

Now you just need to run the script whenever you sync your Jawbone Up, and it'll send your sleep metrics to graphite, ready for adding to dashboards, creating Nagios alerts, and so on.

Please note, each time it's run, the script will send all sleep data dated since *yesterday at midnight* to graphite. This avoids sending repeated old data to your graphite server. If you want to send data for a different date, you can use the ```--set-date``` option:

```
jawbone_to_graphite.rb --set-date=2015-03-29
```
