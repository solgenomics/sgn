
use strict;
use warnings;

use Test::More tests => 15;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;
use SGN::Test;
use SGN::Context;

use CXGN::People::Person;

my $mech = SGN::Test::WWW::Mechanize->new();

$mech->with_test_level( local => sub { 
    my $new_account_page = "/solpeople/new-account.pl";

    $mech->get_ok($new_account_page);
    
# generate an account as a first test.
    
    my %form = (
	form_name => "submit_userdata",
	fields => {
	    first_name => "Test",
	    last_name  => "Testman",
	    username   => "testtesttest",
	    password   => "test-pass",
	    organization => "test-organization",
	    confirm_password => "test-pass",
	    email_address => "lam87\@cornell.edu",
	},
	);
    
    ok($mech->submit_form(%form), "submit form test");
    
    $mech->content_contains("created", "Account creation test");
    #print STDERR $mech->content();
    
# generate the same account again to test if it detects duplicated usernames
    
    $mech->get_ok($new_account_page);
    ok($mech->submit_form(%form), "submit duplicate username test");
    
    #print "CONTENTS: ". $mech->content();
    $mech->content_contains("already in use", "Duplicate username test");
    
# remove the user just created
    
    SGN::Context->new->dbc->txn( ping => sub {
	my $dbh = shift;
	my $p_id = CXGN::People::Person->get_person_by_username($dbh, "testtesttest");
	my $p = CXGN::People::Person->new($dbh, $p_id);
	$p->hard_delete();
				 });

# generate an account with a password that is too short
    
    $form{fields}->{password}="xyz";
    $form{fields}->{confirm_password}="xyz";
    $mech->get_ok($new_account_page);
    ok($mech->submit_form(%form), "password too short form submit");
    $mech->content_contains("Password is too short", "password too short message test");
    
# generate an account with an identical username/password
    
    $mech->get_ok($new_account_page);
    $form{fields}->{username}="testtesttest";
    $form{fields}->{password}="testtesttest";
    $form{fields}->{confirm_password}="testtesttest";
    ok($mech->submit_form(%form), "password and username identical form submit");
    $mech->content_contains("Password must not be the same as your username.");
    
# attempt to generate an account with mismatching password/confirm_password
    
    $mech->get_ok($new_account_page);
    $form{fields}->{password}="asecretword";
    $form{fields}->{confirm_password}="anothersecretword";
    ok($mech->submit_form(%form), "password mismatch form submit");
    $mech->content_contains("Password and confirm password do not match.");
    
		       
			});

