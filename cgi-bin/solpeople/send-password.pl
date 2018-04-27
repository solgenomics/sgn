#!/usr/bin/perl -w
use strict;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::People;
use CXGN::People::Login;
use CXGN::Contact;

my $page = CXGN::Page->new( "Solpeople User Login", "Koni");
my $dbh = CXGN::DB::Connection->new();

my ($username) = $page->get_arguments("username");

my $sp = CXGN::People::Login -> get_login($dbh, $username);
my $email_address = $sp -> get_private_email();
my $password = $sp -> get_password();

if ($username) {
    if ($email_address) 
    {

        my $subject="[SGN] Account password";
	my $body=<<END_HEREDOC;
	
Please do *NOT* reply to this message. The return address is not valid. Use sgn-feedback\@sgn.cornell.edu to reach the SGN staff if you have problems.
	    
Your password was requested from the SGN website. Here it is: \"$password\"
	    
If you did not request your password, it is possible another user mistyped their username. This email was sent only to $email_address. Please contact SGN at sgn-feedback\@sgn.cornell.edu if there are further problems.

Thanks,
Sol Genomics Network

END_HEREDOC

        CXGN::Contact::send_email($subject,$body,$email_address);
     
        $page->header('Sol Genomics Network', 'Forgot Password');
    
        print <<END_HEREDOC;

	<div align="center">
    
        <p>Password mailed to $email_address.</p>
    
        <p>[<a href="/user/login">Login Page</a>]</p>
        <br />

	</div>
END_HEREDOC

         $page->footer();

    } 
    else 
    {
    
        $page->header('Sol Genomics Network', 'Forgot Password');
    
        print <<END_HEREDOC;

	<div align="center">
    
        <p>Email address for username \"$username\" was not found. Please check the username and try again, or contact SGN at sgn-feedback\@sgn.cornell.edu for assistance.</p>
    
        <p>[<a href="/user/login">Login Page</a>]

	</div>
    
END_HEREDOC

        $page->footer();
    }
}    
else 
{

    $page->header('Sol Genomics Network', 'Forgot Password');

    print <<END_HEREDOC;

<div align="center">Your password will be emailed to the email address you used to register your account. <br/>Please type your username below.</div><br/>

<div class="container-fluid">
  <div class="row">
    <div class="col-sm-2 col-md-3 col-lg-4">
    </div>
    <div class="col-sm-8 col-md-6 col-lg-4" align="center">
<form class="form-horizontal" role="form" method="post" action="/solpeople/send-password.pl">
  <div class="form-group">
    <label class="col-sm-3 control-label">Username: </label>
    <div class="col-sm-9">
      <input class="form-control" type="text" name="username" value="" />
    </div>
  </div>
  <button class="btn btn-primary" type="submit" name="send" value="Send password" >Send Password</button>
</form>    
    </div>
    <div class="col-sm-2 col-md-3 col-lg-4">
    </div>
  </div>
</div>

<!--
    <form method="post" action="/solpeople/send-password.pl">
    <table summary="" width="70%" align="center" cellspacing="2" cellpadding="2">
    <tr><td align="center">Your password will be emailed to the email address you used to register your account. Please type your username below.</td></tr>
    <tr><td>
    <table class="table" summary="" align="center" cellspacing="2" cellpadding="2">
    <tr><td>Username</td><td><input class="form-control" type="text" name="username" value="" /></td></tr>
    <tr><td colspan="2" align="center"><input class="btn btn-primary" type="submit" name="send" value="Send password" /></td></tr>
    </table></td></tr>
    </table>
    </form>
-->

END_HEREDOC

    $page->footer();

}
