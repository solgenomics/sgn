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
use CXGN::Stock::Vector;
use Try::Tiny;


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

sub create_vector_construct: Path('/ajax/create_vector_construct') Args(0) ActionClass('REST') { }

sub create_vector_construct_POST { 
    my $self = shift;
    my $c = shift;
    my $status = '';
    my $schema = $c->dbic_schema("Bio::Chado::Schema",'sgn_chado');
    my $vector_list;
    my $organism_list;
    my $user_id = $c->user ? $c->user->get_object()->get_sp_person_id():undef;

    if (!$user_id){
        $status = sprintf('You must be logged in to add a vector!');
        $c->stash->{rest} = {error=>$status};
        return;
    }

    my $dbh = $schema->storage()->dbh();
    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $user_name = $person->get_username;

    my $data = decode_json($c->req->param("data"));

    foreach (@$data){
        my $vector = $_->{uniqueName} || undef;
        my $organism = $_->{species_name} || undef;
        push @$vector_list, $vector;
        push @$organism_list, $organism;
    }

    #validate accessions/vector
    my $validator = CXGN::List::Validate->new();
    my @absent_accessions = @{$validator->validate($schema, 'accessions', $vector_list)->{'missing'}};
    my %accessions_missing_hash = map { $_ => 1 } @absent_accessions;
    my $existing_vectors = '';

    my $validator2 = CXGN::List::Validate->new();
    my @absent_vectors = @{$validator2->validate($schema, 'vector_constructs', $vector_list)->{'missing'}};
    my %vectors_missing_hash = map { $_ => 1 } @absent_vectors;

    foreach (@$vector_list){
        if (!exists($accessions_missing_hash{$_})){
            $existing_vectors = $existing_vectors . $_ ."," ;
        }
        if (!exists($vectors_missing_hash{$_})){
            $existing_vectors = $existing_vectors . $_ ."," ;
        }
    }

    if (length($existing_vectors) >0){
        $status = sprintf('Existing vectors or accessions in the database: %s', $existing_vectors);
        $c->stash->{rest} = {error=>$status};
        return;
    }

    #validate organism
    my $organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
    my $organism_result = $organism_search->get_matches($organism_list, '1');

    my @allowed_organisms;
    my $missing_organisms = '';
    my $found = $organism_result->{found};

    foreach (@$found){
        push @allowed_organisms, $_->{unique_name};
    }
    my %allowed_organisms = map {$_=>1} @allowed_organisms;

    foreach (@$organism_list){
        if (!exists($allowed_organisms{$_})){
            $missing_organisms = $missing_organisms . $_ . ",";
        }
    }
    if (length($missing_organisms) >0){
        $status = sprintf('Organisms were not found on the database: %s', $missing_organisms);
        $c->stash->{rest} = {error=>$status};
        return;
    }

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();

    my @added_stocks;
    my $coderef_bcs = sub {
        foreach my $params (@$data){
            my $species = $params->{species_name} || undef;
            my $uniquename = $params->{uniqueName} || undef;
            my $strain = $params->{Strain} || undef;
            my $backbone = $params->{Backbone} || undef;
            my $cloning_organism = $params->{CloningOrganism} || undef;
            my $inherent_marker = $params->{InherentMarker} || undef;
            my $selection_marker = $params->{SelectionMarker} || undef;
            my $cassette_name = $params->{CassetteName} || undef;
            my $vector_type = $params->{VectorType} || undef;
            my $gene = $params->{Gene} || undef;
            my $promotors = $params->{Promotors} || undef;
            my $terminators = $params->{Terminators} || undef;

            if (exists($allowed_organisms{$species})){
                my $stock = CXGN::Stock::Vector->new({
                    schema=>$schema,
                    check_name_exists=>0,
                    type=>'vector_construct',
                    type_id=>$type_id,
                    sp_person_id => $user_id,
                    user_name => $user_name,
                    species=>$species,
                    name=>$uniquename,
                    uniquename=>$uniquename,
                    Strain=>$strain,
                    Backbone=>$backbone,
                    CloningOrganism=>$cloning_organism,
                    InherentMarker=>$inherent_marker,
                    SelectionMarker=>$selection_marker,
                    CassetteName=>$cassette_name,
                    VectorType=>$vector_type,
                    Gene=>$gene,
                    Promotors=>$promotors,
                    Terminators=>$terminators
                });
               my $added_stock_id = $stock->store();
                push @added_stocks, $added_stock_id;
            }
        }
        if (scalar(@added_stocks) > 0){
            my $dbh = $c->dbc->dbh();
            my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
            my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});
        }
    };

    #save data
    my $transaction_error;

    try {
       $schema->txn_do($coderef_bcs);
    }
    catch {
        $transaction_error = $_;
    };

    if ($transaction_error){
        $status = sprintf('There was an error storing vector %s', $transaction_error);
    }

    $c->stash->{rest} = {response=>$status};
}

1;
