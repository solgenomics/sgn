#!/usr/bin/perl
use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::UserList::Hotlist;
#use CXGN::Login;

my $page = CXGN::Scrap::AjaxPage->new();
my %args = $page->get_all_encoded_arguments();

$page->send_http_header;
print $page->header();

print "<caller>Fasta</caller>\n";

#   Test high-latency conditions for AJAX:
# 	system("sleep 3");

my $type = $args{type} or $page->throw("Type must be specified");
$type =~ /(protein)|(genomic)|(cdna)|(cds)/ or $page->throw("Invalid sequence type: $type");

my $agi_list = $args{agi_list} or $page->throw("Agi list must be sent");

my $fasta = "";

my $dbh = CXGN::DB::Connection->new("public");

my $sth = $dbh->prepare("SELECT $type FROM ara_sequence WHERE agi=?");

my @agis = split /::/, $agi_list;		

foreach(@agis){
	$sth->execute($_);
	my $row = $sth->fetchrow_hashref;
	my $seq = $row->{$type};
	$seq =~ s/(\w{60})/$1\n/g;
	$fasta .= ">$_ | " . $type . "\n$seq\n";
}
print "<type>$type</type>\n";
print "<fasta>$fasta\n</fasta>";

print $page->footer();
