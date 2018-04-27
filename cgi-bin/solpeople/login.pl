use strict;
use warnings;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use SGN::Context;

my $page             = CXGN::Page->new( "Login", "john" );
my $dbh              = CXGN::DB::Connection->new();
my $context          = SGN::Context->new;
my $login_controller = CXGN::Login->new($dbh);

if ( $context->get_conf('is_mirror') ) {
    $page->message_page(
        "Sorry, but you cannot log in to this site.",
"This site is a mirror of <a href=\"/user/login\">sgn.cornell.edu</a>. To log in to SGN, go to <a href=\"/user/login\">SGN's login page</a>."
    );
}

if ( !$login_controller->login_allowed() ) {
    $page->message_page(
"Sorry, but logins are disabled while our server undergoes maintenance.",
"Logins should be available again within 24 hours. Should this condition persist, please contact <a href=\"mailto:sgn-feedback\@sgn.cornell.edu\">sgn-feedback\@sgn.cornell.edu</a>."
    );
}

my ( $username, $password, $goto_url, $logout ) =
  $page->get_arguments( "username", "pd", "goto_url", "logout" );

my $message = "Already have an account? Please log in using the form below.";

my $referer = $ENV{HTTP_REFERER} || '';
if ( $referer =~ m|http://[^/]+/index.pl| ) {

    # if they were on the front page, send them to homepage
    $goto_url ||= "/";
}
elsif ( $referer =~ m|account-confirm.pl| ) {

    # if they just confirmed their account, send them to homepage
    $goto_url = "/";
}
else {

    # if they were anywhere else, send them to the referring page
    $goto_url ||= $referer;
}


if ( $logout && $logout eq "yes" )              #if we are in the process of logging out
{
    $login_controller->logout_user();

}


if ( $username && $password )    #else if we are in the process of logging in
{
    my $login_info = $login_controller->login_user( $username, $password );

    #print STDERR "loggin in: $username\n";
    my $person_id = $login_info->{person_id};

    #print STDERR "sp_person_id: $person_id\n";
    my $account_disabled   = $login_info->{account_disabled};
    my $logins_disabled    = $login_info->{logins_disabled};
    my $incorrect_password = $login_info->{incorrect_password};
    my $duplicate_cookie   = $login_info->{duplicate_cookie_string};
    if ($logins_disabled)    #if the whole system is disabled, print a message
    {
        $page->message_page("Sorry, but this login system is disabled.");
    }
    elsif ($account_disabled)    #if their account is disabled, print a message
    {
        $page->message_page(
"Account for user $username is disabled for reason '$account_disabled'.",
"If your account has not been confirmed, check your email for a confirmation from SGN."
        );
    }
    elsif ($incorrect_password)    #if their password is wrong, print a message
    {
        $page->message_page( "Incorrect username or password.",
            "<a href=\"send-password.pl\">[Lost password]</a>" );
    }
    elsif ($duplicate_cookie)    #if we couldn't generate a unique cookie string
    {
        $page->error_page(
            "Sorry but the login system failed.",
            "Please try again.",
            "failed to generate new cookie string",
            "Our random login cookie generator generated a duplicate value!"
        );
    }
    elsif ($person_id)           #if their username and password matched
    {
        if ($goto_url
          )    #if they came from trying to work somewhere else, send them back
        {

            #if we logged in from having just logged out,
            #make sure we don't get sent back to the logout page:
            if ( $goto_url =~ /login\.pl/ ) {
                $goto_url = "/solpeople/profile/$person_id";
            }

            $page->client_redirect($goto_url);
        }
        else  #else they are just getting started, so send them to the menu page
        {
            $page->client_redirect("/solpeople/profile/$person_id");
        }
    }
}
else          #else we not trying to log in yet
{
    if ( $login_controller->has_session()
      ) #if there's no good reason for them to be here, send them to the homepage
    {
        $page->client_redirect("/");
    }
}


$page->header( 'Sol Genomics Network', 'Login' );
print <<END_HTML;
<div align="center">$message</div>
<div align="center">Your browser must accept cookies for this interface to work correctly.</div><br/>

<div class="container-fluid">
  <div class="row">
    <div class="col-sm-2 col-md-3 col-lg-3">
    </div>
    <div class="col-sm-8 col-md-6 col-lg-6" align="center">
<form class="form-horizontal" role="form" name="login" method="post" action="/user/login">
  <div class="form-group">
    <label class="col-sm-3 control-label">Username: </label>
    <div class="col-sm-9">
      <input class="form-control" id="unamefield" type="text" name="username" value="" />
    </div>
  </div>
  <div class="form-group">
    <label class="col-sm-3 control-label">Password: </label>
    <div class="col-sm-9">
      <input class="form-control" type="password" name="pd" value="" /><input type="hidden" name="goto_url" value="$goto_url" />
    </div>
  </div>
  <button class="btn btn-primary" type="submit" name="login" value="Login" >Login</button>
</form>    
    </div>
    <div class="col-sm-2 col-md-3 col-lg-3">
    </div>
  </div>
</div>
<br/>

<!--
<form name="login" method="post" action="/user/login">
  <table style="padding: 2em" summary="" cellpadding="2" cellspacing="0" border="0" align="center">
  <tr><td>Username</td><td><input class="form-control" id="unamefield" type="text" name="username" size="30" value="" /></td></tr>
  <tr><td colspan="2"></td></tr>
  <tr><td>Password</td><td><input class="form-control" type="password" name="pd" size="30" value="" /></td></tr>
  <tr><td colspan="2" align="center"><br /><button class="btn btn-primary" type="submit" name="login" value="Login" >Login</button></td></tr>
  </table>
<input type="hidden" name="goto_url" value="$goto_url" />
</form>
-->

<div align="center">New user? <a href="/solpeople/new-account.pl">Sign up for an account</a>.<br />
Forgot your password? <a href="/solpeople/send-password.pl">Get it here</a>.</div>
<script language="JavaScript" type="text/javascript">
<!--
document.getElementById("unamefield").focus(1);
-->
</script> 
END_HTML
$page->footer();
