# puppet-kafka [![Build Status](https://travis-ci.org/miguno/puppet-kafka.png?branch=master)](https://travis-ci.org/miguno/puppet-kafka)

[Wirbelsturm](https://github.com/miguno/wirbelsturm)-compatible [Puppet](http://puppetlabs.com/) module to deploy
[Kafka](http://kafka.apache.org/) 0.8+ servers/brokers.

You can use this Puppet module to deploy Kafka to physical and virtual machines, for instance via your existing
internal or cloud-based Puppet infrastructure and via a tool such as [Vagrant](http://www.vagrantup.com/) for local
and remote deployments.

---

Table of Contents

* <a href="#quickstart">Quick start</a>
* <a href="#features">Features</a>
* <a href="#requirements">Requirements and assumptions</a>
* <a href="#installation">Installation</a>
* <a href="#configuration">Configuration</a>
* <a href="#usage">Usage</a>
    * <a href="#configuration-examples">Configuration examples</a>
        * <a href="#hiera">Using Hiera</a>
        * <a href="#manifests">Using Puppet manifests</a>
    * <a href="#service-management">Service management</a>
    * <a href="#log-files">Log files</a>
* <a href="#custom-zk-root">Custom ZooKeeper chroot (experimental)</a>
* <a href="#mirrormaker">Mirror Maker support (optional)</a>
* <a href="#development">Development</a>
* <a href="#todo">TODO</a>
* <a href="#changelog">Change log</a>
* <a href="#contributing">Contributing</a>
* <a href="#license">License</a>
* <a href="#references">References</a>

---

<a name="quickstart"></a>

# Quick start

See section [Usage](#usage) below.


<a name="features"></a>

# Features

* Supports Kafka 0.8+, i.e. the latest stable release version.
* Decouples code (Puppet manifests) from configuration data ([Hiera](http://docs.puppetlabs.com/hiera/1/)) through the
  use of Puppet parameterized classes, i.e. class parameters.  Hence you should use Hiera to control how Kafka is
  deployed and to which machines.
* Supports RHEL OS family (e.g. RHEL 6, CentOS 6, Amazon Linux).
    * Code contributions to support additional OS families are welcome!
* Supports tuning of system-level configuration such as the maximum number of open files (cf.
  `/etc/security/limits.conf`) to optimize the performance of your Kafka deployments.
* Kafka is run under process supervision via [supervisord](http://www.supervisord.org/) version 3.0+.


<a name="requirements"></a>

# Requirements and assumptions

* A Kafka cluster requires a **ZooKeeper quorum** (1, 3, 5, or more ZooKeeper instances) for proper functioning.  Take a
  look at [puppet-zookeeper](https://github.com/miguno/puppet-zookeeper) to deploy such a ZooKeeper quorum for use with
  Kafka.
* This module requires that the target machines to which you are deploying Kafka have **yum repositories configured**
  for pulling the Kafka package (i.e. RPM).
    * We provide [wirbelsturm-rpm-kafka](https://github.com/miguno/wirbelsturm-rpm-kafka) so that you can conveniently
      build such an RPM yourself.
    * Because we run Kafka via supervisord through [puppet-supervisor](https://github.com/miguno/puppet-supervisor), the
      supervisord RPM must be available, too.  See [puppet-supervisor](https://github.com/miguno/puppet-supervisor)
      for details.
* This module requires that the target machines have a **Java JRE/JDK installed** (e.g. via a separate Puppet module
  such as [puppetlabs-java](https://github.com/puppetlabs/puppetlabs-java)).  You may also want to make sure that the
  Java package is installed _before_ Kafka to prevent startup problems.
    * Because different teams may have different approaches to install "base" packages such as Java, this module does
      intentionally not puppet-require Java directly.
    * Take a look at LinkedIn's [Java setup for Kafka](https://kafka.apache.org/documentation.html#java).
* This module requires the following **additional Puppet modules**:

    * [puppetlabs/stdlib](https://github.com/puppetlabs/puppetlabs-stdlib)
    * [puppet-limits](https://github.com/miguno/puppet-limits)
    * [puppet-supervisor](https://github.com/miguno/puppet-supervisor)

  It is recommended that you add these modules to your Puppet setup via
  [librarian-puppet](https://github.com/rodjek/librarian-puppet).  See the `Puppetfile` snippet in section
  _Installation_ below for a starting example.
* **When using Vagrant**: Depending on your Vagrant box (image) you may need to manually configure/disable firewall
  settings -- otherwise machines may not be able to talk to each other.  One option to manage firewall settings is via
  [puppetlabs-firewall](https://github.com/puppetlabs/puppetlabs-firewall).


<a name="installation"></a>

# Installation

It is recommended to use [librarian-puppet](https://github.com/rodjek/librarian-puppet) to add this module to your
Puppet setup.

Add the following lines to your `Puppetfile`:

```
# Add the stdlib dependency as hosted on public Puppet Forge.
#
# We intentionally do not include the stdlib dependency in our Modulefile to make it easier for users who decided to
# use internal copies of stdlib so that their deployments are not coupled to the availability of PuppetForge.  While
# there are tools such as puppet-library for hosting internal forges or for proxying to the public forge, not everyone
# is actually using those tools.
mod 'puppetlabs/stdlib', '>= 4.1.0'

# Add the puppet-kafka module
mod 'kafka',
  :git => 'https://github.com/miguno/puppet-kafka.git'

# Add the puppet-limits and puppet-supervisor module dependencies
mod 'limits',
  :git => 'https://github.com/miguno/puppet-limits.git'

mod 'supervisor',
  :git => 'https://github.com/miguno/puppet-supervisor.git'
```

Then use librarian-puppet to install (or update) the Puppet modules.


<a name="configuration"></a>

# Configuration

* See [init.pp](manifests/init.pp) and [broker.pp](manifests/broker.pp) for the list of currently supported
  configuration parameters.  These should be self-explanatory.
* See [params.pp](manifests/params.pp) for the default values of those configuration parameters.

Of special note is the class parameter `$config_map`:  You can use this parameter to "inject" arbitrary Kafka config
settings via Hiera/YAML into the Kafka broker configuration file (default name: `server.properties`).  However you
should not re-define config settings via `$config_map` that already have explicit Puppet class parameters (such as
`$broker_id`).  See the examples below for more information on `$config_map` usage.


<a name="usage"></a>

# Usage

**IMPORTANT: Make sure you read and follow the [Requirements and assumptions](#requirements) section above.**
**Otherwise the examples below will of course not work.**


<a name="configuration-examples"></a>

## Configuration examples


<a name="hiera"></a>

### Using Hiera


A "full" single-node example that includes the deployment of [supervisord](http://www.supervisord.org/) via
[puppet-supervisor](https://github.com/miguno/puppet-supervisor) and
[ZooKeeper](http://zookeeper.apache.org/) via [puppet-zookeeper](https://github.com/miguno/puppet-zookeeper).
Here, both ZooKeeper and Kafka are running on the same machine.  The Kafka broker will listen on port `9092/tcp` and
will connect to the ZooKeeper server running at `localhost:2181`.  That's a nice setup for your local development
laptop or CI server, for instance.


```yaml
---
classes:
  - kafka::service
  - supervisor
  - zookeeper::service
```

A more sophisticated example that overrides some of the default settings and also demonstrates the use of `$config_map`.
In this example, the broker connects to the ZooKeeper server `zookeeper1`.
Take a look at [Kafka's Java/JVM configuration notes](https://kafka.apache.org/documentation.html#java) as well as
recommended [production configurations](https://kafka.apache.org/documentation.html#prodconfig).

```yaml
---
classes:
  - kafka::service
  - supervisor

## Kafka
kafka::broker_id: 0
kafka::config_map:
  log.roll.hours: 48
  log.retention.hours: 48
kafka::kafka_heap_opts: '-Xms2G -Xmx2G -XX:NewSize=256m -XX:MaxNewSize=256m'
kafka::kafka_opts: '-XX:CMSInitiatingOccupancyFraction=70 -XX:+PrintTenuringDistribution'
kafka::zookeeper_connect:
  - 'zookeeper1:2181'

# Optional: Manage /etc/security/limits.conf to tune the maximum number
# of open files, which is a typical setting you must change for Kafka
# production environments.  Default: false (do not manage)
kafka::limits_manage: true
kafka::limits_nofile: 65536
```


<a name="manifests"></a>

### Using Puppet manifests

_Note: It is recommended to use Hiera to control deployments instead of using this module in your Puppet manifests_
_directly._

TBD


<a name="service-management"></a>

## Service management

To manually start, stop, restart, or check the status of the Kafka broker service, respectively:

    $ sudo supervisorctl [start|stop|restart|status] kafka-broker

Example:

    $ sudo supervisorctl status
    kafka-broker                          RUNNING    pid 16461, uptime 3 days, 09:22:38


<a name="log-files"></a>

## Log files

_Note: The locations below may be different depending on the Kafka RPM you are actually using._

* Kafka log files: `/var/log/kafka/*.log`
* Supervisord log files related to Kafka processes:
    * `/var/log/supervisor/kafka-broker/kafka-broker.out`
    * `/var/log/supervisor/kafka-broker/kafka-broker.err`
* Supervisord main log file: `/var/log/supervisor/supervisord.log`


<a name="custom-zk-root"></a>

# Custom ZooKeeper chroot (experimental)

Kafka supports custom ZooKeeper chroots, which is useful for multi-tenant ZooKeeper setups.
This Puppet module has experimental support for this feature.


## Creating the chroot

If Kafka will share a ZooKeeper cluster with other users, you might want to create a znode in ZooKeeper in which to
store the data of your Kafka cluster.

First, you must create the znode manually yourself.  You can use `zkCli.sh` that ships with ZooKeeper, or you can use
the Kafka built-in `zookeeper-shell`.  The following example creates the znode `/my_kafka`.

```bash
$ kafka zookeeper-shell <zookeeper_host>:2182
Connecting to kraken-zookeeper
Welcome to ZooKeeper!
JLine support is enabled

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
[zk: kraken-zookeeper(CONNECTED) 0] create /my_kafka kafka
Created /my_kafka
```

You can use whatever chroot znode path you like.  The second argument (```data```) is arbitrary.  In this example we
used 'kafka'.


## Configuring Kafka to use the ZooKeeper chroot

When configuring the ZooKeeper connection string you must only add the custom chroot _to the last entry_ in the
`zookeeper_connect` array.

```yaml
# Irrelevant config settings have been omitted/snipped
kafka::brokers:
  broker1:
    # WRONG!
    #
    # This Hiera configuration is the same as if you had added the following (incorrect) setting
    # to the normal Kafka configuration file `config/server.properties`:
    #
    #    zookeeper.connect=zkserver1:2181/my_kafka,zkserver2:2181/my_kafka
    #
    zookeeper_connect:
      - 'zkserver1:2181/my_kafka'
      - 'zkserver2:2181/my_kafka'

    # CORRECT
    #
    # This Hiera configuration is the same as if you had added the following (correct) setting
    # to the normal Kafka configuration file `config/server.properties`:
    #
    #    zookeeper.connect=zkserver1:2181,zkserver2:2181/my_kafka
    #
    zookeeper_connect:
      - 'zkserver1:2181'
      - 'zkserver2:2181/my_kafka'
```

<a name="mirrormaker"></a>
# Mirror Maker (optional)

We use the <a href="https://github.com/TrueCar/go_kafka_client">stealthy go client</a> because go is fast and stable. This puppet manifest can be
modified to use the native Kafka mirrormaker scripts as well. To create a mirrormaker config, simply do:

```

class kafka::mirrormaker::rsyslog_x2y {
  kafka::mirrormaker::generic {$name:
    fromaz         => 'x',
    toaz           => 'y',
    topicwhitelist => 'rsyslog-prod',
  }
}
```

<a name="development"></a>

# Development

It is recommended run the `bootstrap` script after a fresh checkout:

    $ ./bootstrap

You have access to a bunch of rake commands to help you with module development and testing:

    $ bundle exec rake -T
    rake acceptance          # Run acceptance tests
    rake build               # Build puppet module package
    rake clean               # Clean a built module package
    rake coverage            # Generate code coverage information
    rake help                # Display the list of available rake tasks
    rake lint                # Check puppet manifests with puppet-lint / Run puppet-lint
    rake module:bump         # Bump module version to the next minor
    rake module:bump_commit  # Bump version and git commit
    rake module:clean        # Runs clean again
    rake module:push         # Push module to the Puppet Forge
    rake module:release      # Release the Puppet module, doing a clean, build, tag, push, bump_commit and git push
    rake module:tag          # Git tag with the current module version
    rake spec                # Run spec tests in a clean fixtures directory
    rake spec_clean          # Clean up the fixtures directory
    rake spec_prep           # Create the fixtures directory
    rake spec_standalone     # Run spec tests on an existing fixtures directory
    rake syntax              # Syntax check Puppet manifests and templates
    rake syntax:hiera        # Syntax check Hiera config files
    rake syntax:manifests    # Syntax check Puppet manifests
    rake syntax:templates    # Syntax check Puppet templates
    rake test                # Run syntax, lint, and spec tests

Of particular interest are:

* `rake test` -- run syntax, lint, and spec tests
* `rake syntax` -- to check you have valid Puppet and Ruby ERB syntax
* `rake lint` -- checks against the [Puppet Style Guide](http://docs.puppetlabs.com/guides/style_guide.html)
* `rake spec` -- run unit tests


<a name="todo"></a>

# TODO

* Enhance in-line documentation of Puppet manifests.
* Add more unit tests and specs.
* Add rollback/remove functionality to completely purge Kafka related packages and configuration files from a machine.


<a name="changelog"></a>

# Change log

See [CHANGELOG](CHANGELOG.md).


<a name="contributing"></a>

# Contributing to puppet-kafka

Code contributions, bug reports, feature requests etc. are all welcome.

If you are new to GitHub please read [Contributing to a project](https://help.github.com/articles/fork-a-repo) for how
to send patches and pull requests to puppet-kafka.


<a name="license"></a>

# License

Copyright © 2014 Michael G. Noll

See [LICENSE](LICENSE) for licensing information.


<a name="references"></a>

# References

Puppet modules similar to this module:

* [wikimedia/puppet-kafka](https://github.com/wikimedia/puppet-kafka) -- focuses on Debian as the target OS, and
  apparently also supports Kafka mirroring and jmxtrans monitoring (the latter for sending JVM and Kafka broker metrics
  to tools such as Ganglia or Graphite)

The test setup of this module was derived from:

* [puppet-module-skeleton](https://github.com/garethr/puppet-module-skeleton)
