=head1 NAME

SGN::Role::Site::TestMode - adds the concept of 'test mode' to a site

=cut

package SGN::Role::Site::TestMode;

use Moose::Role;
use namespace::autoclean;

use Carp;
use File::Spec;

use Data::Visitor::Callback;

requires 'config', 'path_to', 'finalize_config';

after 'finalize_config' => \&_reroot_test_mode_files;

=head1 DESCRIPTION

This role requires that Catalyst::Plugin::ConfigLoader (or other
plugin providing finalize_config) be activated.

It does two things: adds a C<test_mode> attribute, and reroots
paths to files and directories in the global configuration if the app
is in test mode.

=head1 METHODS

=head2 test_mode

read-only sub, boolean telling whether the site is now running in
test mode.

By default, this attribute is true if the MYAPP_TEST_MODE environment
variable is set to a true value.

=cut

sub test_mode {
    my $c = shift;
    my $app_name = ref($c) || $c;
    return $ENV{ uc($app_name).'_TEST_MODE' };
}

=head1 CONFIGURATION PATH REROOTING

At load time, if the app is running in test mode, this role will
reroot paths in the global configuration to point into a tree of test
data instead of wherever they were pointing before.

Example configuration:

    MyApp->config(

      # TestMode configuration
      'Plugin::Site::TestMode' => {
          reroot_conf    => [ 'foo', 'bar/baz' ],
          test_data_dir => '__path_to(t/data)__',
      },

      # other conf data
      foo => 'my/relative/path',
      bar => {
         quux => '/some/path',
         baz  => '/absolute/path',
      }
    )

This configuration, if MYAPP_TEST_MODE is set, will be rerootd by the
TestMode plugin into:

    MyApp->config(

      # TestMode configuration
      'Plugin::Site::TestMode' => {
          reroot_conf    => [ 'foo', 'bar/baz' ],
          test_data_dir => '__path_to(t/data)__',
      },

      # other conf data
      foo => 't/data/my/relative/path',
      bar => {
         quux => '/some/path',
         baz  => '/path/to/myapp/t/data/absolute/path',
      }
    )


This is controlled by the C<reroot_conf> and C<test_data_dir>
configuration variables.  C<reroot_conf> takes an arrayref of conf
variable names to reroot as if they were path names (using a
/-separated syntax to denote non-top-level conf variables), and
C<test_data_dir> takes the absolute path to the directory in which the
test data file tree resides.

Note that relative paths are kept relative, and assumed to be intended
as relative to the site's home directory.  You cannot currently reroot
a relative path unless it is relative to the site home directory.

Additionally, you can force a rerooted conf var to be treated as either
absolute or relative by adding a prefix of either C<(abs)> or C<(rel)>
to the beginning of the conf name.

=cut

########### helper subs #######

# if in test mode, filter conf variables, if 
sub _reroot_test_mode_files {
    my $c = shift;

    return unless $c->test_mode;

    my $filter_conf_keys = $c->config->{'Plugin::TestMode'}->{reroot_conf}
        or return;


    # parse any (rel) or (abs) declarations on the conf keys
    $filter_conf_keys = [
        map {
            [ m/^ (\( (?:abs|rel) \))? (.+)/x ]
        } @$filter_conf_keys
    ];

    my $test_files_path_abs = $c->config->{'Plugin::TestMode'}->{test_data_dir};
    my $test_files_path_rel = File::Spec->abs2rel( $test_files_path_abs, $c->path_to );

    for my $key_rec ( @$filter_conf_keys ) {
        my ( $prefix, $path ) = @$key_rec;

        my ( $conf, $varname ) = $c->_resolve_conf_key_path( $path );
        next unless $conf && $conf->{$varname};

        my $test_mode_applyer = Data::Visitor::Callback->new(
            plain_value => sub {
                my $force_abs = $prefix && $prefix eq '(abs)';
                my $force_rel = $prefix && $prefix eq '(rel)';

                if( $force_rel || !File::Spec->file_name_is_absolute( $_ ) ) {
                    if( $force_rel and my $leading_slash = m!^/! ) {
                        $_ = "/$test_files_path_rel$_";
                    } else {
                        $_ = File::Spec->catfile( $test_files_path_rel, $_ );
                    }
                }
                else {
                    $_ = File::Spec->catfile( $test_files_path_abs, File::Spec->abs2rel( $_, File::Spec->rootdir)  );
                }
            },
           );
        $test_mode_applyer->visit( $conf->{$varname} )
    }
}

# takes a path expression into the conf like
# 'Plugin::ConfigLoader/blah_blah' and finds the parent hashref that
# holds that conf key, and the conf key itself
sub _resolve_conf_key_path {
    my ( $c, $path_expr ) = @_;

    my @path_components = split /\//, $path_expr;
    # no leading blanks
    shift @path_components while @path_components && !$path_components[0];

    my $path_end = pop @path_components;
    my $parent = $c->config;
    $parent = $parent->{ shift @path_components } while $parent && @path_components;
    return ( $parent, $path_end );
}


1;
