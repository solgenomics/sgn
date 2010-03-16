=head1 NAME

SGN::Feature::GBrowse2 - subclass of L<SGN::Feature::GBrowse> that tweaks the apache conf for GBrowse 2

=cut

package SGN::Feature::GBrowse2;
use MooseX::Singleton;
use namespace::autoclean;
extends 'SGN::Feature::GBrowse';

# returns a string of apache configuration to be included during
# startup. will be part of plugin role
sub apache_conf {
    my ( $self ) = @_;

    my $static_dir  = $self->static_dir;
    my $static_url  = $self->static_url;

    my $conf        = $self->conf_dir;
    my $cgibin      = $self->cgi_bin;
    my $inc         = $self->perl_inc;
    my $fcgi_inc    = @$inc ? "DefaultInitEnv PERL5LIB ".join(':',@$inc) : '';
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
  DefaultInitEnv GBROWSE_CONF $conf
  $fcgi_inc

	cgi => <<"",
ScriptAlias $cgi_url  "$cgibin"
<Directory "$cgibin">
  $cgi_inc
  SetEnv GBROWSE_CONF "$conf"
</Directory>

);

    my $runmode_conf = $runmode_conf{ $self->run_mode }
	or confess "invalid run mode '".$self->run_mode."'";

    return <<EOC; die 'break';
Alias        "$static_url/i/" "$tmp/images/"
Alias        "$static_url"    "$static_dir"

<Directory "$static_dir">
  Options -Indexes -MultiViews +FollowSymLinks
</Directory>

$runmode_conf
EOC

}

1;
