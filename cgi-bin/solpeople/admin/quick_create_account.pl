#!/usr/bin/perl -w
use strict;
use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use HTML::Entities;

my $page=CXGN::Page->new("Create Account","john");
my $dbh = CXGN::DB::Connection->new();

my $logged_in_person_id=CXGN::Login->new($dbh)->verify_session();
my $logged_in_user=CXGN::People::Person->new($dbh, $logged_in_person_id);
my $logged_in_person_id=$logged_in_user->get_sp_person_id();
my $logged_in_username=$logged_in_user->get_first_name()." ".$logged_in_user->get_last_name();
my $logged_in_user_type=$logged_in_user->get_user_type();
if($logged_in_user_type eq 'curator') {
    my($username,$password,$confirm_password,$email_address,$new_user_type,$first_name,$last_name)=$page->get_arguments(qw(username password confirm_password email_address user_type first_name last_name));
    my $new_user_login=CXGN::People::Login->new($dbh);
    if($username) {
        my @fail=();
        if(length($username)<7){push @fail,"Username is too short. Username must be 7 or more characters";} 
        my $existing_login=CXGN::People::Login->get_login($dbh, $username);
        if($existing_login->get_username()){push @fail,"Username \"$username\" is already in use. Please pick a different username.";}
        if(length($password)<7){push @fail,"Password is too short. Password must be 7 or more characters";}
        if("$password" ne "$confirm_password"){push @fail,"Password and confirm password do not match.";}
        if($password eq $username){push @fail,"Password must not be the same as your username.";}
        if($new_user_type ne 'user' and $new_user_type ne 'sequencer' and $new_user_type ne 'submitter'){push @fail,"Sorry, but you cannot create user of type \"$new_user_type\" with web interface.";}
        if(@fail)
        {
            my $fail_str="";
            foreach(@fail)
            {
                $fail_str .= "<li>$_</li>\n"
            }
            $page->header();
print <<END_HTML;
            
            <table width=80% align=center>
            <tr><td>
            <p>Your account could not be created for the following reasons</p>
            <ul>
            $fail_str
            </ul>
            <p>Please use your browser\'s back button to try again.</p>
            </td></tr>
            <tr><td><br /></td></tr>
            </table>
END_HTML
            $page->footer();
        }
        else {
            $new_user_login->set_username(encode_entities($username));
            $new_user_login->set_password($password);
            $new_user_login->set_private_email(encode_entities($email_address));
            $new_user_login->set_user_type(encode_entities($new_user_type));
            $new_user_login->store();
            my $new_user_person_id=$new_user_login->get_sp_person_id();
            my $new_user_person=CXGN::People::Person->new($dbh, $new_user_person_id);
            $new_user_person->set_first_name(encode_entities($first_name));
            $new_user_person->set_last_name(encode_entities($last_name));
            ##removed. This was causing problems with creating new accounts for people,
            ##and then not finding it in the people search.
            #$new_user_person->set_censor(1);#censor by default, since we are creating this account, not the person whose info might be displayed, and they might not want it to be displayed
            $new_user_person->store();
            $page->header();
 print <<END_HTML;

            <table width=80% align=center>
            <tr><td><p>Account was created with username "$username".</p></td></tr>
            <tr><td><br /></td></tr>
            </table>

END_HTML
            $page->footer();
        }
    } 
    else 
    {
        $page->header();
print <<END_HTML;

        <form method="post" action="quick_create_account.pl">
        <table cellpadding="2" cellspacing="2" width="100%" align="center">
        <tr><td colspan="2"><b>Curators may use this form to create accounts for new users.<br />&nbsp;</b></td></tr>
        <tr><td>First Name</td><td><input type="text" name="first_name" size="20" value=""></td></tr>
        <tr><td>Last Name</td><td><input type="text" name="last_name" size="20" value=""></td></tr>
        <tr><td>Username (at least 7 characters)</td><td><input type="text" name="username" size="12" value=""></td></tr>
        <tr><td>Password (at least 7 characters)</td><td><input type="password" name="password" size="12" value=""></td></tr>
        <tr><td>Confirm Password</td><td><input type="password" name="confirm_password" size="12" value=""></td></tr>
        <tr><td>Private Email Address</td><td><input type="text" name="confirm_email" size="40" value=""></td></tr>
        <tr><td>User Type</td><td><input type="text" name="user_type" size="10" value=""></td></tr>
        <tr><td>&nbsp;</td></tr>
        <tr><td colspan="2" align="center"><input type="submit" name="create_account" value="Create Account"></td></tr>
        </table>
        <br />

END_HTML
    }
    $page->footer();

}
else
{
    $page->client_redirect('/user/login');
}
