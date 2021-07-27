=head1 NAME

SGN::Controller::AJAX::Transgenic - a REST controller class for Vector Constructs. 

=head1 DESCRIPTION

Synchronizes transgenic accessions into the database from the ETHZ CASS database.

=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=cut

package SGN::Controller::AJAX::Transgenic;

use Moose;
use JSON -support_by_pp;
use List::MoreUtils qw /any /;
use Data::Dumper;
use JSON;
use SGN::Model::Cvterm;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub sync_cass_transgenics : Path('/ajax/cass_transgenics/sync') Args(0) ActionClass('REST') { }

sub sync_cass_transgenics_POST { 
    my $self = shift;
    my $c = shift;
    my $status = '';
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $transgenic_names = decode_json($c->req->param("data"));
    my %transgenic_hash = %$transgenic_names;
    my $transgenics = $transgenic_hash{transgenic};
    my @transgenics_array = @$transgenics;

    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $stock_prop_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transgenic', 'stock_property')->cvterm_id();

    my $create_db = $schema->resultset("General::Db")->find_or_create({
    	name => 'ETHZ_CASS',
    	description => 'Internal ETHZ CASS DB',
    	urlprefix => '',
    	url => 'https://cass.pb.ethz.ch'
    });

    foreach (@transgenics_array) {
    	#print STDERR $_->{construct};
    	#print STDERR $_->{construct_id};
    	#print STDERR $_->{level};

    	my $create_stock = $schema->resultset("Stock::Stock")->find_or_create({
            uniquename => $_->{transgenic},
            name => $_->{transgenic},
            type_id => $stock_type_id,
        });

        my $create_dbxref = $schema->resultset("General::Dbxref")->find_or_create({
        	db_id => $create_db->db_id(),
        	accession => $_->{transgenic_id},
        	version => 'transgenic',
        	description => 'ETHZ_CASS transgenic id'
        });

        my $create_stock_dbxref = $schema->resultset("Stock::StockDbxref")->find_or_create({
        	stock_id => $create_stock->stock_id(),
        	dbxref_id => $create_dbxref->dbxref_id()
        });

        my $create_stock_prop = $schema->resultset("Stock::Stockprop")->find_or_create({
        	stock_id => $create_stock->stock_id(),
        	type_id => $stock_prop_type_id,
        	value => 1
        });
    }

    #print STDERR Dumper $transgenics;
    #print STDERR $status;

    $c->stash->{rest} = {response=>$status};
}

1;
