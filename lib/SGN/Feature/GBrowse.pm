=head1 NAME

SGN::Feature::GBrowse - site feature object to provide GBrowse integration

=cut

package SGN::Feature::GBrowse;
use Moose;
use namespace::autoclean;

extends 'SGN::Feature';

use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class qw | Dir File |;
use MooseX::Types::URI 'Uri';
use HTML::Mason::Interp;

{ my $pi = subtype as 'ArrayRef';
  coerce $pi,
      from 'Value',
      via { [$_] };

  has 'perl_inc' => ( documentation => 'arrayref of paths to set in PERL5LIB if running in fastcgi or cgi mode',
    is => 'ro',
    isa => $pi,
    default => sub { [] },
    coerce => 1,
   );
}

has '+description' => (
    default => 'Genome browser',
   );

has 'conf_dir' => ( documentation => 'directory where GBrowse will look for its conf files',
    is => 'ro',
    isa => Dir,
    coerce => 1,
    lazy_build => 1,
   ); sub _build_conf_dir { my $self = shift; $self->tmpdir->subdir( 'rendered_conf' ) }

has 'conf_template_dir' => ( documentation => <<'EOD',
directory for configuration templates, which will be rendered on a one-to-one basis into $self->conf_dir during setup()
EOD
    is => 'ro',
    isa => Dir,
    coerce => 1,
    lazy_build => 1,
   ); sub _build_conf_template_dir { shift->path_to('conf','templates') }

has 'static_url' => ( documentation => 'URL base for GBrowse static files',
    is => 'ro',
    isa => 'Str',
    required => 1,
   );

has 'static_dir' => (
    is => 'ro',
    isa => Dir,
    coerce => 1,
    required => 1,
   );

has 'cgi_url' => (
    is => 'ro',
    isa => Uri,
    required => 1,
    coerce => 1,
   );
has 'cgi_bin' => (
    is => 'ro',
    isa => Dir,
    coerce => 1,
    required => 1,
   );

has 'tmp_dir' => (
    is => 'ro',
    isa => Dir,
    coerce => 1,
    required => 1,
   );

has 'run_mode' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
   );


# default database connection info used by gbrowse
has 'default_db_host' => (
    is  => 'ro',
    isa => 'Str',
    lazy_build => 1,
   ); sub _build_default_db_host {
       my $dsn = shift->context->dbc_profile->{dsn};
       return unless $dsn =~ /host=([^;]+)/;
       return $1;
   }
has 'default_db_user' => (
    is  => 'ro',
    isa => 'Str',
    lazy_build => 1,
   ); sub _build_default_db_user {
       shift->context->dbc_profile->{user};
   }
has 'default_db_password' => (
    is  => 'ro',
    isa => 'Str',
    lazy_build => 1,
   ); sub _build_default_db_password {
       shift->context->dbc_profile->{password};
   }


sub local_inc {
    'local @INC = ( '.join(', ',map "'$_'",@INC).' );';
}


# assembles a URI linking to gbrowse.
sub link_uri {
    my ( $self, $conf_name, $params ) = @_;

    my $uri = URI->new($self->cgi_url."/$conf_name/");
    $uri->query_form( %$params );
    return $uri;
}


after setup => sub {
    my ( $self, $c ) = @_;
    $self->render_all_configs;
};

sub xrefs {
    my ( $self, $q ) = @_;
    return unless defined $q;

    # go through each data source and give it a crack at it
    return map $_->xrefs($q), $self->data_sources;
}

sub data_sources {
    die 'data_sources not yet implemented for gbrowse 1.x';
}


