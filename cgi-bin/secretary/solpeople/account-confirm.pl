#!/usr/bin/perl -w
use strict;
use CXGN::Scrap;
use CXGN::People;

our $page = CXGN::Scrap->new( "Solpeople User Confirmation","Chris");

my ($username, $confirm_code) = $page->get_arguments("username","confirm");

my $sp = CXGN::People::Login -> get_login($username);

#print STDERR "DATA: ".$sp->get_username, $sp->get_password(), $sp->get_confirm_code()."\n";

if (! $sp) { 
    confirm_failure("Username \"$username\" was not found."); 
}

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


print <<EOF;

<center>
<p>Confirmation successful for username <b>$username</b>.</p>

<p><a href=../index.pl>[Secretary Home Page]</a></p>
<br />
</center>
EOF


sub confirm_failure {
  my ($reason) = @_;


print <<EOF;

<center>
  <p>Sorry, we are unable to process this confirmation request. Please check that your complete confirmation URL has been pasted correctly into your browser.</p>

  <p><b>Reason:</b> $reason</p>

  <br />
</center>
EOF


  exit 0;
}
