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
use CXGN::Stock::Vector::ParseUpload;
use Try::Tiny;
use Encode;
use JSON::XS qw | decode_json |;
use utf8;


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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

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
    my $vector_list;
    my $user_id = $c->user ? $c->user->get_object()->get_sp_person_id():undef;

    if (!$user_id){
        $status = sprintf('You must be logged in to add a vector!');
        $c->stash->{rest} = {error=>$status};
        return;
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema",'sgn_chado', $user_id);
    my $dbh = $schema->storage()->dbh();
    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $user_name = $person->get_username;

    my $data = decode_json( encode("utf8", $c->req->param('data')));

    foreach (@$data){
        my $vector = $_->{uniqueName} || undef;
        my $organism = $_->{species_name} || undef;
        push @$vector_list, $vector;
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

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();

    my @added_stocks;
    my @added_fullinfo_stocks;
    my $coderef_bcs = sub {
        foreach my $params (@$data){
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
            my $plant_antibiotic_resistant_marker = $params->{PlantAntibioticResistantMarker} || undef;
            my $bacterial_resistant_marker = $params->{BacterialResistantMarker} || undef;

            my $stock = CXGN::Stock::Vector->new({
                schema=>$schema,
                check_name_exists=>0,
                type=>'vector_construct',
                type_id=>$type_id,
                sp_person_id => $user_id,
                user_name => $user_name,
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
                Terminators=>$terminators,
                PlantAntibioticResistantMarker=>$plant_antibiotic_resistant_marker,
                BacterialResistantMarker=>$bacterial_resistant_marker
            });
            my $added_stock_id = $stock->store();
            push @added_stocks, $added_stock_id;
            push @added_fullinfo_stocks, [$added_stock_id, $uniquename];
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

    if (scalar(@added_stocks) > 0){
        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});
    }

    $c->stash->{rest} = {
        response=>$status,
        success => "1",
        added => \@added_fullinfo_stocks
    };
}

sub verify_vectors_file : Path('/ajax/vectors/verify_vectors_file') : ActionClass('REST') { }
sub verify_vectors_file_POST : Args(0) {
    my ($self, $c) = @_;

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this vector info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this vector info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $upload = $c->req->upload('new_vectors_upload_file');
    my $do_fuzzy_search = $user_role eq 'curator' && !$c->req->param('fuzzy_check_upload_vectors') ? 0 : 1;
    my $autogenerate_uniquename = !$c->req->param('autogenerate_uniquename') ? 0 : 1;

    if ($user_role ne 'curator' && !$do_fuzzy_search) {
        $c->stash->{rest} = {error=>'Only a curator can add vectors without using the fuzzy search!'};
        $c->detach();
    }

    # These roles are required by CXGN::UploadFile
    if ($user_role ne 'curator' && $user_role ne 'submitter' && $user_role ne 'sequencer' ) {
        $c->stash->{rest} = {error=>'Only a curator, submitter or sequencer can upload a file'};
        $c->detach();
    }

    my $subdirectory = "vectors_spreadsheet_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;

    my @editable_vector_props = split ',', $c->config->{editable_vector_props};
    my $parser = CXGN::Stock::Vector::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path, editable_stock_props=>\@editable_vector_props, do_fuzzy_search=>$do_fuzzy_search, autogenerate_uniquename=>$autogenerate_uniquename);
    $parser->load_plugin('VectorsXLS');
    my $parsed_data = $parser->parse();

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
            $c->detach();
        } else {
            $parse_errors = $parser->get_parse_errors();

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_species => $parse_errors->{'missing_species'}};
        $c->detach();
    }

    my $full_data = $parsed_data->{parsed_data};
    my @vector_names;
    my %full_vectors;
    while (my ($k,$val) = each %$full_data){
        push @vector_names, $val->{germplasmName};
        $full_vectors{$val->{germplasmName}} = $val;
    }

    my $new_list_id = CXGN::List::create_list($c->dbc->dbh, "VectorsIn".$upload_original_name.$timestamp, 'Autocreated when upload vectors from file '.$upload_original_name.$timestamp, $user_id);
    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id => $new_list_id } );

    $list->add_bulk(\@vector_names);
    $list->type('vector_construct');

    my %return = (
        success => "1",
        list_id => $new_list_id,
        full_data => \%full_vectors,
        absent => $parsed_data->{absent_vectors},
        fuzzy => $parsed_data->{fuzzy_vectors},
        found => $parsed_data->{found_vectors},
        absent_organisms => $parsed_data->{absent_organisms},
        fuzzy_organisms => $parsed_data->{fuzzy_organisms},
        found_organisms => $parsed_data->{found_organisms}
    );

    if ($parsed_data->{error_string}){
        $return{error_string} = $parsed_data->{error_string};
    }


    $c->stash->{rest} = \%return;
}


