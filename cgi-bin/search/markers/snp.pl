use strict;
use warnings;
use CGI;
use CXGN::DB::DBICFactory;

use CXGN::Marker::SNP::Snp;
use CXGN::Marker::SNP::Schema;

my $schema = CXGN::DB::DBICFactory->open_schema('CXGN::Marker::SNP::Schema');

my ($snp_id) = CGI->new->param("snp_id");
$c->throw( message => 'Must provide a valid SNP id', notify => 0 ) unless $snp_id + 0 eq $snp_id;

my $snp = CXGN::Marker::SNP::Snp->new( $schema, $snp_id )
    or $c->throw( message => "SNP not found", developer_message => "snp_id was '$snp_id'", is_error => 0 );

$c->forward_to_mason_view('/markers/snp/detail.mas', snp => $snp );
