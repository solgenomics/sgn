#!/usr/bin/perl -w
use strict;
use CatalystX::GlobalContext '$c';
use SGN::I18N;
use HTML::Entities qw(encode_entities);
my SGN::I18N $i18n = eval { $c && $c->i18n };
my $render_i18n_html = sub {
    my ($message, $slots) = @_;
    my $html = encode_entities($message);
    # One substitution pass: inserted data cannot become another markup slot.
    $html =~ s/(__SGN_UI_[A-Z0-9_]+__)/exists $slots->{$1} ? $slots->{$1} : $1/ge;
    return $html;
};
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Cookie;
my $dbh = CXGN::DB::Connection->new();
my $check_q = $dbh->prepare("SELECT order_routing_id from clone LEFT JOIN library USING (library_id) where clone_name=?");

my $page_title = encode_entities($i18n ? $i18n->p('global.clone-order.page_title', 'Clone Shopping Cart') : 'Clone Shopping Cart');
our $page = CXGN::Page->new($page_title, "Koni");

my ($clone_add) = $page->get_arguments("add_clone");

my $cart_contents = CXGN::Cookie::get_cookie("CloneCart");
my $cart_contents_label = encode_entities(($i18n ? $i18n->p('global.clone-order.cart_contents', 'Shopping Cart Contents') : 'Shopping Cart Contents'));
my $empty_cart_label = encode_entities(($i18n ? $i18n->p('global.clone-order.empty_cart', 'There are no cDNA clones in your shopping cart.') : 'There are no cDNA clones in your shopping cart.'));
my $new_search_link = '<a href="/search/direct_search.pl">' . encode_entities($i18n ? $i18n->p('global.clone-order.new_search', 'new search') : 'new search') . '</a>';
my $shopping_cart_intro = $render_i18n_html->(($i18n ? $i18n->p("global.clone-order.intro", "SGN can compile a list of clones to order and then route the orders to appropriate people or facilities for you when you are finished selecting clones. To continue selecting clones, use your browser's back button or start a %{search_link}", {search_link => "__SGN_UI_SEARCH_LINK__"}) : "SGN can compile a list of clones to order and then route the orders to appropriate people or facilities for you when you are finished selecting clones. To continue selecting clones, use your browser's back button or start a __SGN_UI_SEARCH_LINK__"), {"__SGN_UI_SEARCH_LINK__" => $new_search_link});
my $cookie_note = $render_i18n_html->(($i18n ? $i18n->p("global.clone-order.cookie_note", "%{note_label} SGN does not handle clone orders directly. Selected clones will be routed online to the appropriate parties using the submit buttons above. Your browser %{cookie_support} for this to work properly. Please use your browser's back button to select additional clones, or start a new search using the links above.", {note_label => "__SGN_UI_NOTE_LABEL__", cookie_support => "__SGN_UI_COOKIE_SUPPORT__"}) : "__SGN_UI_NOTE_LABEL__ SGN does not handle clone orders directly. Selected clones will be routed online to the appropriate parties using the submit buttons above. Your browser __SGN_UI_COOKIE_SUPPORT__ for this to work properly. Please use your browser's back button to select additional clones, or start a new search using the links above."), {"__SGN_UI_NOTE_LABEL__" => '<b>' . encode_entities(($i18n ? $i18n->p("global.safe_caption.please_note", "Please Note:") : "Please Note:")) . '</b>', "__SGN_UI_COOKIE_SUPPORT__" => '<b>' . encode_entities(($i18n ? $i18n->p("global.safe_caption.cookie_support", "must support cookies") : "must support cookies")) . '</b>'});
my $empty_cart_cookie_note = encode_entities($i18n ? $i18n->p('global.clone-order.empty_cart_cookie_note', 'Please note that your browser must accept cookies to order clones through SGN.') : 'Please note that your browser must accept cookies to order clones through SGN.');
my $ted_supplier_label = $render_i18n_html->(($i18n ? $i18n->p("global.clone-order.supplier_available", "The following selected clones are available through %{supplier}", {supplier => "__SGN_UI_SUPPLIER__"}) : "The following selected clones are available through __SGN_UI_SUPPLIER__"), {"__SGN_UI_SUPPLIER__" => '<b>TED</b>'});
my $kazusa_supplier_label = $render_i18n_html->(($i18n ? $i18n->p("global.clone-order.supplier_available", "The following selected clones are available through %{supplier}", {supplier => "__SGN_UI_SUPPLIER__"}) : "The following selected clones are available through __SGN_UI_SUPPLIER__"), {"__SGN_UI_SUPPLIER__" => '<b>Kazusa</b>'});
my $order_clones_email = encode_entities($i18n ? $i18n->p('global.clone-order.order_clones_email', 'ORDER CLONES (email)') : 'ORDER CLONES (email)');
my $kazusa_request_page = encode_entities($i18n ? $i18n->p('global.clone-order.kazusa_request_page', 'Kazusa Clone request page') : 'Kazusa Clone request page');
my $kazusa_agreement = encode_entities($i18n ? $i18n->p('global.clone-order.kazusa_agreement', 'Kazusa Material Transfer Agreement') : 'Kazusa Material Transfer Agreement');

if (!$cart_contents) {
  $cart_contents = "";
}

my @clones = split /,/,$cart_contents;
if ($clone_add) {
  push @clones, $clone_add;
}

