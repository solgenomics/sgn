package SGN::Apache2::Startup;

use strict;
use warnings;

use English;
use Carp;
use FindBin;
use File::Spec::Functions;
use File::Basename;
use File::Path;
use Path::Class;

use autodie qw/:all/;

###############

# reuse database connections rather than getting new ones every
# time a new query is made
# THIS MUST BE LOADED BEFORE DBI OR ANY OTHER MODULE THAT USES DBI
# otherwise, you get ticket #184, where the number of open databaseconnections
# you have inexplicably explodes
use Apache::DBI;

#use CXGN::Apache::Registry for request dispatch to our cgi-style scripts
use CXGN::Apache::Registry;

################

use Apache2::ServerUtil ();
use Apache2::ServerRec ();

sub import {
    my $class = shift;
    my %args = @_;

    require SGN::Context;
    my $c = SGN::Context->new;

    exists $args{vhost}
        or die "FATAL: vhost argument required for $class, e.g. 'use $class vhost => 1;'\n";

    # preload a large number of modules at server startup
    unless( exists $args{module_preload} && ! $args{module_preload} ) {
	require SGN::Apache2::Startup::Preload;
    }

    my %paths;

    # find the sgn/ basepath
    $paths{basepath} = catdir( $c->path_to() );

    # path to the root of the shipwright vessel, if we are in one
    $paths{shipwright_vessel}   = catdir($paths{basepath},updir());

    # resolve any .. or . in %paths
    $_ = Cwd::realpath($_) for values %paths;

    # flag, true if we are running under a shipwright vessel
    my $running_under_shipwright = -f catfile( $paths{shipwright_vessel}, 'etc', 'shipwright-perl-wrapper' );

    if( $running_under_shipwright ) {
        # use the shipwright lib dirs if under shipwright
        unshift @INC,
            catdir( $paths{shipwright_vessel}, 'lib', 'perl5', 'site_perl' ),
            catdir( $paths{shipwright_vessel}, 'lib', 'perl5' );
    }

    ##### now that we have set up the proper paths for perl modules,
    ##### go on with the rest of our server configuration

    if( $running_under_shipwright ) {
        my $v = $paths{shipwright_vessel};
        $ENV{PATH} = "$v/sbin:$v/bin:$v/usr/sbin:$v/usr/bin:$ENV{PATH}";
        $ENV{PROJECT_NAME} = 'SGN';
    }

    # run setup() on each of our site features
    $_->setup( $c ) for $c->enabled_features;

    # add some other configuration to the web server
    my $root_server = my $server =  Apache2::ServerUtil->server;
    unless( $c->config->{production_server} ) {
        $server->add_config(['MaxRequestsPerChild 1']);
    }

    $server = $server->next if $args{mod_perl_vhost};
    $server->add_config( $_ ) for generate_apache_config( \%paths, $c );

    # make and chown the tempfiles dir.
    # note that this mkdir and chown is going to be running as root.

    umask 000002; #< all files written by web server will be group-writable by default

    # the tempfiles_subdir() function makes and chmods the given
    # directory.  with no arguments, will make and chmod the main
    # tempfiles directory
    my $temp_subdir = $c->path_to( $c->tempfiles_subdir() );
    $c->chown_generated_dir( $temp_subdir ); #< force-set the
                                             # permissions on the
                                             # main tempfiles dir

    # also chown any subdirs that are in the temp dir.
    # this line should be removed eventually, the application itself should take
    # care of creating temp dirs if it wants.
    $c->chown_generated_dir( $_ ) for glob "$temp_subdir/*/";
}

