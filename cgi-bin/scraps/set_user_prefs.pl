#!/usr/bin/perl
use strict;

use CXGN::DB::Connection;
use CXGN::Scrap::AjaxPage;
use CXGN::UserPrefs;
use CXGN::Login;

my $page = CXGN::Scrap::AjaxPage->new();
my $dbh = CXGN::DB::Connection->new();

my %args = $page->get_all_encoded_arguments();
$page->caller("UserPrefs");
$page->send_http_header();
print $page->header();

my $updated = 0;
my $errmsg = "";
my $fatalmsg = "";

eval {

my $user_prefs = $args{user_prefs};
my $sgn_session_id = $args{sgn_session_id};

my $sp_person_id = undef;
if($sgn_session_id){
	$sp_person_id = CXGN::Login->new($dbh)->query_from_cookie($sgn_session_id);
}
else {
	$sp_person_id = CXGN::Login->new($dbh)->has_session();
}


if($sp_person_id && $user_prefs){
	my $up = CXGN::UserPrefs->new($dbh,$sp_person_id);
	$up->set_user_pref_string($user_prefs);
	$up->store();
	$updated = 1;
}
else {
	if(!$sp_person_id){
		$errmsg .= "sp_person_id could not be resolved\n";
	}
	if(!$user_prefs){
		$errmsg .= "user_prefs was found in arguments list\n";
	}
}

};
if($@){
	$fatalmsg = $@;
}

print "<updated>$updated</updated>\n";
if($errmsg){
	print "<errmsg>$errmsg</errmsg>\n";
}
if($fatalmsg) {
	print "<fatalmsg>$fatalmsg</fatalmsg>\n";
}

print $page->footer();