# for each .mas file in the $self->conf_template_dir directory, run
# templating on it and put the output in $self->conf_dir under the
# same filename, without the ending .mas
sub render_all_configs {
    my $self = shift;

    # all .mas files in the conf_template_dir
    my @template_files;
    $self->conf_template_dir->recurse(
        callback => sub {
            my ($child) = @_;
            return if $child->is_dir || $child !~ /\.mas$/ || $child =~ /^#/ || $child =~ /~$/;
            push @template_files, $child;
        });

    foreach my $template_file (@template_files) {

        # assemble our target filename, which is the same file name
        # (minus the .mas), in the $self->conf_dir directory
        my $render_target_relative = $template_file->relative( $self->conf_template_dir );
        $render_target_relative =~ s/\.mas$//;
        my $render_target = $self->conf_dir->file( $render_target_relative );

        $render_target->dir->mkpath;
        $self->render_config_template( $template_file => $render_target );
    }

    # also symlink other things in the conf dir into there
    for my $conf_thing ( $self->conf_template_dir->parent->children ) {
        my $link_target = $self->conf_dir->file( $conf_thing->relative( $conf_thing->parent ) );
        unlink $link_target;
        symlink $conf_thing, $link_target
            or die "$! linking $conf_thing -> $link_target";
    }
}

sub render_config_template {
    my ( $self, $template_file, $render_target ) = @_;

    # render the template into the target file
    # my $outbuf;
    # my $mason = HTML::Mason::Interp
    #     ->new( allow_globals => [qw[ $c $feature ]],
    #            autohandler_name => '',
    #            comp_root => [['conf_templates', $self->conf_template_dir->stringify ]],
    #            out_method => \$outbuf,
    #           );
    # $mason->set_global( '$c'       => $self->context );
    # $mason->set_global( '$feature' => $self          );

    # $mason->exec( '/'.$template_file->relative( $self->conf_template_dir) ); #< mason's default search path is current working directory

    # $render_target->openw->print( $outbuf );
}

# # returns a string of apache configuration to be included during
# # startup. will be part of plugin role
# sub apache_conf {
#     my ( $self ) = @_;
#     my $dir         = $self->static_dir;
#     my $conf        = $self->conf_dir;
#     my $cgibin      = $self->cgi_bin;
#     my $tmp         = $self->tmp_dir;
#     my $cgiroot     = basename($cgibin);
#     my $perl5lib    = $self->added_to_INC;
#     my $inc         = $perl5lib ? "SetEnv PERL5LIB \"$perl5lib\""   : '';
#     my $fcgi_inc    = $perl5lib ? "-initial-env PERL5LIB=$perl5lib" : '';
#     my $fcgid_inc   = $perl5lib ? "DefaultInitEnv PERL5LIB $perl5lib"        : '';
#     my $modperl_inc = $inc ? "Perl$inc" : '';
#     my $url_base    = $self->url_base;

#     my %runmode_conf = (
# 	modperl => <<"",
#    Alias /$url_base "$cgibin"
#    <Location /mgb2>
#      SetHandler perl-script
#      PerlResponseHandler ModPerl::Registry
#      PerlOptions +ParseHeaders
#      PerlSetEnv GBROWSE_CONF "$conf"
#      $modperl_inc
#    </Location>

# 	fcgi => <<"",
#   Alias /$url_base "$cgibin"
#   <Location /fgb2>
#     SetHandler   fcgid-script
#     Options      ExecCGI
#   </Location>
#   DefaultInitEnv GBROWSE_CONF $conf
#   $fcgid_inc

# 	fastcgi => <<"",
#   Alias /$url_base "$cgibin"
#   <Location /fgb2>
#     SetHandler   fastcgi-script
#     Options      ExecCGI
#   </Location>
#   FastCgiConfig $fcgi_inc -initial-env GBROWSE_CONF=$conf

# 	cgi => <<"",
# ScriptAlias  "/$url_base"   "$cgibin"
# <Directory "$cgibin">
#   $inc
#   SetEnv GBROWSE_CONF "$conf"
# </Directory>

#        );

#     my $runmode_conf = $runmode_conf{ $self->run_mode }
# 	or confess "invalid run mode '".$self->run_mode."'";

#     return <<EOC;
# Alias        "/$url_base/static/i/" "$tmp/images/"
# Alias        "/$url_base/static"    "$dir"

# <Directory "$dir">
#   Options -Indexes -MultiViews +FollowSymLinks
# </Directory>

# $runmode_conf
# EOC
# }

__PACKAGE__->meta->make_immutable;

1;
