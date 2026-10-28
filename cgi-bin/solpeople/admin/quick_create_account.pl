#!/usr/bin/perl -w
use strict;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use HTML::Entities;

    my SGN::I18N $ui_people_i18n = SGN::I18N::translate($c);
    my %ui_people_text = (
        your_account_could_not_be_created_for_the_following_reasons => SGN::I18N::translate($ui_people_i18n, 'community.people.your_account_could_not_be_created_for_the_following_reasons', 'Your account could not be created for the following reasons', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        please_use_your_browser_s_back_button_to_try_again => SGN::I18N::translate($ui_people_i18n, 'community.people.please_use_your_browser_s_back_button_to_try_again', 'Please use your browser\'s back button to try again.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        curators_may_use_this_form_to_create_accounts_for_new_users => SGN::I18N::translate($ui_people_i18n, 'community.people.curators_may_use_this_form_to_create_accounts_for_new_users', 'Curators may use this form to create accounts for new users.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        first_name => SGN::I18N::translate($ui_people_i18n, 'community.people.first_name_capitalized', 'First Name', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        last_name => SGN::I18N::translate($ui_people_i18n, 'community.people.last_name_capitalized', 'Last Name', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        username_at_least_7_characters => SGN::I18N::translate($ui_people_i18n, 'community.people.username_at_least_7_characters', 'Username (at least 7 characters)', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        password_at_least_7_characters => SGN::I18N::translate($ui_people_i18n, 'community.people.password_at_least_7_characters', 'Password (at least 7 characters)', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        confirm_password => SGN::I18N::translate($ui_people_i18n, 'community.people.confirm_password', 'Confirm Password', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        private_email_address => SGN::I18N::translate($ui_people_i18n, 'community.people.private_email_address', 'Private Email Address', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        user_type => SGN::I18N::translate($ui_people_i18n, 'community.people.user_type', 'User Type', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        create_account => SGN::I18N::translate($ui_people_i18n, 'community.people.create_account', 'Create Account', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        account_was_created_with_username => SGN::I18N::translate($ui_people_i18n, 'community.people.account_was_created_with_username', 'Account was created with username ', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
    );

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
        if(length($username)<7){push @fail,SGN::I18N::translate($ui_people_i18n, 'community.people.username_is_too_short_username_must_be_7_or_more_characters', 'Username is too short. Username must be 7 or more characters', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 });}
        my $existing_login=CXGN::People::Login->get_login($dbh, $username);
        if($existing_login->get_username()){push @fail,SGN::I18N::translate($ui_people_i18n, 'community.people.username_in_use', 'Username "%{username}" is already in use. Please pick a different username.', { username => $username });}
        if(length($password)<7){push @fail,SGN::I18N::translate($ui_people_i18n, 'community.people.password_is_too_short_password_must_be_7_or_more_characters', 'Password is too short. Password must be 7 or more characters', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 });}
        if("$password" ne "$confirm_password"){push @fail,SGN::I18N::translate($ui_people_i18n, 'community.people.password_and_confirm_password_do_not_match', 'Password and confirm password do not match.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 });}
        if($password eq $username){push @fail,SGN::I18N::translate($ui_people_i18n, 'community.people.password_must_not_be_the_same_as_your_username', 'Password must not be the same as your username.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 });}
        if($new_user_type ne 'user' and $new_user_type ne 'sequencer' and $new_user_type ne 'submitter'){push @fail,SGN::I18N::translate($ui_people_i18n, 'community.people.cannot_create_user_type', 'Sorry, but you cannot create user of type "%{type}" with web interface.', { type => $new_user_type });}
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
            <p>$ui_people_text{your_account_could_not_be_created_for_the_following_reasons}</p>
            <ul>
            $fail_str
            </ul>
            <p>$ui_people_text{please_use_your_browser_s_back_button_to_try_again}</p>
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
            <tr><td><p>$ui_people_text{account_was_created_with_username}"$username".</p></td></tr>
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
        <tr><td colspan="2"><b>$ui_people_text{curators_may_use_this_form_to_create_accounts_for_new_users}<br />&nbsp;</b></td></tr>
        <tr><td>$ui_people_text{first_name}</td><td><input type="text" name="first_name" size="20" value=""></td></tr>
        <tr><td>$ui_people_text{last_name}</td><td><input type="text" name="last_name" size="20" value=""></td></tr>
        <tr><td>$ui_people_text{username_at_least_7_characters}</td><td><input type="text" name="username" size="12" value=""></td></tr>
        <tr><td>$ui_people_text{password_at_least_7_characters}</td><td><input type="password" name="password" size="12" value=""></td></tr>
        <tr><td>$ui_people_text{confirm_password}</td><td><input type="password" name="confirm_password" size="12" value=""></td></tr>
        <tr><td>$ui_people_text{private_email_address}</td><td><input type="text" name="confirm_email" size="40" value=""></td></tr>
        <tr><td>$ui_people_text{user_type}</td><td><input type="text" name="user_type" size="10" value=""></td></tr>
        <tr><td>&nbsp;</td></tr>
        <tr><td colspan="2" align="center"><input type="submit" name="create_account" value="$ui_people_text{create_account}"></td></tr>
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
