#!/usr/bin/perl -w
use strict;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';

use warnings;

use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::DB::Connection;
use HTML::Entities;

    my SGN::I18N $ui_people_i18n = SGN::I18N::translate($c);
    my %ui_people_text = (
        curators_may_use_this_form_to_create_organizations => SGN::I18N::translate($ui_people_i18n, 'community.people.curators_may_use_this_form_to_create_organizations', 'Curators may use this form to create organizations.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        organization_name => SGN::I18N::translate($ui_people_i18n, 'community.people.organization_name', 'Organization name', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        short_name => SGN::I18N::translate($ui_people_i18n, 'community.people.short_name', 'Short name', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        clear_form => SGN::I18N::translate($ui_people_i18n, 'community.people.clear_form', 'Clear form', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        create_organization => SGN::I18N::translate($ui_people_i18n, 'community.people.create_organization', 'Create organization', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        organization_created => SGN::I18N::translate($ui_people_i18n, 'community.people.organization_created', 'Organization created: ', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
    );

my $page=CXGN::Page->new(SGN::I18N::translate($ui_people_i18n, 'community.people.create_organization', 'Create organization', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),"john");
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
        if($existing_org_id){$page->message_page(SGN::I18N::translate($ui_people_i18n, 'community.people.organization_exists', 'Organization "%{name}" exists, id %{id}.', { name => $name, id => $existing_org_id }));}
        else
        { 
            my $org_insert=$dbh->prepare("insert into sgn_people.sp_organization (name, shortname) values (?,?)");
            $org_insert->execute($name, $short_name);
            $page->header(SGN::I18N::translate($ui_people_i18n, 'community.people.create_organization', 'Create organization', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),"$ui_people_text{organization_created}$name");
            $page->footer();
        }
    } 
    else 
    {
        $page->header(SGN::I18N::translate($ui_people_i18n, 'community.people.create_organization', 'Create organization', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
        print <<END_HTML;
        <form method="post" action="">
        <table cellpadding="2" cellspacing="2" width="100%" align="center">
        <tr><td colspan="2"><b>$ui_people_text{curators_may_use_this_form_to_create_organizations}<br />&nbsp;</b></td></tr>
        <tr><td>$ui_people_text{organization_name}</td><td><input type="text" name="organization_name" size="30" value=""></td></tr>
        <tr><td>$ui_people_text{short_name}</td><td><input type="text" name="short_name" size="30" value=""></td></tr>
        <tr><td>&nbsp;</td></tr>
        <tr><td colspan="2" align="center"><input type="submit" name="create_organization" value="$ui_people_text{create_organization}"></td></tr>
        <tr><td colspan="2" align="center"><input type="reset" name="Clear" value="$ui_people_text{clear_form}"></td></tr>
        </table>
        <br />
END_HTML
    }
}
else
{
    $page->client_redirect('/solpeople/login.pl');
}
