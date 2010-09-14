#!/usr/bin/perl -w
use strict;
use warnings;

use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::DB::Connection;
use HTML::Entities;

my $page=CXGN::Page->new("Create organization","john");
my $dbh=CXGN::DB::Connection->new("sgn_people");

my $logged_in_person_id=CXGN::Login->new($dbh)->verify_session();
my $logged_in_user=CXGN::People::Person->new($dbh, $logged_in_person_id);
my $logged_in_username=$logged_in_user->get_first_name()." ".$logged_in_user->get_last_name();
my $logged_in_user_type=$logged_in_user->get_user_type();
if($logged_in_user_type eq 'curator')
{
    my($name,$short_name)=$page->get_encoded_arguments("organization_name", "short_name");
    if($name)
    {
        $short_name ||= $name;
        my $org_query=$dbh->prepare("select sp_organization_id from sgn_people.sp_organization where name=?");
        $org_query->execute($name);
        my($existing_org_id)=$org_query->fetchrow_array();
        if($existing_org_id){$page->message_page("Organization \"$name\" exists, id $existing_org_id.");}
        else
        { 
            my $org_insert=$dbh->prepare("insert into sgn_people.sp_organization (name, shortname) values (?,?)");
            $org_insert->execute($name, $short_name);
            $page->header("Create organization","Organization created: $name");
            $page->footer();
        }
    } 
    else 
    {
        $page->header("Create organization");
        print <<END_HTML;
        <form method="post" action="">
        <table cellpadding="2" cellspacing="2" width="100%" align="center">
        <tr><td colspan="2"><b>Curators may use this form to create organizations.<br />&nbsp;</b></td></tr>
        <tr><td>Organization name</td><td><input type="text" name="organization_name" size="30" value=""></td></tr>
        <tr><td>Short name</td><td><input type="text" name="short_name" size="30" value=""></td></tr>
        <tr><td>&nbsp;</td></tr>
        <tr><td colspan="2" align="center"><input type="submit" name="create_organization" value="Create organization"></td></tr>
        <tr><td colspan="2" align="center"><input type="reset" name="Clear" value="Clear form"></td></tr>
        </table>
        <br />
END_HTML
    }
}
else
{
    $page->client_redirect('/solpeople/login.pl');
}
