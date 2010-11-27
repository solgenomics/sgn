use strict;
use warnings;


use CXGN::People::Person;

use CGI qw / param /;

use CXGN::DB::Connection;
use CXGN::Phenome::Locus;

use CatalystX::GlobalContext qw( $c );

my $q   = CGI->new();
my $dbh = CXGN::DB::Connection->new();

my $user = $c->user_exists ? $c->user->get_object : undef;

my $locus_id = $q->param("locus_id") + 0;
my $action   = $q->param("action");

# print message if locus_id is not valid 
unless (    $locus_id =~ m /^\d+$/
         || $action eq 'new' && !$locus_id
       ) {

  $c->throw_404('No locus exists for this identifier');
}

my $locus = CXGN::Phenome::Locus->new( $dbh, $locus_id );

# print message if the locus is obsolete 
if ( $locus->get_obsolete() eq 't' && (!$user || $user->get_user_type ne 'curator') ) {
    $c->throw( is_client_error => 0,
	       title   => 'Obsolete locus',
	       message =>"Locus $locus_id is obsolete!",
               developer_message => 'only curators can see obsolete loci',
               notify => 0,   #< does not send an error email
              );
}

# print message if locus_id does not exist
if ( !$locus->get_locus_id() && $action ne 'new' && $action ne 'store' ) {
  $c->throw_404('No locus exists for this identifier');
}

$c->forward_to_mason_view( '/locus/index.mas',
    action   => $action,
    locus    => $locus,
    locus_id => $locus_id ,
    user     => $user,
    dbh      => $dbh,
 );

#############