sub generate_apache_config {
    my $paths = shift;
    my $c = shift;
    my $cfg = $c->config;

    my $rewrite_logfile = check_logfile($c, $cfg->{rewrite_log} );

    return map {[split /\n/, $_]}

            'PerlSetEnv PROJECT_NAME SGN',

            # don't output a server signature, which gives potential intruders
            # a bit too much information
            'ServerSignature Off',

            # set an environmental variable which will allow modules which are
            # used by multiple virtual hosts (for instance, CXGN::Page) to
            # find out which virtual host they are running on

            'PerlSetEnv PROJECT_NAME SGN',

            #respond to all requests by looking in this directory...
            "DocumentRoot ".catdir($paths->{basepath},$cfg->{document_root_subdir}),

             <<'',
             <Location />
               PerlOptions +GlobalRequest
             </Location>

             <<EOS
            <Directory />
              # allow symlinks to work in the site tree
              Options +FollowSymLinks
EOS
             # set the access control on this server based on the values of
             # $cfg->{production_server} and $cfg->{shared_devel_server}
            ._apache_access_control_str( $cfg )
            ."</Directory>\n",


            # set up HTML backtraces if this is not a production server
            ( $cfg->{production_server} ? () : <<EOS ),
             <Perl>
                use CGI::Carp::DebugScreen
                       debug => 1,
                       environment => 1,
                       style => qq|<style type="text/css">\n\\\@import url("$cfg->{static_site_files_url}/inc/debugscreen.css");\n</style>|;
             </Perl>
EOS

            # set up our site-specific die handlers to chain in front
            # of any existing die handlers that are set up, and make a
            # backtrace
            <<'EOS',
            <Perl>
               { my $old_die = $SIG{__DIE__} || sub { die @_ }; #< might be set by DebugScreen above
                 $SIG{__DIE__} = sub {
                     my  $die_scalar = shift;
                     my $mess = Carp::longmess();
                     $mess =~ s|[^\n]+\n||; # remove first line
                     $mess =~ s|[^\n]+RegistryCooker.+||s; # remove any apache registry lines

                     unless( $mess =~ m'eval \{' ) {
                       SGN::Context->instance->handle_exception( $die_scalar, @_ );
                       push @_, $mess;
                     }

                     $old_die->( $die_scalar, @_ );
                 };
               }
            </Perl>
EOS

            # email address for apache to include in really bad error messages
            qq|ServerAdmin $cfg->{email}|,

            #when a page is not found, go here
            "ErrorDocument 404 $cfg->{error_document}?code=404",

            # when a script dies, go here. this should usually not be
            # needed, since dies will be handled by
            # CXGN::Apache::Registry, but sometimes things break
            # badly. LEAVE THE INITIAL QUOTE IN (unless replacing this
            # with a path to a file)
            "ErrorDocument 500 $cfg->{error_document}?code=500",


            # serve files directly from /data/shared if configured
            ( $cfg->{static_datasets_url} && $cfg->{static_datasets_path} ? <<EOC : () ),
                Alias $cfg->{static_datasets_url} $cfg->{static_datasets_path}
                <Directory $cfg->{static_datasets_path}>
                    AllowOverride All
                    Options +Indexes -ExecCGI +FollowSymLinks
                    Order allow,deny
                    Allow from all
                 </Directory>
EOC

             ( $cfg->{executable_subdir} ? <<END_HEREDOC : () ),

        <Directory />
            # the favicon is expected to be right under document root, but don't execute it as a script!
            <Files favicon.ico>
                SetHandler none
            </Files>

            # the robots.txt file is expected to be right under document root, but don't execute it as a script!
            <Files robots.txt>
                SetHandler none
            </Files>
        </Directory>

        #in our cgi-bin (or equivalent) directory...
        <Directory $paths->{basepath}/$cfg->{executable_subdir}>

            AllowOverride All

            # execute cgi scripts, auto indexing of directories
            Options +ExecCGI +Indexes

            # set up perl script parsing
    	    SetHandler perl-script

            # send perl scripts to go through ModPerl::Registry
            PerlResponseHandler CXGN::Apache::Registry

            # if only a directory is specified, look for index.pl.
            DirectoryIndex index.pl index.html

            # and add the fixup handler that allows the above
            # DirectoryIndex line to work with ModPerl::Registry
            PerlFixupHandler CXGN::Apache2::DirectoryFixup

            # send things that look like http headers as http headers
            PerlSendHeader On

            # the output of our perl scripts is to be interpreted as text/html
            DefaultType text/html
    	    AddType text/html .pl

            # use CXGN custom error handlers to make appropriate crash pages (on production)
            # or send errors to browser (on devel)
        </Directory>
END_HEREDOC

             # set up default plain content-type for tempfiles subdir
             ( $cfg->{tempfiles_subdir} ? <<EOH : () ),
    <Directory $paths->{basepath}/$cfg->{tempfiles_subdir}>
        DefaultType text/plain
    </Directory>
EOH

            #where to write error messages
            "ErrorLog ".check_logfile($c, $cfg->{error_log}),
            "CustomLog ".check_logfile($c, $cfg->{access_log}).' combined',

             #if this is not a production server, enable apache debugging routines
             ( $cfg->{production_server} ? () : _apache_debugging() ),


             # load apache configurations for all enabled SGN::Feature objects
             feature_apache_confs( $c ),

	     # now add several other aliases for images, javascript, etc
             <<END_HEREDOC,
    Alias /img       $paths->{basepath}/$cfg->{static_site_files_path}/img
    Alias /js        $paths->{basepath}/$cfg->{global_js_lib}
    Alias /cgi-bin   $paths->{basepath}/cgi-bin

    Alias $cfg->{static_content_url}     $cfg->{static_content_path}
    Alias $cfg->{static_site_files_url}  $paths->{basepath}/$cfg->{static_site_files_path}

    #insitu image locations
    Alias  /fullsize_images   $cfg->{static_datasets_path}/images/insitu/processed
    Alias  /thumbnail_images  $cfg->{static_datasets_path}/images/insitu/display

    Redirect 301 /gbrowse/index.pl /tomato/genome_data.pl

END_HEREDOC

             # and now a bunch of rewrites for old stuff that used to
             # be here, these can probably be removed
             <<END_HEREDOC,
    RewriteEngine On
    RewriteLogLevel 1
    RewriteLog $rewrite_logfile

    # Redirect rules to direct old locations of CGN site under SGN, to the
    # coffee virtual host under PGN
    RewriteRule /CGN(.*) http://coffee.pgn.cornell.edu/\$1 [L,R=301]
    RewriteRule /cgn(.*) http://coffee.pgn.cornell.edu/\$1 [L,R=301]

    # Redirect rules to direct old locations in SGN to the zamir virtual host
    RewriteRule /mutants/mutants_web(.*) http://zamir.sgn.cornell.edu/mutants\$1 [L,R=301]
    RewriteRule /mutation_site/(.+) http://zamir.sgn.cornell.edu/mutation_site/\$1 [L,R=301]
    RewriteRule /mutation_images/Qtl/(.*) http://zamir.sgn.cornell.edu/Qtl/\$1 [L,R=301]
    RewriteRule /mutation_images(.+) http://zamir.sgn.cornell.edu/mutation_images\$1 [L,R=301]

    #anything SOLANDINO now goes to a single place
    RewriteRule SOLANDINO http://www.sgn.cornell.edu/about/ecosol/

    #############################################
    #pages that have moved
    #############################################
    #we moved the /cgi-bin/help/about directory up one level
    RewriteRule ^/help/about/(.*) http://www.sgn.cornell.edu/about/\$1 [L,R=301]

    #this page has moved
    RewriteRule /tools/blast/simple.pl(.*) http://www.sgn.cornell.edu/tools/blast/index.pl\$1 [L,R=301]

    # new map viewer
    RewriteCond %{QUERY_STRING}  (.*)map_id=1(.*)
    RewriteRule /mapviewer/displayWholeMap.pl http://sgn.cornell.edu/cview/map.pl?%1map_id=9%2 [L,R=301]
    RewriteRule /mapviewer/displayWholeMap.pl(.*) http://sgn.cornell.edu/cview/map.pl\$1 [L,R=301]

    # Permanent redirect rule for Rutger's Plant Cell paper supplement, which
    # now lives in our supplement/ directory
    RewriteRule /bac_annotation/(.+) http://www.sgn.cornell.edu/supplement/plantcell-14-1441/\$1 [L,R=301]

    # this page moved at some point and is still confusing google
    RewriteRule /maps/pennellii_il/pennellii_il_map.pl http://www.sgn.cornell.edu/maps/pennellii_il/index.pl [L,R=301]

    # Old Google Index links to us. 301 Return code should cause google
    # to update its index when it checks links. I hope. Meanwhile, this will
    # get people to the right place.
    # Note "^" to match null string at beginning of line, otherwise the
    # rules will match their own target, resulting in a redirect loop!
    RewriteRule ^/solanaceae-project/SOL.final.31_12_03.sent.doc.pdf http://www.sgn.cornell.edu/solanaceae-project/index.pl [L,R=301]
    RewriteRule ^/solanaceae-project/SOL_draft2_part3_20040215.pdf http://www.sgn.cornell.edu/solanaceae-project/index.pl [L,R=301]
    RewriteRule ^/maps/physical/bac_data.pl http://www.sgn.cornell.edu/maps/physical/clone_info.pl [L,R=301]
    RewriteRule /legacy/markers/(.*) http://www.sgn.cornell.edu/markers/\$1 [L,R=301]
    RewriteRule /legacy/microarray/(.*) http://www.sgn.cornell.edu/microarray/\$1 [L,R=301]
    RewriteRule /legacy/tgc/(.*) http://www.sgn.cornell.edu/tgc/\$1 [L,R=301]
    RewriteRule /legacy/mutants/(.*) http://www.sgn.cornell.edu/mutants/\$1 [L,R=301]
    RewriteRule ^/mapviewer/mapTop.pl http://www.sgn.cornell.edu/cview/map.pl [L,R=301]
    RewriteRule ^/mapviewer/mapviewerHome.pl http://www.sgn.cornell.edu/cview/index.pl [L,R=301]
    RewriteRule ^/maps/tomato_arabidopsis/synteny_map.html http://www.sgn.cornell.edu/maps/tomato_arabidopsis/index.pl [L,R=301]
    RewriteRule ^/maps/mapviewer/mapviewerAbout.html http://www.sgn.cornell.edu/help/cview.pl [L,R=301]
    RewriteRule ^/solpeople/posts.pl http://www.sgn.cornell.edu/forum/posts.pl [L,R=301]
    RewriteRule ^/solpeople/topics.pl http://www.sgn.cornell.edu/forum/topics.pl [L,R=301]

    #all cgi-bin files are now located at document root
    RewriteRule ^/cgi-bin(.*) http://www.sgn.cornell.edu\$1 [L,R=301]
    #all formerly static pages now have similar URLs but with .pl extensions
    RewriteRule ^(.*)\\\\.html http://www.sgn.cornell.edu\$1.pl [L,R=301]
    #all images, ppts, pdfs, and everything else except perl scripts, the favicon, and robots.txt are now in the /documents folder
    RewriteRule ^(/(community|content|forum|gbrowse|help|img|maps|markers|methods|microarray|misc|mutants|sgn_photos|solanaceae-project|supplement).*\.(jpe?g|ppt|pdf|gif|png|txt|gz|zip)) http://www.sgn.cornell.edu/documents\$1 [L,R=301]

 	#if the domain name begins with 'secretary', redirect all perl script (and only perl script) requests to secretary subfolder in sgn's cgi-bin
    RewriteCond \%{HTTP_HOST} ^secretary [NC]
    RewriteRule ^/(.*\\.pl) /secretary/\$1

END_HEREDOC

}

