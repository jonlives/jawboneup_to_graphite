jawboneup_to_graphite
=====================

A little script for sending Sleep metrics from your Jawbone Up to Graphite

##Installation

This script requires a couple of gems to function. Run the following ```gem install``` commands before using:

```
gem install choice
gem install jawbone-up
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

The next step is to copy your XID and Token into the ```xid``` and ```token``` variables at the top of the ```jawboneup_to_graphite``` script. You'll also want to set your graphite host, port, and the prefix you want to give your metrics:

```
xid = 'bhdoijfoijdoipjfdspad'
token = 'sdsajdosajdioaj'
graphite_host = "my.graphite.server"
graphite_port = "2003"
metric_prefix = "me.jawbone.sleep"
```

Now you just need to run the script whenever you Sync your Jawbone Up, and it'll send your sleep metrics to graphite ready for adding to Dashboard, creating Nagios alerts and so on.