# Change log

## 2.0.3 (August 04, 2014)

* IMPROVEMENTS

* Data log directories are only created when needed. (thanks bazilek) [GH-3]


## 2.0.2 (July 01, 2014)

IMPROVEMENTS

* Handle so-called "controlled" broker shutdowns in a better way by supporting a `$service_stopsecs` class parameter for
  customizing the service configuration (supervisord) of Kafka brokers.  Previously, a broker that was performing a
  controlled shutdown (which take longer than uncontrolled shutdowns) was likely to be killed prematurely by
  supervisord. [GH-2] (thanks tioteath)
    * The `$service_stopsecs` class parameter configures the `stopwaitsecs` configuration option of supervisord:
      Here, supervisord will wait up to `stopwaitsecs` seconds for a process to gracefully shutdown before it will
      SIGKILL the process.  We set the default value of `$service_stopsecs` to 120 (seconds), which is compatible with
      the default shutdown cycle of Kafka brokers if controlled shutdowns are enabled.
    * See `controlled.shutdown.max.retries` and `controlled.shutdown.retry.backoff.ms` in the Kafka broker
      documentation.  Be aware that as of Kafka 0.8.1.1 the shutdown timeout of a Kafka broker is hardcoded to 30
      seconds (cf. [KAFKA-1342](https://issues.apache.org/jira/browse/KAFKA-1342)).  Doing the math, a controlled
      shutdown of Kafka using the default broker configuration settings will take about `3x (30s + 5s) = 105s`.

GENERAL

* bootstrap: Use new GitHub.com URL for retrieving raw user content.


## 2.0.1 (April 24, 2014)

IMPROVEMENTS

* Move user/group management into a separate Puppet class `kafka::users` to enforce correct resource ordering
  regardless of whether the module should or should not manage the user/group.  This way we can make sure that the user
  and group are available before we set permissions on files and directories.

BACKWARDS INCOMPATIBILITIES

* Remove the `$group_manage` parameter.  The `$user_manage` parameter now enables/disables both the user and the group
  management.


## 2.0.0 (April 09, 2014)

IMPROVEMENTS

* Simplify how this module is configured in Hiera, at the expense of breaking backwards compatibility by removing the
  feature to run multiple broker instances on the same machine.
* Introduces `config.pp`.
* The functionality of the previous `broker.pp` code was split into `install.pp`, `config.pp`, and `service.pp`.
  Parameters are now exclusively defined through `init.pp`, with defaults in `params.pp`.
* Adds more unit tests.

BACKWARDS INCOMPATIBILITIES

* Remove support for running multiple Kafka broker instances on the same box.
    * As part of this change the functionality of the defined type `kafka::broker` was merged into `kafka::service`.
* Remove `$kafka::global_config_map` `$kafka::broker::config_map` parameters, which have been superceded by
  `$kafka::config_map`.
* Default value of `$log_dirs` changed from `['/app/kafka-broker-0']` to `['/app/kafka/log']`
* The broker ID index suffix was removed from various configuration and log files.  Examples:
    * `server-0.properties` becomes `server.properties`.
    * `log4j-0.properties` becomes `log4j.properties`.
    * `daemon-gc-0.log` becomes `daemon-gc.log`.
    * `state-change-0.log` becomes `state-change.log`.
    * And so on.
* Default value of `$tmpfs` changed from `/tmpfs-0` to `/tmpfs`.
* The supervisord service name does not include the broker ID anymore because we do not support multiple broker
  instances per target machine.  For instance, the default service name is changed from `kafka-broker-0` to
  `kafka-broker`.


## 1.0.7 (April 09, 2014)

IMPROVEMENTS

* Add `$kafka::global_config_map` to facilitate sharing Kafka config settings between broker instances.


## 1.0.6 (April 08, 2014)

IMPROVEMENTS

* Remove `puppetlabs/stdlib` from `Modulefile` to decouple us from PuppetForge.


## 1.0.5 (March 25, 2014)

IMPROVEMENTS

* Add experimental support to write Kafka (data) log files to a tmpfs mount.  See the new class parameters
  `$tmpfs_manage` (default: false), `$tmpfs_path`, and `$tmpfs_size` in `broker.pp`.  Note that you want to use tmpfs
  only in rare scenarios.


## 1.0.4 (March 24, 2014)

IMPROVEMENTS

* Add `compile` test for `kafka::broker`.


## 1.0.3 (March 17, 2014)

IMPROVEMENTS

* Add `$user_manage` and `$group_manage` parameters.
* Add more unit tests.


## 1.0.2 (March 14, 2014)

IMPROVEMENTS

* Initial support for testing this module.
    * A skeleton for acceptance testing (`rake acceptance`) was also added.

BACKWARDS INCOMPATIBILITY

* Change default value of `$package_ensure` from "latest" to "present".
* Puppet module fails if run on an unsupported platform.  Currently we only support the RHEL OS family.

BUG FIXES

* Properly generate broker configuration when multiple directories are specified for `$log_dirs`.


## 1.0.1 (March 11, 2014)

IMPROVEMENTS

* Recursively create directories defined via `$log_dirs` if needed.


## 1.0.0 (February 25, 2014)

* Initial release.

