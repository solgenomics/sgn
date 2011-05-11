use strict;
use warnings;

use CXGN::People::Person;

use CGI qw/ param /;

use CXGN::DB::Connection;
use CXGN::Phenome::Locus;

use CatalystX::GlobalContext qw( $c );

my $q   = CGI->new();
my $dbh = CXGN::DB::Connection->new();

my $user =
    $c->user_exists
  ? $c->user->get_object
  : CXGN::People::Person->new( $dbh, undef );

my $locus_id = $q->param("locus_id") + 0;
my $action   = $q->param("action");

# print message if locus_id is not valid
unless ( $locus_id || $action eq 'new' && !$locus_id ) {

    $c->throw( is_client_error => 1, public_message => 'Invalid arguments' );

}

my $locus = CXGN::Phenome::Locus->new( $dbh, $locus_id );

# print message if the locus is obsolete
if ( $locus->get_obsolete() eq 't'
    && ( !$user || $user->get_user_type ne 'curator' ) )
{
    $c->throw(
        is_client_error   => 0,
        title             => 'Obsolete locus',
        message           => "Locus $locus_id is obsolete!",
        developer_message => 'only curators can see obsolete loci',
        notify => 0,    #< does not send an error email
    );
}

# print message if locus_id does not exist
if ( !$locus->get_locus_id() && $action ne 'new' && $action ne 'store' ) {
    $c->throw_404('No locus exists for this identifier');
}

my @locus_xrefs =

  # 4. look up xrefs for all of them
  map $c->feature_xrefs( $_, { exclude => 'locuspages' } ),

  # 3. plus primary locus name
  $locus->get_locus_name,

  # 2. list of locus alias strings
  map $_->get_locus_alias,

  # 1. list of locus alias objects
  $locus->get_locus_aliases( 'f', 'f' );

$c->forward_to_mason_view(
    '/locus/index.mas',
    action   => $action,
    locus    => $locus,
    locus_id => $locus_id,
    user     => $user,
    dbh      => $dbh,
    xrefs    => \@locus_xrefs,
);

#############

