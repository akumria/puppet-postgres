class postgres {
    if $pgversion == "" {
        exec { '/bin/false # missing postgres version': }
    } else {
        $pgdata = "/etc/postgresql/$pgversion/main"

        package { "postgresql-common":
            ensure => installed,
            before => [
                Service['postgresql'],
            ],
            require => [
                User['postgres'],
                Group['postgres'],
            ],
        }

        package { "postgresql-$pgversion":
            ensure => installed,
            alias  => 'postgres',
            require => [
                Package['postgresql-common'],
            ],
            notify => [
                Exec["drop initial cluster"],
                Exec["create initial cluster"],
            ],
        }

        exec {"drop initial cluster":
            command     => "pg_dropcluster --stop ${pgversion} main",
            onlyif      => "test \$(su -c 'psql -lx' postgres |awk '/Encoding/ {printf tolower(\$3)}') = 'sql_asciisql_asciisql_ascii'",
            timeout     => 60,
            environment => "PWD=/",
        }

        exec {"create initial cluster":
            command => "pg_createcluster --start -e UTF8 $pgversion main",
            require => [
                Exec["drop initial cluster"],
            ]
        }

        user { 'postgres':
            ensure  => present,
            uid     => 133,
            gid     => postgres,
            require => [
                Group['postgres'],
            ],
        }

        group { 'postgres':
            ensure  => present,
            gid => 133,
        }

        file { 'pg_hba':
            mode         => 644,
            owner        => 'postgres',
            group        => 'postgres',
            path         => "/etc/postgresql/$pgversion/main/pg_hba.conf",
            notify       => Exec['postgres-reload'],
            require      => [
                User['postgres'],
                Group['postgres'],
            ],
        }

        case $pgversion {
                "9.0": {
                        $servicename = 'postgresql'
                        $servicealias = 'postgresql'
                }
                "8.4": {
                        $servicename = 'postgresql-8.4'
                        $servicealias = 'postgresql'
                }
                "8.3": {
                        $servicename = 'postgresql-8.3'
                        $servicealias = 'postgresql'
                }
                "default": {
                        $servicename = 'postgresql'
                        $servicealias = undef
                }
        }

        exec { "/etc/init.d/$servicename reload":
            refreshonly => true,
            require     => Service['postgresql'],
            alias       => 'postgres-reload',
        }

        service { $servicename:
            ensure     => running,
            enable     => true,
            hasstatus  => true,
            hasrestart => true,
            alias      => $servicealias,
            require    => [
                User['postgres'],
                Package['postgres'],
            ],
        }
    }
}

# vi:syntax=puppet:filetype=puppet:ts=4:et:
