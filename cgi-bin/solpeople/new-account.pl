
use strict;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw | page_title_html |;
use CXGN::People::Login;
use CXGN::People::Person;
use CXGN::Contact;

use CatalystX::GlobalContext '$c';

my $page = CXGN::Page->new("solpeople create account", "Koni");
my $dbh = CXGN::DB::Connection->new();

my $conf = $c->config;

if ($conf->{is_mirror}) { 
    $page->message_page("This site is a mirror site and does not support adding users. Please go to the main site to create an account.");
}


my ($first_name, $last_name, $username, $password, $confirm_password, $email_address, $organization)
  = $page->get_arguments(qw(first_name last_name username password confirm_password email_address organization));

if ($username) {
  #
  # check password properties...
  #
  my @fail = ();
  if (length($username) < 7) {
    push @fail, "Username is too short. Username must be 7 or more characters";
  } else {
    # does user already exist?
    #
      my $existing_login = CXGN::People::Login -> get_login($dbh, $username); 
      
      if ($existing_login->get_username()) { 
	  push @fail, "Username \"$username\" is already in use. Please pick a different username.";
      }
      
  }
  if (length($password) < 7) {
    push @fail, "Password is too short. Password must be 7 or more characters";
  }
  if ("$password" ne "$confirm_password") {
    push @fail, "Password and confirm password do not match.";
  }

  if (!$organization) { 
      push @fail, "'Organization' is required.'";
  }

  if ($password eq $username) {
    push @fail, "Password must not be the same as your username.";
  }
  if ($email_address !~ m/[^\@]+\@[^\@]+/) {
    push @fail, "Email address is invalid.";
  }
  unless($first_name) {
      push @fail,"You must enter a first name or initial.";
  }
  unless($last_name) {
      push @fail,"You must enter a last name.";
  }  

  if (@fail) {

      #$page->message_page("Account could not be created ".(join "  ", @fail));

      &show_fail_reasons(\@fail, $page);
      exit();
      
  }


  my $confirm_code = $page->tempname();
  my $new_user = CXGN::People::Login->new($dbh);
  $new_user -> set_username($username);
  $new_user -> set_password($password);
  $new_user -> set_pending_email($email_address);
  $new_user -> set_confirm_code($confirm_code);
  $new_user -> set_disabled('unconfirmed account');
  $new_user -> set_organization($organization);
  $new_user -> store();

  #this is being added because the person object still uses two different objects, despite the fact that we've merged the tables
  my $person_id=$new_user->get_sp_person_id();
  my $new_person=CXGN::People::Person->new($dbh,$person_id);
  $new_person->set_first_name($first_name);
  $new_person->set_last_name($last_name);
  $new_person->store();
  
  my $host = CGI->new->server_name;
  my $subject="[SGN] Email Address Confirmation Request";
  my $body=<<END_HEREDOC;

Please do *NOT* reply to this message. The return address is not valid. 
Use sgn-feedback\@solgenomics.net instead.

This message is sent to confirm the email address for community user
\"$username\"

Please click (or cut and paste into your browser) the following link to
confirm your account and email address:

https://$host/solpeople/account-confirm.pl?username=$username&confirm=$confirm_code

Thank you,
Sol Genomics Network

END_HEREDOC

  CXGN::Contact::send_email($subject,$body,$email_address);



  $page->header();

  print page_title_html("Create New Account");

  print <<END_HEREDOC;

<table summary="" width="80%" align="center">
<tr><td><p>Account was created with username \"$username\". To continue, you must confirm that SGN staff can reach you via email address \"$email_address\". An email has been sent with a URL to confirm this address. Please check your email for this message and use the link to confirm your email address.</p></td></tr>
<tr><td><br /></td></tr>
</table>

END_HEREDOC

  $page->footer();

} else {

  $page->header();


  print page_title_html("Create New Account");

  print <<END_HEREDOC;


  <!--
  <div class='boxbgcolor5'><b>Please note:</b></a><br />


      <ul>

      <li><b>Before</b> creating a new account, please check if you <b>already have an account</b> using the <a href="/search/direct_search.pl?search=directory">directory search</a>. </li>
      <li>A link will be emailed to you. Please click on it to activate the account.</li>
      <li><b>All fields are required.</b></li>
      </div>
  -->
      
<div class="container-fluid">
  <div class="row">
    <div class="col-sm-2 col-md-2 col-lg-2">
    </div>
    <div class="col-sm-8 col-md-8 col-lg-8" >
      <div class="panel panel-danger">
        <div class="panel-heading">Notice</div>
	<div class="panel-body">
          <ul>
	    <li><b>Before</b> creating a new account, please check if you <b>already have an account</b> using the <a href="/search/direct_search.pl?search=directory">directory search</a>. </li>
	    <li>A link will be emailed to you. Please click on it to activate the account.</li>
	    <li><b>All fields are required.</b></li>
	  </ul>
	</div>
      </div>

<form class="form-horizontal" role="form" name="submit_userdata" method="post" action="new-account.pl">
  <div class="form-group">
    <label class="col-sm-3 control-label">First Name: </label>
    <div class="col-sm-9">
      <input class="form-control" type="text" name="first_name" value="" />
    </div>
  </div>
  <div class="form-group">
    <label class="col-sm-3 control-label">Last Name: </label>
    <div class="col-sm-9">
      <input class="form-control" type="text" name="last_name" value="" />
    </div>
  </div>
  <div class="form-group">
    <label class="col-sm-3 control-label">Organization: </label>
    <div class="col-sm-9">
      <input class="form-control" type="text" name="organization" value="" />
    </div>
  </div>
  <div class="form-group">
    <label class="col-sm-3 control-label">Username: </label>
    <div class="col-sm-9">
      <input class="form-control" type="text" name="username" value="" /><br/>Username must be at least 7 characters long.
    </div>
  </div>
  <div class="form-group">
    <label class="col-sm-3 control-label">Password: </label>
    <div class="col-sm-9">
      <input class="form-control" type="password" name="password" value="" /><br/>Password must be at least 7 characters long and different from your username.
    </div>
  </div>
  <div class="form-group">
    <label class="col-sm-3 control-label">Confirm Password: </label>
    <div class="col-sm-9">
      <input class="form-control" type="password" name="confirm_password" value="" />
    </div>
  </div>
  <div class="form-group">
    <label class="col-sm-3 control-label">Email Address: </label>
    <div class="col-sm-9">
      <input class="form-control" type="text" name="email_address" value="" /><br/>An email will be sent to this address requiring you to confirm its receipt to activate your account.<br/>
    </div>
  </div>
  <div align="right">
    <button class="btn btn-default" type="reset" >Reset</button>
    <button class="btn btn-primary" type="submit" name="create_account" value="Create Account" >Create Account</button>
  </div>
</form>    
    </div>
    <div class="col-sm-2 col-md-2 col-lg-2">
    </div>
  </div>
</div>
<br/>

<!--
  <form name="submit_userdata" method="post" action="new-account.pl">
  <table summary="" cellpadding="2" cellspacing="2" width="80%" align="center">

  <tr><td colspan="2"><br /></td></tr>
  <tr><td>First name</td><td><input type="text" name="first_name" size="40" value="" /></td></tr>
  <tr><td>Last name</td><td><input type="text" name="last_name" size="40" value="" /></td></tr>
  <tr><td>Organization</td><td><input type="text" name="organization" size="40" value="" /></td></tr>
  <tr><td>Username</td><td><input type="text" name="username" size="12" value="" /></td></tr>
  <tr><td colspan="2" style="font-size: 80%">Username must be at least 7 characters long.</td></tr>
  <tr><td>Password</td><td><input type="password" name="password" size="12" value="" /></td></tr>
  <tr><td colspan="2" style="font-size: 80%">Password must be at least 7 characters long and different from your username.</td></tr>
  <tr><td>Confirm Password</td><td><input type="password" name="confirm_password" size="12" value="" /></td></tr>
  <tr><td colspan="2"><br /></td></tr>
  <tr><td>Email Address</td><td><input type="text" name="email_address" size="40" value="" /></td></tr>
  <tr><td colspan="2" style="font-size: 80%">An email will be sent to this address requiring you to confirm its receipt to activate your account.<br /><br /><br /></td></tr>

  <tr><td><input type="reset" /></td><td align="right"><input type="submit" name="create_account" value="Create Account" /></td></tr>
  </table>
  </form>
-->

END_HEREDOC

  $page->footer();

}

sub show_fail_reasons {
    my $fail_ref = shift;
    my $p = shift;

    my $fail_str = "";
    foreach my $s (@$fail_ref) {
	$fail_str .= "<li>$s</li>\n"
    }
    

    $p->header();
    
    
    print <<END_HEREDOC;

 <table summary="" width="80%" align="center">
 <tr><td>
 <p>Your account could not be created for the following reasons</p>

 <ul>
 $fail_str
 </ul>

 <p>Please use your browser\'s back button to try again.</p>
 </td></tr>
  <tr><td><br /></td></tr>
 </table>

END_HEREDOC

  $p->footer();


}
