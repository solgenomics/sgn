use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::Login;
use JSON;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();
my ($stock_name, $locus_id, $type, $allele_id, $stock_id) = $doc->get_encoded_arguments("stock_name", "locus_id", "type", "allele_id" , "stock_id");

my $dbh = CXGN::DB::Connection->new();

my($login_person_id, $login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {

    if ($type eq 'browse') {
	my $query = $dbh->prepare("SELECT stock_id, name, description FROM public.stock WHERE stock.name ilike ? ");
	$query->execute("\%$stock_name\%");
	my $available_stocks;
        while ( my ($stock_id, $name, $desc)   = $query->fetchrow_array() ) {
            $available_stocks .= "$stock_id*$name--$desc|";
        }
	print "$available_stocks";
    }
    #search from the allele page. Fiter only the existing individuals associated with $allele.
    #obsolete individual-allele association
    elsif ($type eq 'obsolete') {
	eval {
	    my $query = "delete from public.stockprop WHERE stock_id = ? AND value = ? AND type_id = (select cvterm_id from public.cvterm where cvterm.name = ?";
	    my $sth= $dbh->prepare($query);
            $sth->execute($stock_id, $allele_id, 'sgn allele_id');
	};
        if ($@) {
	    warn "stock-allele obsoletion failed! " . $@ ;
	}
    }
}