# Note: An advantage of server-side statefulness here is not repeating this
#       every time. This is typical of stateful/stateless tradeoff -- storing
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
    my SGN::I18N $cgi_clone_order_ted_order_routing_i18n = eval { $c && $c->i18n };
    my $render_i18n_html = sub {
    my ($message, $slots) = @_;
    my $html = encode_entities($message);
    # One substitution pass: inserted data cannot become another markup slot.
    $html =~ s/(__SGN_UI_[A-Z0-9_]+__)/exists $slots->{$1} ? $slots->{$1} : $1/ge;
    return $html;
};
    my $ted_supplier_label = $render_i18n_html->(($cgi_clone_order_ted_order_routing_i18n ? $cgi_clone_order_ted_order_routing_i18n->p("global.clone-order.supplier_available", "The following selected clones are available through %{supplier}", {supplier => "__SGN_UI_SUPPLIER__"}) : "The following selected clones are available through __SGN_UI_SUPPLIER__"), {"__SGN_UI_SUPPLIER__" => '<b>TED</b>'});

  my ($clone_listref) = @_;
  my $clone_order = join(",",@{$clone_listref});
  my $text = <<EOF;
  <form method="post" action="/search/route-order.pl" target="_BLANK">
<input type="hidden" name="route_to" value="1" />
<input type="hidden" name="order_clones" value="$clone_order" />
<table summary="" cellpadding="2" cellspacing="2" border="0" align="center" width="100%">
<tr><td style="background-color: CCCCFF;" align="center">$ted_supplier_label</td></tr>
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
    my SGN::I18N $cgi_clone_order_kazusa_order_routing_i18n = eval { $c && $c->i18n };
    my $render_i18n_html = sub {
    my ($message, $slots) = @_;
    my $html = encode_entities($message);
    # One substitution pass: inserted data cannot become another markup slot.
    $html =~ s/(__SGN_UI_[A-Z0-9_]+__)/exists $slots->{$1} ? $slots->{$1} : $1/ge;
    return $html;
};
    my $kazusa_supplier_label = $render_i18n_html->(($cgi_clone_order_kazusa_order_routing_i18n ? $cgi_clone_order_kazusa_order_routing_i18n->p("global.clone-order.supplier_available", "The following selected clones are available through %{supplier}", {supplier => "__SGN_UI_SUPPLIER__"}) : "The following selected clones are available through __SGN_UI_SUPPLIER__"), {"__SGN_UI_SUPPLIER__" => '<b>Kazusa</b>'});
    my $order_clones_email = encode_entities($cgi_clone_order_kazusa_order_routing_i18n ? $cgi_clone_order_kazusa_order_routing_i18n->p('global.clone-order.order_clones_email', 'ORDER CLONES (email)') : 'ORDER CLONES (email)');
    my $kazusa_request_page = encode_entities($cgi_clone_order_kazusa_order_routing_i18n ? $cgi_clone_order_kazusa_order_routing_i18n->p('global.clone-order.kazusa_request_page', 'Kazusa Clone request page') : 'Kazusa Clone request page');
    my $kazusa_agreement = encode_entities($cgi_clone_order_kazusa_order_routing_i18n ? $cgi_clone_order_kazusa_order_routing_i18n->p('global.clone-order.kazusa_agreement', 'Kazusa Material Transfer Agreement') : 'Kazusa Material Transfer Agreement');

    my ($clone_listref) = @_;
    my $clone_order = join(",", @{$clone_listref});
    my $clone_order_text = "Dear Kazusa, %0AI would like to order the following clones:%0A$clone_order%0A";
    my $text = <<EOF;
<form method="post" action="/search/route-order.pl" target="_BLANK">
<input type="hidden" name="route_to" value="1" />
<input type="hidden" name="order_clones" value="$clone_order" />
<table summary="" cellpadding="2" cellspacing="2" border="0" align="center" width="100%">
<tr><td style="background-color: CCCCFF;" align="center">$kazusa_supplier_label</td></tr>
EOF
  foreach (@{$clone_listref}) {
    $text .= "<tr><td>$_</td></tr>";
  }

  $text .= <<EOF;
<tr><td style="background-color: CCCCFF;" align="center">
<a href="mailto:plantinfo\@kazusa.or.jp?subject=clone order&amp;body=$clone_order_text"><b>$order_clones_email</b></a>&nbsp;&nbsp;<input type="submit" name="route_order" value="Delete Order" /><br /><br />
<a href="http://www.kazusa.or.jp/clonereq/">$kazusa_request_page</a> | <a href="http://www.kazusa.or.jp/clonereq/agreement.html">$kazusa_agreement</a>
</td></tr></table></form>

EOF
return $text;
}

$page->header();

print <<EOF;

<table summary="" width="80%" align="center" cellspacing="2" cellpadding="2" border="0">
<tr><td>
<p>$shopping_cart_intro</p>
</td></tr>
<tr><td align="center"><b>$cart_contents_label</b></td></tr>
<tr><td>
<p />
@order_text
</td></tr>
<tr><td>
<p>
$cookie_note
</p>
</td></tr>
</table>
EOF

$page->footer();

sub empty_cart {
    my SGN::I18N $cgi_clone_order_empty_cart_i18n = eval { $c && $c->i18n };
    my $empty_cart_label = encode_entities(($cgi_clone_order_empty_cart_i18n ? $cgi_clone_order_empty_cart_i18n->p('global.clone-order.empty_cart', 'There are no cDNA clones in your shopping cart.') : 'There are no cDNA clones in your shopping cart.'));
    my $empty_cart_cookie_note = encode_entities($cgi_clone_order_empty_cart_i18n ? $cgi_clone_order_empty_cart_i18n->p('global.clone-order.empty_cart_cookie_note', 'Please note that your browser must accept cookies to order clones through SGN.') : 'Please note that your browser must accept cookies to order clones through SGN.');


  $page->header();

  print <<EOF;

  <table summary="" border="0" width="80%" align="center">
  <tr><td align="center"><p>$empty_cart_label</td></tr>
  <tr><td align="center"><p>$empty_cart_cookie_note</p>
  <br /></td></tr>
  </table>

EOF

  $page->footer();

  exit 0;
}

