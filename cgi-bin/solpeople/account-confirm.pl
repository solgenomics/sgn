#!/usr/bin/perl -w
use strict;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::People;
use CXGN::People::Login;

my $page = CXGN::Page->new( "solpeople User Confirmation","Koni");
my $dbh = CXGN::DB::Connection->new();

my ($username, $confirm_code) = $page->get_arguments("username","confirm");
warn "given '" . $confirm_code . "'";
my $sp = CXGN::People::Login->get_login($dbh, $username);

if (! $sp) { 
    confirm_failure("Username \"$username\" was not found."); 
}

warn "confc: '" . $sp->get_confirm_code() . "'";
if ($sp -> get_confirm_code() ne $confirm_code) { 
    confirm_failure("Confirmation code is not valid!\n");
}
if (! $sp->get_confirm_code()) { 
    confirm_failure("No confirmation is required for user <b>$username</b>");
}

$sp -> set_disabled(undef);
$sp -> set_confirm_code(undef);
$sp -> set_private_email($sp->get_pending_email());

$sp -> store();

$page->header();

print <<EOF;

<p>Confirmation successful for username <b>$username</b>.</p>

<p><a href=login.pl>[Login Page]</a></p>
<br />

EOF


$page->footer();

sub confirm_failure {
  my ($reason) = @_;

  $page->header();

print <<EOF;

  <p>Sorry, we are unable to process this confirmation request. Please check that your complete confirmation URL has been pasted correctly into your browser.</p>

  <p><b>Reason:</b> $reason</p>

  <br />

EOF

  $page->footer();

  exit 0;
}
