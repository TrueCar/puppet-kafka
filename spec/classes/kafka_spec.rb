require 'spec_helper'

describe 'kafka' do
  context 'supported operating systems' do
    ['RedHat'].each do |osfamily|
      ['RedHat', 'CentOS', 'Amazon', 'Fedora'].each do |operatingsystem|
        let(:facts) {{
          :osfamily        => osfamily,
          :operatingsystem => operatingsystem,
        }}

        default_broker_configuration_file  = '/opt/kafka/config/server.properties'
        default_logging_configuration_file = '/opt/kafka/config/log4j.properties'

        context "with explicit data (no Hiera)" do

          describe "kafka with default settings on #{osfamily}" do
            let(:params) {{ }}
            # We must mock $::operatingsystem because otherwise this test will
            # fail when you run the tests on e.g. Mac OS X.
            it { should compile.with_all_deps }

            it { should contain_class('kafka::params') }
            it { should contain_class('kafka') }
            it { should contain_class('kafka::users').that_comes_before('kafka::install') }
            it { should contain_class('kafka::install').that_comes_before('kafka::config') }
            it { should contain_class('kafka::config') }
            it { should contain_class('kafka::service').that_subscribes_to('kafka::config') }

            it { should contain_package('kafka').with_ensure('present') }

            it { should contain_group('kafka').with({
              'ensure'     => 'present',
              'gid'        => 53002,
            })}

            it { should contain_user('kafka').with({
              'ensure'     => 'present',
              'home'       => '/home/kafka',
              'shell'      => '/bin/bash',
              'uid'        => 53002,
              'comment'    => 'Kafka system account',
              'gid'        => 'kafka',
              'managehome' => true,
            })}

            it { should contain_file('/opt/kafka/logs').with({
              'ensure' => 'directory',
              'owner'  => 'kafka',
              'group'  => 'kafka',
              'mode'   => '0755',
            })}

            it { should contain_file('/var/log/kafka').with({
              'ensure' => 'directory',
              'owner'  => 'kafka',
              'group'  => 'kafka',
              'mode'   => '0755',
            })}

            it { should contain_file(default_broker_configuration_file).with({
                'ensure' => 'file',
                'owner'  => 'root',
                'group'  => 'root',
                'mode'   => '0644',
              }).
              with_content(/^broker.id=0$/).
              with_content(/^port=9092$/).
              with_content(/^log.dirs=\/app\/kafka\/log$/).
              with_content(/^zookeeper.connect=localhost:2181$/)
            }

            it { should contain_file(default_logging_configuration_file).with({
                'ensure' => 'file',
                'owner'  => 'root',
                'group'  => 'root',
                'mode'   => '0644',
              }).
              with_content(/^log4j.appender.kafkaAppender.File=\/var\/log\/kafka\/server.log$/).
              with_content(/^log4j.appender.stateChangeAppender.File=\/var\/log\/kafka\/state-change.log$/).
              with_content(/^log4j.appender.requestAppender.File=\/var\/log\/kafka\/kafka-request.log$/).
              with_content(/^log4j.appender.controllerAppender.File=\/var\/log\/kafka\/controller.log$/)
            }

            it { should contain_file('kafka-log-directory-/app/kafka/log').with({
              'ensure'       => 'directory',
              'path'         => '/app/kafka/log',
              'owner'        => 'kafka',
              'group'        => 'kafka',
              'mode'         => '0750',
              'recurse'      => true,
              'recurselimit' => 0,
            })}

            it { should_not contain_file('/tmpfs') }
            it { should_not contain_mount('/tmpfs') }

            it { should contain_supervisor__service('kafka-broker').with({
              'ensure'      => 'present',
              'enable'      => true,
              'command'     => '/opt/kafka/bin/kafka-run-class.sh kafka.Kafka /opt/kafka/config/server.properties',
              'environment' => """JMX_PORT=9999,KAFKA_GC_LOG_OPTS=\"-Xloggc:/var/log/kafka/daemon-gc.log -verbose:gc -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps\",KAFKA_HEAP_OPTS=\"-Xmx256M\",KAFKA_JMX_OPTS=\"-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false\",KAFKA_JVM_PERFORMANCE_OPTS=\"-server -XX:+UseCompressedOops -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -XX:+CMSScavengeBeforeRemark -XX:+DisableExplicitGC -Djava.awt.headless=true\",KAFKA_LOG4J_OPTS=\"-Dlog4j.configuration=file:/opt/kafka/config/log4j.properties\",""",
              'user'        => 'kafka',
              'group'       => 'kafka',
              'autorestart' => true,
              'startsecs'   => 10,
              'retries'     => 999,
              'stopsignal'  => 'INT',
              'stopasgroup' => true,
              'stopwait'    => 120,
              'stdout_logfile_maxsize' => '20MB',
              'stdout_logfile_keep'    => 5,
              'stderr_logfile_maxsize' => '20MB',
              'stderr_logfile_keep'    => 10,
            })}
          end

          describe "kafka with limits_manage enabled on #{osfamily}" do
            let(:params) {{
              :limits_manage => true,
            }}
            it { should contain_limits__fragment('kafka/soft/nofile').with_value(65536) }
            it { should contain_limits__fragment('kafka/hard/nofile').with_value(65536) }
          end

          describe "kafka with disabled user management on #{osfamily}" do
            let(:params) {{
              :user_manage  => false,
            }}
            it { should_not contain_group('kafka') }
            it { should_not contain_user('kafka') }
          end

          describe "kafka with custom user and group on #{osfamily}" do
            let(:params) {{
              :user_manage      => true,
              :gid              => 456,
              :group            => 'kafkagroup',
              :uid              => 123,
              :user             => 'kafkauser',
              :user_description => 'Apache Kafka user',
              :user_home        => '/home/kafkauser',
            }}

            it { should_not contain_group('kafka') }
            it { should_not contain_user('kafka') }

            it { should contain_user('kafkauser').with({
              'ensure'     => 'present',
              'home'       => '/home/kafkauser',
              'shell'      => '/bin/bash',
              'uid'        => 123,
              'comment'    => 'Apache Kafka user',
              'gid'        => 'kafkagroup',
              'managehome' => true,
            })}

            it { should contain_group('kafkagroup').with({
              'ensure'     => 'present',
              'gid'        => 456,
            })}
          end

          describe "kafka with a custom broker id on #{osfamily}" do
            let(:params) {{
              :broker_id => 23,
            }}

            it { should contain_file(default_broker_configuration_file).with_content(/^broker.id=23$/) }
          end

          describe "kafka with a custom port on #{osfamily}" do
            let(:params) {{
              :broker_port => 9093,
            }}

            it { should contain_file(default_broker_configuration_file).with_content(/^port=9093$/) }
          end

          describe "kafka with a single custom ZK server for $zookeeper_connect on #{osfamily}" do
            let(:params) {{
              :zookeeper_connect => ['zookeeper1:1234'],
            }}

            it { should contain_file(default_broker_configuration_file).
              with_content(/^zookeeper.connect=zookeeper1:1234$/)
            }
          end

          describe "kafka with a custom three-node ZK quorum for $zookeeper_connect on #{osfamily}" do
            let(:params) {{
              :zookeeper_connect => ['zookeeper1:1234', 'zookeeper2:5678','zkserver3:2181'],
            }}

            it { should contain_file(default_broker_configuration_file).
              with_content(/^zookeeper.connect=zookeeper1:1234,zookeeper2:5678,zkserver3:2181$/)
            }
          end

          describe "kafka with two directories for $log_dirs on #{osfamily}" do
            let(:params) {{
              :log_dirs => ['/app/kafka/log-1', '/app/kafka/log-2'],
            }}

            it { should contain_file(default_broker_configuration_file).
              with_content(/^log.dirs=\/app\/kafka\/log-1,\/app\/kafka\/log-2$/)
            }

            it { should contain_file('kafka-log-directory-/app/kafka/log-1').with({
              'ensure'       => 'directory',
              'path'         => '/app/kafka/log-1',
              'owner'        => 'kafka',
              'group'        => 'kafka',
              'mode'         => '0750',
              'recurse'      => true,
              'recurselimit' => 0,
            })}

            it { should contain_file('kafka-log-directory-/app/kafka/log-2').with({
              'ensure'       => 'directory',
              'path'         => '/app/kafka/log-2',
              'owner'        => 'kafka',
              'group'        => 'kafka',
              'mode'         => '0750',
              'recurse'      => true,
              'recurselimit' => 0,
            })}
          end

          describe "kafka with tmpfs enabled on #{osfamily}" do
            let(:params) {{
              :tmpfs_manage => true,
            }}

            it { should contain_file('/tmpfs') }

            it { should contain_mount('/tmpfs').with({
              'ensure'  => 'mounted',
              'device'  => 'none',
              'fstype'  => 'tmpfs',
              'atboot'  => true,
              'options' => "size=0k",
            })}
          end

          describe "kafka with a custom $config_map on #{osfamily}" do
            let(:params) {{
              :config_map => {
                'log.roll.hours'      => 23,
                'log.retention.hours' => 45,
              },
            }}

            it { should contain_file(default_broker_configuration_file).
              with_content(/^log\.roll\.hours=23$/).
              with_content(/^log\.retention\.hours=45$/)
            }
          end
        end

        context "with Hiera data" do

          describe "kafka with custom embedded_log_dir on #{osfamily}" do
            let(:hiera_config) { Hiera_yaml }
            hiera = Hiera.new(:config => Hiera_yaml)
            embedded_log_dir = hiera.lookup('kafka::embedded_log_dir', nil, nil)
            let(:params) {{
              :embedded_log_dir => embedded_log_dir
            }}

            it { should contain_file(embedded_log_dir).with({
                'ensure' => 'directory',
                'owner'  => 'kafka',
                'group'  => 'kafka',
                'mode'   => '0755',
              })
            }


          end

        end

      end
    end
  end

  context 'unsupported operating system' do
    describe 'kafka without any parameters on Debian' do
      let(:facts) {{
        :osfamily => 'Debian',
      }}

      it { expect { should contain_class('kafka') }.to raise_error(Puppet::Error,
        /The kafka module is not supported on a Debian based system./) }
    end
  end
end