sub verify_vectors_fuzzy_options : Path('/ajax/vector_list/fuzzy_options') : ActionClass('REST') { }

sub verify_vectors_fuzzy_options_POST : Args(0) {
    my ($self, $c) = @_;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $vector_list_id = $c->req->param('vector_list_id');
    my $fuzzy_option_hash = decode_json( encode("utf8", $c->req->param('fuzzy_option_data')));
    my $names_to_add = _parse_list_from_json($c, $c->req->param('names_to_add'));

    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $vector_list_id } );

    my %names_to_add = map {$_ => 1} @$names_to_add;
    foreach my $form_name (keys %$fuzzy_option_hash){
        my $item_name = $fuzzy_option_hash->{$form_name}->{'fuzzy_name'};
        my $select_name = $fuzzy_option_hash->{$form_name}->{'fuzzy_select'};
        my $fuzzy_option = $fuzzy_option_hash->{$form_name}->{'fuzzy_option'};
        if ($fuzzy_option eq 'replace'){
            $list->replace_by_name($item_name, $select_name);
            delete $names_to_add{$item_name};
        } elsif ($fuzzy_option eq 'keep'){
            $names_to_add{$item_name} = 1;
        } elsif ($fuzzy_option eq 'remove'){
            $list->remove_by_name($item_name);
            delete $names_to_add{$item_name};
        } elsif ($fuzzy_option eq 'synonymize'){
            my $stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>$select_name})->stock_id();
            my $stock = CXGN::Chado::Stock->new($schema, $stock_id);
            $stock->add_synonym($item_name);

            delete $names_to_add{$item_name};
        }
    }

    my @names_to_add = sort keys %names_to_add;
    my $rest = {
        success => "1",
        names_to_add => \@names_to_add
    };
    $c->stash->{rest} = $rest;
}


sub get_new_vector_uniquename : Path('/ajax/get_new_vector_uniquename') : ActionClass('REST') { }

sub get_new_vector_uniquename_GET : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();

    my $stocks = $schema->resultset("Stock::Stock")->search({
        type_id => $stock_type_id,
    });

    my $id;
    my $max=0;
    while (my $r = $stocks->next()) {
        $id = $r->uniquename;
        if ($id =~ m/T[0-9]+/){
            $id =~ s/T//;
            if($max < $id){
                $max = $id;
            }
        }
    }
    $max += 1;
    #Vector construct has letter T before autogenerated number.
    $c->stash->{rest} = [ "T". $max];
}


sub _parse_list_from_json {
    my $c = shift;
    my $list_json = shift;
    my $json = JSON::XS->new();

    if ($list_json) {
        debug($c, "LIST_JSON is utf8? ".utf8::is_utf8($list_json)." valid utf8? ".utf8::valid($list_json)."\n");
        print STDERR "JSON NOW: $list_json\n";
        my $decoded_list = $json->decode($list_json);

        my @array_of_list_items = ();
        if (ref($decoded_list) eq "ARRAY" ) {
            @array_of_list_items = @{$decoded_list};
        }
        else {
            debug($c, "Dont know what to do " );
        }

        return \@array_of_list_items;
    }
    else {
        return;
    }
}

sub debug {
    my $c = shift;
    my $message = shift;
}

1;
