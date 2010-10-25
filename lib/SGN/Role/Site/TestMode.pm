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

=head2 test_mode

read-only accessor, boolean telling whether the site is now running in test mode

=cut

has 'test_mode' => (
    is  => 'ro',
    isa => 'Bool',
    default => sub {
        my $c = shift;
        my $app_name = ref $c || $c;
        #warn "app is $app_name, test mode is ".$ENV{ uc($app_name).'_TEST_MODE' };
        return $ENV{ uc($app_name).'_TEST_MODE' };
    },
);



########### helper subs #######

# if in test mode, filter conf variables, if 
sub _reroot_test_mode_files {
    my $c = shift;

    return unless $c->test_mode;

    my $filter_conf_keys = $c->config->{'Plugin::Site::TestMode'}->{reroot_conf}
        or return;

    my $test_files_path_abs = $c->config->{'Plugin::Site::TestMode'}->{test_data_dir};
    my $test_files_path_rel = File::Spec->abs2rel( $test_files_path_abs, $c->path_to );

    my $test_mode_applyer = Data::Visitor::Callback->new(
        plain_value => sub {
            if( File::Spec->file_name_is_absolute( $_ ) ) {
                $_ = File::Spec->catfile( $test_files_path_abs, File::Spec->abs2rel( $_, File::Spec->rootdir)  );
            } else {
                $_ = File::Spec->catfile( $test_files_path_rel, $_ );
            }
        },
       );

    for my $path ( @$filter_conf_keys ) {
        my ( $conf, $varname ) = $c->_resolve_conf_key_path( $path );
        next unless $conf && $conf->{$varname};
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
