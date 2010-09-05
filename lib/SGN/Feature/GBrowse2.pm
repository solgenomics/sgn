=head1 NAME

SGN::Feature::GBrowse2 - subclass of L<SGN::Feature::GBrowse> that tweaks the apache conf for GBrowse 2

=cut

package SGN::Feature::GBrowse2;
use Moose;
use namespace::autoclean;
extends 'SGN::Feature::GBrowse';

use Bio::Graphics::FeatureFile;

has '_data_sources' => (
    is         => 'ro',
    isa        => 'HashRef',
    traits     => ['Hash'],
    lazy_build => 1,
    handles => {
        data_sources => 'values',
        data_source  => 'get',
    },
   ); sub _build__data_sources {
       my $self = shift;

       return {} unless $self->config_master;

       my $ds_class =  __PACKAGE__.'::DataSource';
       Class::MOP::load_class( $ds_class );

       my %sources;
       foreach my $type ( $self->config_master->configured_types ) {

           # absolutify the path from the config file
           my $path = $self->config_master->setting( $type => 'path' )
               or die "no path configured for [$type] in ".$self->config_master."\n";
           $path = Path::Class::File->new( $path );
           unless( $path->is_absolute ) {
               $path = $self->conf_dir->file( $path );
           }

           $sources{$type} = $ds_class->new(
               name    => $type,
               path    => $path,
               gbrowse => $self,
               description => $self->config_master->setting( $type => 'description' ),
               extended_description => $self->config_master->setting( $type => 'extended_description' ),
              );
       }

       return \%sources;
   }

has 'config_master' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build_config_master {

       my $master_file = shift->conf_dir->file('GBrowse.conf');
       return unless -f $master_file;

       my $ff = Bio::Graphics::FeatureFile->new( -file => "$master_file" );
       $ff->safe( 1 ); #< mark the file as safe, so we can use code refs
       return $ff;
   }

sub fpc_data_sources {
    return
        sort { my ($ad,$bd) = map $_->description =~ m|(20\d\d)|,$a,$b; $bd <=> $ad }
        grep $_->description =~ /FPC/i,
        shift->data_sources;
}

# returns a string of apache configuration to be included during
# startup. will be part of plugin role
around apache_conf => sub {
    my ( $orig, $self ) = @_;

    my $upstream_conf = $self->$orig();

    my $static_dir  = $self->static_dir;
    my $static_url  = $self->static_url;

    my $conf        = $self->conf_dir;
    my $cgibin      = $self->cgi_bin;
    my $inc         = $self->perl_inc;
    my $fcgi_inc    = @$inc ? "DefaultInitEnv PERL5LIB \"".join(':',@$inc).'"' : '';
    my $cgi_inc    =  @$inc ? "SetEnv PERL5LIB ".join(':',@$inc) : '';
    my $cgi_url     = $self->cgi_url;
    my $tmp         = $self->tmp_dir;

    my %runmode_conf = (
# 	modperl => <<"",
#    Alias /$url_base "$cgibin"
#    <Location /mgb2>
#      SetHandler perl-script
#      PerlResponseHandler ModPerl::Registry
#      PerlOptions +ParseHeaders
#      PerlSetEnv GBROWSE_CONF "$conf"
#    </Location>

	fcgi => <<"",
  Alias $cgi_url "$cgibin"
  <Location $cgi_url>
    SetHandler   fcgid-script
    Options      ExecCGI
  </Location>
  DefaultInitEnv GBROWSE_CONF "$conf"
  BusyTimeout 360
  IPCCommTimeout 300
  $fcgi_inc

	cgi => <<"",
ScriptAlias $cgi_url  "$cgibin"
<Directory "$cgibin">
  $cgi_inc
  SetEnv GBROWSE_CONF "$conf"
  Order allow,deny
  Allow from all
</Directory>

       );

    my $runmode_conf = $runmode_conf{ $self->run_mode }
	or confess "invalid run mode '".$self->run_mode."'";

    return $upstream_conf.<<EOC;
Alias        "$static_url/i/" "$tmp/images/"
Alias        "$static_url"    "$static_dir"

<Location "$static_url">
    SetHandler default-handler\n"
</Location>
<Directory "$static_dir">
  Options -Indexes -MultiViews +FollowSymLinks
  Order allow,deny
  Allow from all
</Directory>

$runmode_conf
EOC

};

1;
