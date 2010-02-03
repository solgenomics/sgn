#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Cookie;
# The purpose of this script is an intermediate between our final order page
# and the supplier's page. This is necessary so that if the user clicks send 
# order on clone-order.pl, we can delete the items from the cookie before we
# send over to receiving site. 
#
# Because we need to use POST, we can't accomplish this transparently with an
# HTML REDIRECT in the <HEAD> section. 
#
# Instead we use javascript to automatically click the submit button and 
# POST to the receiving site. Users without javascript enabled will see the
# intermediate page and have to click the submit button manually.
our ($dbh, $check_q);
our $page = CXGN::Page->new("Clone Shopping Cart","Koni");#cleaned up by john 23Dec2005
$dbh = CXGN::DB::Connection->new();
$check_q = $dbh->prepare("SELECT order_routing_id from clone LEFT JOIN library USING (library_id) where clone_name=?");
my $cart_contents = CXGN::Cookie::get_cookie("CloneCart");
if (!$cart_contents) 
{
    $page->error_page('Cannot route order because shopping cart is empty.');
    #$cart_contents = "";
}
my %cookie_clones;
foreach ( split /,/,$cart_contents ) 
{
    $cookie_clones{$_} = 1;
}
# Since we can, we always check to make sure we are doing what we are supposed
# to be doing. The script which POSTs to this page should specify what we are
# ordering, and where to route it to, so we verify that what is being ordered
# is supposed to be routed the given way. We don't care whether or not they
# are in the cookie. If they are in the cookie, they will be removed.
my %order_clones;
my ($posted_clones, $routing_id, $action) = $page->get_arguments("order_clones","route_to","route_order");
foreach ( split /,/,$posted_clones ) 
{
    $check_q->execute($_);
    my ($clone_routing_id) = $check_q->fetchrow_array();
    if ($clone_routing_id == $routing_id) 
    {
        $order_clones{$_} = 1;
    }
}
# Later, we will reset the cookie to the list formed from the cookie_clones
# hash keys.
foreach ( keys %order_clones ) 
{
    if ($cookie_clones{$_}) 
    {
        delete $cookie_clones{$_};
    }
}
my $new_cookie = join(",",keys(%cookie_clones));
#i have no idea what a new cookie could be for if we are sending these cookies away to be processed,
#but i'm leaving this in since i don't understand it. i THINK what this MIGHT be doing is rescuing
#cookie clones that fail the above tests by reinserting them into the cookie. but why do we want to 
#rescue them if they are invalid? lukas says this is because in the future we may need to add code
#to order these other clones that failed the above tests. --john
if($new_cookie)
{
    CXGN::Cookie::set_cookie("CloneCart",$new_cookie);
}
else
{
    CXGN::Cookie::set_cookie("CloneCart","");
} 
if ($action eq "Delete Order")
{
    $page->header();
    print <<END_HTML;
Order deleted.
<script type="text/javascript">
<!--
window.opener.document.location.replace("/search/clone-order.pl");
window.close();
-->
</script>
END_HTML
    $page->footer();
}
else
{
    if ($routing_id == 1) 
    {
        my $order_clones = join(" ",keys(%order_clones));
        # Fei hates the "-" seperators in clone names that we use at SGN
        $order_clones =~ s/-//g;
        $page->header();
        print <<END_HTML;
<p />
<table summary="" cellpadding="2" cellspacing="2" align="center" width="80%" border="0">
<tr><td>This page should automatically route your order to the ordering facility. If you are seeing this page, your browser may not support the javascript commands which automate the order submission. Simply click the button below in that case.</td></tr>
<tr><td>
<form name="auto-routing-form" method="post" action="http://ted.bti.cornell.edu/cgi-bin/TFGD/order/order.cgi?order_clones=$order_clones&item=clone">
<input type="hidden" name="clone" value="$order_clones">
<input type="submit" value="Submit Order">
</td></tr>
</table>
<script language="javascript" type="text/javascript">
<!--
// Its the second form because of the quick search form in the header
document.forms[1].submit();
window.opener.document.location.replace("/search/clone-order.pl");
-->
</script>
END_HTML
        $page->footer();
    }
    else 
    {
        $page->error_page("Clone order sent to unknown routing id \"$routing_id\" ($!)");
    }
}
