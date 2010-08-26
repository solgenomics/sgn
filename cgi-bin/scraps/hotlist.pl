use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::UserList::Hotlist;
use CXGN::Login;
use Carp;

my $page = CXGN::Scrap::AjaxPage->new();
my $dbh = CXGN::DB::Connection->new("sgn_people");

my %args = $page->get_all_encoded_arguments();

$page->send_http_header;
print $page->header();

print "<caller>Hotlist</caller>\n";

#   Test high-latency conditions for AJAX:
# 	system("sleep 3");

my $action = $args{action} or $page->throw("Action must be specified");
my $content_list = $args{content} or $page->throw("Content must be sent");
my $button_id = $args{button_id};

print "<content>$content_list</content>\n";
print "<buttonId>$button_id</buttonId>\n";


# if($id_check != $session_id) { die "Session ID is not valid" }

my $loginh = CXGN::Login->new($dbh, {NO_REDIRECT=>1});
my $owner = $loginh->has_session();

$page->throw("No session") unless ($owner);


my @content_list = split /::/, $content_list;		


my $hotlist = CXGN::UserList::Hotlist->new($dbh, $owner);

my $old_hotlist_size = $hotlist->get_list_size();
print "<oldsize>$old_hotlist_size</oldsize>\n";	

if($action eq "add"){
	print "<action>add</action>\n";
	$hotlist->add_items(@content_list);
}
elsif($action eq "remove"){
	print "<action>remove</action>\n";
	$hotlist->remove_items(@content_list);
}
else {
	$page->throw("Invalid action sent");
}
	
my $new_hotlist_size = $hotlist->get_list_size();

print "<newsize>$new_hotlist_size</newsize>\n";

print $page->footer();

