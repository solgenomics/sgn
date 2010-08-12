
=head1 NAME

qtl.t - tests for cgi-bin/qtl.pl
add_organismprop.t

=head1 DESCRIPTION

Tests for server side script cgi-bin/chado/add_organismprop.pl

=head1 AUTHORS

Naama Menda  <nm249@cornell.edu>

=cut

use strict;
use Test::More 'no_plan';
use JSON::Any;
use Test::WWW::Mechanize;
use SGN::Context;

use_ok("CXGN::DB::Connection");
use_ok("CXGN::People::Person");

my $dbh = CXGN::DB::Connection->new();

# go to page without logging in
my $mech = Test::WWW::Mechanize->new();

my $server = $ENV{SGN_TEST_SERVER}
  || die "Need SGN_TEST_SERVER environment variable set";

my $url = "$server/chado/add_organismprop.pl";
my $species = 'Solanum lycopersicum';
my $prop_name = 'sol100';
my $prop_value = 'test';

$mech->get_ok( $url );

$mech->content_like( qr/You don't have the right privileges/i, "User has no privileges. Server side script does not attempt to  store the organism! ");

# generate a new user for testing purposes
# (to be deleted right afterwards)

if( my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "testusername" ) ) {
    CXGN::People::Person->new( $dbh, $u_id )->hard_delete;
}
#
my $p = CXGN::People::Person->new($dbh);
$p->set_first_name("testfirstname");
$p->set_last_name("testlastname");
my $p_id = $p->store();

my $login = CXGN::People::Login->new( $dbh, $p_id );
$login->set_username("testusername");
$login->set_password("testpassword");
$login->set_user_type("user");

$login->store();

$dbh->commit();

send_login_form($mech);
#logged in as user, the server side script should still not allow storing 

$mech->get( $url );
$mech->get_ok( $url );

$mech->content_like( qr/You don't have the right privileges/i, "User has no privileges. Server side script does not attempt to  store the organism! ");


#logout before changing user type 
$mech->get( "$server/solpeople/login.pl?logout=yes" );
#user is a submitter

$login->set_user_type("submitter");

$login->store();
$dbh->commit();

send_login_form($mech);

$mech->get( $url );

$mech->content_like( qr/The organism does not exist/i, "Did not find the organism! Server side script returned a 'no organism' fail flag");


$mech->get($url . "?species=$species&prop_name=$prop_name&prop_value=$prop_value");

$mech->content_like( qr/Success, the object was added to the table/i, "Found organism $species. Loading new organismprop!");

#now delete the row 
print STDOUT "Deleting organismprop $prop_name (value = $prop_value) for species $species...\n";
my $c = SGN::Context->instance;  
my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
my $type_id = $schema->resultset("Cv::Cv")->find(
    { name => 'organism_property' })->find_related('cvterms', {
	name=> $prop_name })->cvterm_id();

$schema->resultset("Organism::Organism")->find(
    { species => $species } )->find_related('organismprops', { 
	value => $prop_value,
	type_id => $type_id  }
    )->delete();

print STDOUT "Gone!\n";

#######
sub send_login_form {
    my $mech = shift;
    
    $mech->get_ok("$server/solpeople/top-level.pl");
    $mech->content_contains("Login");
    
    my %form = (
	form_name => 'login',
	fields    => {
	    username => 'testusername',
	    pd       => 'testpassword',
	},
	);
    
    $mech->submit_form_ok( \%form, "Login form submission test" );
    
}
