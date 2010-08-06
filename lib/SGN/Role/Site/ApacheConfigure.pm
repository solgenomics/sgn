package SGN::Role::Site::ApacheConfigure;
use Moose::Role;
use namespace::autoclean;

requires
    'config',
    ;

=head2 configure_mod_perl

  Status  : public
  Usage   : MyApp->configure_mod_perl( vhost => 1 );
  Returns : nothing meaningful
  Args    : hash-style list of arguments as:
             vhost => boolean of whether this
                      configuration should be applied
                      to the current virtual host (if true),
                      or the root Apache server (if false),
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
           ServerName smmid.localhost.localdomain

           <Perl>

             use lib qw( /crypt/rob/cxgn/git/local-lib/core/MyApp/lib );
             use MyApp;
             MyApp->configure_mod_perl( vhost => 1 );

           </Perl>

       </VirtualHost>

=cut

sub configure_mod_perl {
    my $self = shift;
    my $class = ref($self) || $self;
    my %args = @_;

    exists $args{vhost}
        or die "must pass 'vhost' argument to configure_mod_perl()\n";

    require Apache2::ServerUtil;
    require Apache2::ServerRec;

    my $app_name = $class->config->{name};
    my $cfg = $class->config;
    -d $cfg->{home} or die <<EOM;
FATAL: Catalyst could not figure out the home dir for $app_name, it
guessed '$cfg->{home}', but that directory does not exist.  Aborting start.
EOM
    # add some other configuration to the web server
    my $server = Apache2::ServerUtil->server;
    $server = $server->next if $args{vhost}; #< vhost currently being
                                             #configured should be first
                                             #in the list
    $server->add_config( $_ ) for map [ split /\n/, $_ ],
        (
         'ServerSignature Off',

         #respond to all requests by looking in this directory...
         "DocumentRoot $cfg->{home}",

         #where to write error messages
         "ErrorLog "._check_logfile( $cfg->{error_log} ),
         "CustomLog "._check_logfile( $cfg->{access_log} ).' combined',

         'ErrorDocument 500 "Internal server error: The server encountered an internal error or misconfiguration and was unable to complete your request. Feel free to contact us at sgn-feedback@sgn.cornell.edu and inform us of the error."',


         # allow symlinks, allow access from anywhere
         "<Directory />

             Options +FollowSymLinks

             Order allow,deny
             Allow from all

          </Directory>
         ",

         'PerlOptions +GlobalRequest',

         # set our application to handle most requests by default
         "<Location />
             SetHandler modperl
             PerlResponseHandler $class
          </Location>
         ",

#          # except set up serving /static files directly from apache,
#          # bypassing any perl code
#          'Alias /static '.File::Spec->catdir( $cfg->{home}, 'root', 'static' ),
#          "<Location /static>
#              SetHandler  default-handler
#           </Location>
#          ",
        );

}

sub _check_logfile {
    my $file = File::Spec->catfile(@_);

    return $file if -w $file;

    my $dir = File::Basename::dirname($file);

    return $file if -w $dir;

    -d $dir
        or do { my $r = File::Path::mkpath($dir); chmod 0755, $dir}
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
