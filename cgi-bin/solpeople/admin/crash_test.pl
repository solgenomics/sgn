#!/usr/bin/perl -w

use strict;
use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People;
use CXGN::VHost;

my $page = CXGN::Page->new("crash_test.pl","john binns");
my $dbh = CXGN::DB::Connection->new();

# We are NOT using get_encoded_arguments here because we want to
# simulate scripts that have neglected this.
my($test,$message) = $page->get_arguments('test','message');
$message ||= 'crash_test';

my $vhost = CXGN::VHost->new;
my $is_production_server = $vhost->get_conf('production_server');
my $logged_in_person_id = CXGN::Login->new($dbh)->verify_session();
my $logged_in_user = CXGN::People::Person->new($dbh, $logged_in_person_id);
my $logged_in_username = $logged_in_user->get_first_name()." ".$logged_in_user->get_last_name();
my $logged_in_user_type=$logged_in_user->get_user_type();

if( !$is_production_server || $logged_in_user_type eq 'curator') {
  if ($test) {
    # Demonstrate the ugly double header problem, in case someone
    # tries to fix it sometime.
    $page->header('Crash tester');
    if ($test == 1) {
      $page->error_page($message,'message body','errorverbed','developer message');
    } elsif ($test == 2) {
      &rube_goldberg();	#unneccessary function to test stack backtrace
    } elsif ($test == 3) {
      eval {
	die("Well, don't REALLY die.");
      };
      if ($@) {
	print $@;
      } else {
	print"Code eval'd without errors.";
      }
    } elsif ($test == 4) {
      $page->message_page($message,'message body');
    } elsif ($test == 5) {
      $c->forward_to_mason_view('/test/error_test.mas');
    } elsif ($test == 6) {
      $c->render_mason('/test/error_test.mas');
    } else {
      $page->message_page('Deeerrrrrrrr....');
    }
    $page->footer();
  } else { #no arguments
    &plain_page($page, $message);
  }
}
else {
   $page->message_page('Sorry, but you are not authorized to run crash tests.');
}

sub rube_goldberg {
    die 'big ugly terrible death';
}

sub plain_page {
    my $page = shift;
    my $message = shift;
    $page->header();
    print <<EOF;
<a href="?test=1&amp;message=$message">Test anticipated error</a>
(Note: the notion of &quot;anticipated&quot; error is deprecated.
Just call die().)
<br /><br />

<a href="?test=2">Test unanticipated error</a>
(Note: the notion of &quot;unanticipated&quot; error is deprecated.
Just call die().)
<br /><br />

<a href="?test=5">Test Mason-handled error 1</a>
<br /><br />
<a href="?test=6">Test Mason-handled error 2</a>
<br /><br />

<a href="page_that_doesnt_compile.pl">Test compile-time error</a>
(Actually, this page does compile, and the error has always been a
run-time error.)
<br /><br />

<a href="another_page_that_doesnt_compile.pl">
Test an actual compile-time error</a>
(Specifically, an execution error during compilation.)
<br /><br />

<a href="page_with_syntax_error.pl">Test a syntax error</a>
(Specifically a parse error, which Perl seems to handle differently
than execution errors during compilation)
<br /><br />

<a href="/page_that_doesnt_exist/">Test 404</a><br /><br />

<a href="image_404_test.pl">Test image 404 within a page</a><br /><br />

<a href="?test=4&amp;message=$message">Test message page</a><br /><br />

<a href="?test=3">Test eval (page should NOT generate error page, just a long message)</a><br /><br />
EOF

    $page->footer();
    exit(0);
}