# given the context obj, return list of apache conf strings for each
# of the activated features
sub feature_apache_confs {
    map $_->apache_conf, shift->enabled_features
}


# no arguments looks at the values of $self->{production_server} and
# $hostconf{shared_devel_server} to generate an access control
# configuration
sub _apache_access_control_str {
    my $cfg = shift;

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
    my $file = catfile(@_);

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

sub tee(@) {
    my @args = @_;
    for( @args ) {
        if( ref ) {
            print Dumper $_;
        } else {
            print "$_\n"
        }
    }
    return @args;
}

# =head1 NAME

# CXGN::Apache2::DirectoryFixup - mod_perl fixup handler module to allow
# DirectoryIndex usage under directories managed by ModPerl::Registry

# =head1 FUNCTIONS

#  All functions below are EXPORT_OK.

# =cut

package CXGN::Apache2::DirectoryFixup;

use strict;
use warnings FATAL => qw(all);

use Apache2::Const -compile => qw(DIR_MAGIC_TYPE OK DECLINED);
use Apache2::RequestRec;

sub handler {

  my $r = shift;

  if ($r->handler eq 'perl-script' &&
      -d $r->filename              &&
      $r->is_initial_req)
  {
    $r->handler(Apache2::Const::DIR_MAGIC_TYPE);

    return Apache2::Const::OK;
  }

  return Apache2::Const::DECLINED;
}


###
1;#do not remove
###


__END__

=head1 NAME

startup.pl - startup script to configure Apache for running SGN

This script is meant to be run from your httpd.conf via

  PerlRequire "path/to/this/startup.pl"

=head1 SYNOPSIS

  startup.pl

  Options:

    none yet

=head1 MAINTAINER

Robert Buels

=head1 AUTHOR

Robert Buels, E<lt>rmb32@cornell.eduE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
