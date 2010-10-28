=head1 NAME

SGN::Deploy::Apache - deploy the SGN site on an Apache web server

=head1 SYNOPSIS

   # in your apache conf:

   <VirtualHost *:80>

       ServerName sgn.localhost.localdomain

       PerlWarn On
       PerlTaintCheck On

       LogLevel error

       <Perl>

          use lib '/crypt/rob/cxgn/curr/sgn/lib';
          use lib '/crypt/rob/cxgn/curr/ITAG/lib';
          use lib '/crypt/rob/cxgn/curr/Phenome/lib';
          use lib '/crypt/rob/cxgn/curr/tomato_genome/lib';
          use lib '/crypt/rob/cxgn/curr/Cview/lib';
          use lib '/crypt/rob/cxgn/curr/cxgn-corelibs/lib';
          use local::lib '/crypt/rob/cpan-lib';

          use SGN::Deploy::Apache SGN => (
              type  => 'mod_perl',
              vhost => 1,
              env   => {
                 SGN_CONFIG => '/etc/cxgn/SGN.conf',
              },
          );

       </Perl>

   </VirtualHost>

=head1 METHODS

=cut

package SGN::Deploy::Apache;
use strict;
use warnings;
use 5.10.0;

use Carp;
use File::Spec;
use File::Basename;
use File::Path qw/ mkpath /;

use Class::MOP;

=head2 import( $app_class, %options )

  Status  : public
  Usage   : use SGN::Deploy::Apache MyApp => ( vhost => 1, type => 'mod_perl' );
  Returns : nothing meaningful
  Args    : app name,
            hash-style list of arguments as:

             vhost => boolean of whether this
                      configuration should be applied
                      to the current virtual host (if true),
                      or the root Apache server (if false),

             type  => one of the deployment types listed below

             env   => hashref of environment variables to set.  This
                      must be used instead of Apache's SetEnv or
                      PerlSetEnv in order for environment variables to
                      be available early enough to be used during
                      Catalyst's setup phases.

  Side Eff: loads the app, and configures the Apache environment to
            properly run it

  Configures the currently running Apache mod_perl server
  to run this application.

  Example :

    In an Apache configuration file:

       <VirtualHost *:80>

           PerlWarn On
           PerlTaintCheck On

           LogLevel error

           #the name of the virtual host we are defining
            ServerName myapp.example.com

           <Perl>

             use local::lib qw( /usr/local/MyApp/local-lib );
             use lib qw( /usr/local/MyApp/lib );

             use MyApp;
             MyApp->setup_apache( vhost => 1, type => 'fcgi' );

           </Perl>

       </VirtualHost>

=cut

sub import {
    my $class = shift;
    my $app   = shift;

    $class->configure_apache( $app, @_ );
}
sub _load_app {
    my ( $class, $app ) = @_;
    Class::MOP::load_class( $app );

    for (qw( path_to config )) {
        $app->can($_) or confess "$class requires $app to support the '$_' method";
    }
}


sub configure_apache {
    my ( $class, $app,  %args ) = @_;
    $args{type} ||= 'fcgi';

    if( my $env = $args{env} ) {
        $class->setup_env( $env );
    }

    my $setup_method = "configure_apache_$args{type}";
    unless( $class->can($setup_method) ) {
        croak "'$args{type}' Apache configuration type not supported by $class";
    }
    $class->$setup_method( $app, \%args );
}

# set the environment variables given in the hashref
sub setup_env {
    my ( $class, $env_to_add ) = @_;

    while( my ($k,$v) = each %$env_to_add ) {
        $ENV{$k} = $v;
    }
}

sub apache_server {
    my ($class, $args) = @_;
    exists $args->{vhost}
        or confess
    "'vhost' argument is required for apache mod_perl configuration\n";

    require Apache2::ServerUtil;
    require Apache2::ServerRec;

    # add some other configuration to the web server
    my $server = Apache2::ServerUtil->server;
    # vhost currently being configured should be first in apache's list
    $server = $server->next if $args->{vhost};
    return $server;
}


=head1 SUPPORTED CONFIGURATION TYPES

=head2 mod_perl

Run the application as an Apache mod_perl handler.

=cut

sub configure_apache_mod_perl {
    my ( $class, $app, $args ) = @_;

    # force CGI.pm into non-mod-perl mode so that the Catalyst CGI
    # wrapping will work.
    # notice that we do this BEFORE loading the app
    require CGI;
    $CGI::MOD_PERL = 0;

    $class->_load_app( $app );

    my $server = $class->apache_server( $args );

    my $app_name = $app->config->{name};
    my $cfg = $app->config;
    -d $cfg->{home} or confess <<EOM;
FATAL: Could not figure out the home dir for $app_name, it
guessed '$cfg->{home}', but that directory does not exist.  Aborting start.
EOM

    my $error_email = $cfg->{feedback_email} || $ENV{SERVER_ADMIN};
    $server->add_config( $_ ) for map [ split /\n/, $_ ],
        (
         'ServerSignature Off',

         # email address for apache to include in really bad error messages
         qq|ServerAdmin $cfg->{email}|,

         #where to write error messages
         "ErrorLog  ".$class->check_logfile( $cfg->{error_log} ),
         "CustomLog ".$class->check_logfile( $cfg->{access_log} ).' combined',

         # needed for CGI.pm compat
         'PerlOptions +GlobalRequest',

         ( 'ErrorDocument 500 "Internal server error: The server encountered an internal error or misconfiguration and was unable to complete your request.'
           .( $error_email ? <<"" : '"' )
Additionally, an error report could not be automatically sent, please help us by informing us of the error at $error_email."

         ),

         # set our application to handle most requests by default
         "<Location />
             SetHandler modperl
             PerlResponseHandler $app
         "
         .  $class->_apache_access_control_str( $cfg )
         ."</Location>\n",

         $class->_conf_serve_static( $app ),
         $class->_conf_features( $app ),

        );
}


