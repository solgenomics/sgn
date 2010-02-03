#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Cookie;
my $dbh = CXGN::DB::Connection->new();
my $check_q = $dbh->prepare("SELECT order_routing_id from clone LEFT JOIN library USING (library_id) where clone_name=?");

our $page = CXGN::Page->new("Clone Shopping Cart", "Koni");

my ($clone_add) = $page->get_arguments("add_clone");

my $cart_contents = CXGN::Cookie::get_cookie("CloneCart");

if (!$cart_contents) {
  $cart_contents = "";
}

my @clones = split /,/,$cart_contents;
if ($clone_add) {
  push @clones, $clone_add;
}

# Note: An advantage of server-side statefulness here is not repeating this
#       everytime. This is typical of stateful/stateless tradeoff -- storing
#       state provides performance gains but at the expense of correctness and
#       increased complexity.
#
#       Future versions of this ordering thing may require server side state
#       due to the limitations of cookie size at the client.
my %ok_clones = ();
my %orders = ();
foreach my $clone_id ( @clones ) 
{
  $check_q->execute($clone_id);
  if ($check_q->rows()>0) {
    my ($order_routing_id) = $check_q->fetchrow_array();
    if (!$ok_clones{$clone_id}) {
      push @{$orders{$order_routing_id}}, $clone_id;
      $ok_clones{$clone_id} = 1;
    }
  }
}

# If we have valid clones, set the cookie.
if (keys(%ok_clones) > 0) {
  CXGN::Cookie::set_cookie("CloneCart",join(",",keys(%ok_clones)));
} else {
  CXGN::Cookie::set_cookie("CloneCart","");
  empty_cart();
}

if ($clone_add) {
  $page->client_redirect("/search/clone-order.pl");
  exit(0);
}

my @order_text = ();
foreach my $routing_id ( keys %orders ) {
  if ($routing_id == 1) { # TED
      push @order_text, ted_order_routing($orders{$routing_id});
  }
  elsif ($routing_id == 2) { # Kazusa
      push @order_text, kazusa_order_routing($orders{$routing_id});
  } else {
    $page->error_page("Clone ordered but order routing function for \"$routing_id\" is not available");
  }

}

sub ted_order_routing {
  my ($clone_listref) = @_;
  my $clone_order = join(",",@{$clone_listref});
  my $text = <<EOF;
  <form method="post" action="/search/route-order.pl" target="_BLANK">
<input type="hidden" name="route_to" value="1" />
<input type="hidden" name="order_clones" value="$clone_order" />
<table summary="" cellpadding="2" cellspacing="2" border="0" align="center" width="100%">
<tr><td style="background-color: CCCCFF;" align="center">The following selected clones are available through <b>TED</b></td></tr>
EOF
  foreach (@{$clone_listref}) {
    $text .= "<tr><td>$_</td></tr>";
  }

  $text .= <<EOF;
<tr><td style="background-color: CCCCFF;" align="center">
<input type="submit" name="route_order" value="Route Order" />&nbsp;&nbsp;<input type="submit" name="route_order" value="Delete Order" />
</td></tr></table></form>
EOF

  return $text;
}

sub kazusa_order_routing { 
    my ($clone_listref) = @_;
    my $clone_order = join(",", @{$clone_listref});
    my $clone_order_text = "Dear Kazusa, %0AI would like to order the following clones:%0A$clone_order%0A";
    my $text = <<EOF;
<form method="post" action="/search/route-order.pl" target="_BLANK">
<input type="hidden" name="route_to" value="1" />
<input type="hidden" name="order_clones" value="$clone_order" />
<table summary="" cellpadding="2" cellspacing="2" border="0" align="center" width="100%">
<tr><td style="background-color: CCCCFF;" align="center">The following selected clones are available through <b>Kazusa</b></td></tr>
EOF
  foreach (@{$clone_listref}) {
    $text .= "<tr><td>$_</td></tr>";
  }

  $text .= <<EOF;
<tr><td style="background-color: CCCCFF;" align="center">
<a href="mailto:plantinfo\@kazusa.or.jp?subject=clone order&amp;body=$clone_order_text"><b>ORDER CLONES (email)</b></a>&nbsp;&nbsp;<input type="submit" name="route_order" value="Delete Order" /><br /><br />
<a href="http://www.kazusa.or.jp/clonereq/">Kazusa Clone request page</a> | <a href="http://www.kazusa.or.jp/clonereq/agreement.html">Kazusa Material Transfer Agreement</a>
</td></tr></table></form>

EOF
return $text;
}

$page->header();

print <<EOF;

<table summary="" width="80%" align="center" cellspacing="2" cellpadding="2" border="0">
<tr><td>
<p>SGN can compile a list of clones to order and then route the orders to appropriate people or facilities for you when you are finished selecting clones. To continue selecting clones, use your browser's back button or start a <a href="/search/direct_search.pl">new search</a></p>
</td></tr>
<tr><td align="center"><b>Shopping Cart Contents</b></td></tr>
<tr><td>
<p />
@order_text
</td></tr>
<tr><td>
<p>
<b>Please Note:</b> SGN does not handle clone orders directly. Selected clones will be routed online to the appropriate parties using the submit buttons above. Your browser <b>must support cookies</b> for this to work properly. Please use your browser's back button to select additional clones, or start a new search using the links above.
</p>
</td></tr>
</table>
EOF

$page->footer();

sub empty_cart {

  $page->header();

  print <<EOF;

  <table summary="" border="0" width="80%" align="center">
  <tr><td align="center"><p>There are no cDNA clones in your shopping cart.</td></tr>
  <tr><td align="center"><p>Please note that your browser must accept cookies to order clones through SGN.</p>
  <br /></td></tr>
  </table>

EOF

  $page->footer();

  exit 0;
}

