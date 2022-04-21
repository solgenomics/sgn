
=head1 NAME

SGN - Catalyst-based application to run the SGN website.

=head1 SYNOPSIS

    script/sgn_server.pl

=head1 DESCRIPTION

This is the main class for the Sol Genomics Network main website.

=cut

package SGN;
use Moose;
use namespace::autoclean;

BEGIN {
    $ENV{WEB_PROJECT_NAME} = $ENV{PROJECT_NAME} = __PACKAGE__;
}

use SGN::Exception;

use Catalyst::Runtime 5.80;

=head1 ROLES

Does the roles L<SGN::Role::Site::Config>,
L<SGN::Role::Site::DBConnector>, L<SGN::Role::Site::DBIC>,
L<SGN::Role::Site::Exceptions>, L<SGN::Role::Site::Files>,
L<SGN::Role::Site::Mason>, L<SGN::Role::Site::SiteFeatures>,
L<SGN::Role::Site::TestMode>

=cut

use Catalyst qw/
     ConfigLoader
     Static::Simple
     SmartURI
     Authentication
     +SGN::Authentication::Store
     Authorization::Roles
     +SGN::Role::Site::Config
     +SGN::Role::Site::DBConnector
     +SGN::Role::Site::DBIC
     +SGN::Role::Site::Exceptions
     +SGN::Role::Site::Files
     +SGN::Role::Site::Mason
     +SGN::Role::Site::SiteFeatures
     +SGN::Role::Site::TestMode
 /;

extends 'Catalyst';

=head1 METHODS

=cut

# configure catalyst-related things.  in general, things should not be
# added here.  add them to SGN.conf, with comments.
__PACKAGE__->config(

    name => 'SGN',
    root => 'static',

    disable_component_resolution_regex_fallback => 1,

    default_view => 'Mason',

    # Static::Simple configuration
    'Plugin::Static::Simple' => {
        dirs => [qw[ css s static img documents static_content data ]],
    },

    'Plugin::ConfigLoader' => {
        substitutions => {
            UID       => sub { $> },
            USERNAME  => sub { (getpwuid($>))[0] },
            GID       => sub { $) },
            GROUPNAME => sub { (getgrgid($)))[0] },
           },
       },

    # configure SGN::Role::Site::TestMode.  These are the
    # configuration keys that it will change so that they point into
    # t/data
    'Plugin::TestMode' => {
        test_data_dir => __PACKAGE__->path_to('t','data'),
        reroot_conf   =>
            [qw(

                blast_db_path
                cluster_shared_tempdir
                ftpsite_root
                image_path
                genefamily_dir
                homepage_files_dir
                intron_finder_database
                solqtl
                static_content_path
                static_datasets_path
                trace_path

               )],
       },

    'Plugin::Cache'=>{
        backend => {
            store =>"FastMmap",
        },
    },



    'Plugin::Authentication' => {
	default_realm => 'default',
	realms => {
	    default => {
		credential => {
		    class => '+SGN::Authentication::Credentials',
		},

		store => {
		    class => "+SGN::Authentication::Store",
		    user_class => "+SGN::Authentication::User",
###		    role_column => 'roles',
		},
	    },
	},
    },

    ( $ENV{SGN_TEST_MODE} ? ( test_mode => 1 ) : () ),
);


# on startup, do some dynamic configuration
after 'setup_finalize' => sub {
    my $self = shift;

    $self->config->{basepath} = $self->config->{home};

    # all files written by web server should be group-writable
    umask 000002;

    # update the symlinks used to serve static files
    $self->_update_static_symlinks;
    
    if(! $ENV{SGN_WEBPACK_WATCH}){
	my $uid = (lstat("js/package.json"))[4];

	my $user_exists = `id $uid 2>&1`;            
    if ($user_exists =~ /no such user/) {
	    `useradd -u $uid -m devel`;
	} 

	print STDERR "\n\nUSING USER ID $uid FOR npm...\n\n\n";
        system("cd js && sudo -u $uid npm run build && cd -");
    }
};

__PACKAGE__->setup;

sub _update_static_symlinks {
    my $self = shift;

    # symlink the static_datasets and
    # static_content in the root dir so that
    # Catalyst::Plugin::Static::Simple can serve them.  in production,
    # these will be served directly by Apache

    # make symlinks for static_content and static_datasets
    my @links =
        map [ $self->config->{$_.'_path'} =>
               $self->path_to( $self->config->{root}, $self->config->{$_.'_url'} )
            ],
        qw( static_content static_datasets );

    for my $link (@links) {
        if( $self->debug ) {
            my $l1_rel = $link->[1]->relative( $self->path_to );
            $self->log->debug("symlinking static dir '$link->[0]' -> '$l1_rel'") if $self->debug;
        }
        unlink $link->[1];
        symlink( $link->[0], $link->[1] )
            or die "$! symlinking $link->[0] => $link->[1]";
    }
}

=head1 SEE ALSO

L<SGN::Controller::Root>, L<Catalyst>

=head1 AUTHOR

The SGN team

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
