=head1 NAME

SGN::Controller::AJAX::VectorConstruct - a REST controller class for Vector Constructs. 

=head1 DESCRIPTION

Synchronizes vector constructs into the database from the ETHZ CASS database.

=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=cut

package SGN::Controller::AJAX::VectorConstruct;

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

sub sync_cass_constructs : Path('/ajax/cass_vector_construct/sync') Args(0) ActionClass('REST') { }

sub sync_cass_constructs_POST { 
    my $self = shift;
    my $c = shift;
    my $status = '';
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $construct_names = decode_json($c->req->param("data"));
    my %construct_hash = %$construct_names;
    my $constructs = $construct_hash{construct};
    my @construct_array = @$constructs;

    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();

    my $create_db = $schema->resultset("General::Db")->find_or_create({
    	name => 'ETHZ_CASS',
    	description => 'Internal ETHZ CASS DB',
    	urlprefix => '',
    	url => 'https://cass.pb.ethz.ch'
    });

    foreach (@construct_array) {
    	#print STDERR $_->{construct};
    	#print STDERR $_->{construct_id};
    	#print STDERR $_->{level};

    	my $create_stock = $schema->resultset("Stock::Stock")->find_or_create({
            uniquename => $_->{construct},
            name => $_->{construct},
            type_id => $stock_type_id,
        });

        my $create_dbxref = $schema->resultset("General::Dbxref")->find_or_create({
        	db_id => $create_db->db_id(),
        	accession => $_->{construct_id},
        	version => 'vector_construct',
        	description => 'ETHZ_CASS vector_construct id'
        });

        my $create_stock_dbxref = $schema->resultset("Stock::StockDbxref")->find_or_create({
        	stock_id => $create_stock->stock_id(),
        	dbxref_id => $create_dbxref->dbxref_id()
        });
    }

    #print STDERR Dumper $constructs;
    #print STDERR $status;

    $c->stash->{rest} = {response=>$status};
}

1;