# return configuration for serving static files with Apache
sub _conf_serve_static {
    my ( $class, $app ) = @_;

    my $cfg = $app->config;

    # serve files directly from the static/ subdir of the site,
    # following the symlinks therein
    return
        ( map {
            my $url = "/$_";
            my $dir = $app->path_to( $cfg->{root}, $url );
            qq|Alias $url $dir|,
            "<Location $url>\n"
            ."    SetHandler default-handler\n"
            ."</Location>\n",
          }
          'favicon.ico',
          'robots.txt',
          @{ $cfg->{static}->{dirs} }
        ),
        '<Directory '.$app->path_to($cfg->{root}).qq|>\n|
        ."    Options +Indexes -ExecCGI +FollowSymLinks\n"
        ."    Order allow,deny\n"
        ."    Allow from all\n"
        ."</Directory>\n"

}


# =head2 fcgi

# Run the application under Apache's mod_fcgid

# =cut

# sub configure_apache_fcgi {
#     confess 'Unimplemented';
# }


# given the context obj, return list of apache conf strings for each
# of the activated features
sub _conf_features {
    my ($class,$app) = @_;
    my @confs;
    if( $app->can('enabled_features') ) {
        for ( $app->enabled_features ) {
            push @confs, $_->apache_conf if $_->can('apache_conf');
        }
    }
    return @confs;
}

# no arguments looks at the values of $self->{production_server} and
# $hostconf{shared_devel_server} to generate an access control
# configuration
sub _apache_access_control_str {
    my ($class,$cfg) = @_;

    if ( $cfg->{production_server} ) {
	# for production servers, allow connections from everywhere
	<<EOT;
        # below is the access profile for a production webserver. allow connections from anywhere.
        Order allow,deny
        Allow from all
EOT
    } elsif ( $cfg->{shared_devel_server} ) {
	# for a shared development server, allow connections from just
	# a few places, and require passwords
	my $auth_user_file = "/etc/cxgn/htpasswd-sgn";
	-f $auth_user_file
	    or die "shared_devel_server enabled, but no htpasswd file ($auth_user_file) found. aborting configuration generation.";
	<<EOT
        # below is the access profile for a shared development server, only allow connections from a list of trusted hosts
        # and subnets
        AllowOverride None
        AuthName "Development site; contact $cfg->{email} to request access"
        AuthType Basic
        AuthUserFile $auth_user_file
        Require valid-user
        Order deny,allow
        Deny from all
        Allow from 127.0.0.0/16
        Allow from 132.236.157.64/26
        Allow from 128.253.40.0/26
        Allow from 132.236.81.0/24
	Allow from 128.84.197.64/26
        Satisfy Any
EOT
    } else {
	<<EOT
        # below is the access profile for a personal development server: only allow connections from 127.0.*.*
        Order deny,allow
        Deny from all
        Allow from 127.0.0.0/16
        Allow from 192.168.0.0/16
        Allow from 172.16.0.0/12
        Allow from 10.0.0.0/8
EOT
    }
}

# three different windows into apache internals:
sub _apache_debugging {
return <<EOC;

  # 1.) the Apache server status plugin
  # add a server-status location where you can monitor your 
  # you must run 'sudo a2enmod status' for this to work
  <Location /server-status>
    SetHandler server-status

    Order Deny,Allow
    Deny from all
    Allow from 127.0.1.1
    Allow from *.sgn.cornell.edu
  </Location>

  # 2.) the mod_perl status plugin
  # add a /perl-status page where you can see mod_perl-specific status
  # information
  <Location /perl-status>
   SetHandler  perl-script
   PerlHandler Apache2::Status

    Order Deny,Allow
    Deny from all
    Allow from 127.0.1.1
    Allow from *.sgn.cornell.edu
  </Location>
  PerlSetVar StatusOptionsAll On

  # 3.) support for interactive debugging of the mod_perl process
  # enable apachedb if being run in debug mode
  # under Debian, use it by running:
  # sudo APACHE_RUN_USER=www-data APACHE_RUN_GROUP=www-data /usr/sbin/apache2 -D PERLDB -X
  <IfDefine PERLDB>
      <Perl>
        use Apache::DB ();
        Apache::DB->init;
      </Perl>

      <Location />
        PerlFixupHandler Apache::DB
      </Location>

  </IfDefine>
EOC
}

sub check_logfile {
    my $context = shift;
    my $file = File::Spec->catfile(@_);

    return $file if -w $file;

    my $dir = dirname($file);

    return $file if -w $dir;

    -d $dir
        or do { my $r = mkpath($dir); chmod 0755, $dir}
        or die "cannot open log file '$file', dir '$dir' does not exist and I could not create it";

    -w $dir
        or die "cannot open log file '$file', dir '$dir' is not writable";

    return $file;
}

sub tee (@) {
    print "$_\n" for @_;
    return @_;
}



1;
