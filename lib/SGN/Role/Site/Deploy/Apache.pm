package SGN::Role::Site::Deploy::Apache;
use Moose::Role;
use namespace::autoclean;
use 5.10.0;

use Carp;
use File::Spec;

requires
    'config',
    ;

=head2 configure_apache

  Status  : public
  Usage   : MyApp->configure_apache( vhost => 1, type => 'mod_perl' );
  Returns : nothing meaningful
  Args    : hash-style list of arguments as:
             vhost => boolean of whether this
                      configuration should be applied
                      to the current virtual host (if true),
                      or the root Apache server (if false),
             type  => one of the deployment types listed below
  Side Eff: adds a lot of configuration to the currently running
            apache server


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

sub configure_apache {
    my ( $class, %args ) = @_;
    $args{type} ||= 'fcgi';

    return;

    my $setup_method = "configure_apache_$args{type}";
    unless( $class->can($setup_method) ) {
        croak "'$args{type}' Apache configuration type not supported by $class";
    }
    $class->$setup_method( \%args );
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


=head1 CONFIGURATION TYPES

=head2 mod_perl

Run the application as an Apache mod_perl handler.

=cut

sub configure_apache_mod_perl {
    my ( $class, $args ) = @_;

    my $server = $class->apache_server( $args );

    my $app_name = $class->config->{name};
    my $cfg = $class->config;
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

         $class->_conf_serve_static,
         $class->_conf_features,

         <<''
         <Directory />
            Options +FollowSymLinks

            # set the access control on this server based on the values of
            # $cfg->{production_server} and $cfg->{shared_devel_server}
         .  $class->_apache_access_control_str
         ."</Directory>\n",


         # set our application to handle most requests by default
         "<Location />
             SetHandler modperl
             PerlResponseHandler $class
          </Location>
         ",

        );
}


# return configuration for serving static files with Apache
sub _conf_serve_static {
    my $class = shift;

    my $cfg = $class->config;

    # serve files directly from the static/ subdir of the site,
    # following the symlinks therein
    return
        ( map {
            qq|Alias /$_ "|.$class->path_to( $cfg->{root}, $_ ).'"',
          }
          @{ $cfg->{static}->{dirs} }
        ),
        '<Directory "'.$class->path_to($cfg->{root}).qq|">\n|
        ."    Options +Indexes -ExecCGI +FollowSymLinks\n"
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
    my $class = shift;
    if( $class->can('enabled_features') ) {
        my @confs;
        for ( $class->enabled_features ) {
            push @confs, $_->apache_conf if $_->can('apache_conf');
        }
        return @confs;
    }
    return;
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
