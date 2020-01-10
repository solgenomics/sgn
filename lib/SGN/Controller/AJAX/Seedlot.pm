
package SGN::Controller::AJAX::Seedlot;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

use Data::Dumper;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;
use SGN::Model::Cvterm;
use CXGN::Stock::Seedlot::ParseUpload;
use CXGN::Login;
use JSON;
use CXGN::BreederSearch;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub list_seedlots :Path('/ajax/breeders/seedlots') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params() || {};
    #print STDERR Dumper $params;
    my $seedlot_name = $params->{seedlot_name} || '';
    my $breeding_program = $params->{breeding_program} || '';
    my $location = $params->{location} || '';
    my $minimum_count = $params->{minimum_count} || '';
    my $minimum_weight = $params->{minimum_weight} || '';
    my $contents_accession = $params->{contents_accession} || '';
    my $contents_cross = $params->{contents_cross} || '';
    my $exact_accession = $params->{exact_accession};
    my $exact_cross = $params->{exact_cross};
    my $rows = $params->{length} || 10;
    my $offset = $params->{start} || 0;
    my $limit = ($offset+$rows)-1;
    my $draw = $params->{draw};
    $draw =~ s/\D//g; # cast to int

    my @accessions = split ',', $contents_accession;
    my @crosses = split ',', $contents_cross;

    my $exact_match_uniquenames = 0;
    if (@accessions > 0 && $exact_accession) {
        $exact_match_uniquenames = 1;
    } elsif (@crosses > 0 && $exact_cross) {
        $exact_match_uniquenames = 1;
    }

    my ($list, $records_total) = CXGN::Stock::Seedlot->list_seedlots(
        $c->dbic_schema("Bio::Chado::Schema", "sgn_chado"),
        $c->dbic_schema("CXGN::People::Schema"),
        $c->dbic_schema("CXGN::Phenome::Schema"),
        $offset,
        $limit,
        $seedlot_name,
        $breeding_program,
        $location,
        $minimum_count,
        \@accessions,
        \@crosses,
        $exact_match_uniquenames,
        $minimum_weight
    );
    my @seedlots;
    foreach my $sl (@$list) {
        my $source_stock = $sl->{source_stocks};
        my $contents_html = '';
        if ($source_stock->[0]->[2] eq 'accession'){
            $contents_html .= '<a href="/stock/'.$source_stock->[0]->[0].'/view">'.$source_stock->[0]->[1].'</a> ('.$source_stock->[0]->[2].') ';
        }
        if ($source_stock->[0]->[2] eq 'cross'){
            $contents_html .= '<a href="/cross/'.$source_stock->[0]->[0].'">'.$source_stock->[0]->[1].'</a> ('.$source_stock->[0]->[2].') ';
        }
        push @seedlots, {
            breeding_program_id => $sl->{breeding_program_id},
            breeding_program_name => $sl->{breeding_program_name},
            seedlot_stock_id => $sl->{seedlot_stock_id},
            seedlot_stock_uniquename => $sl->{seedlot_stock_uniquename},
            contents_html => $contents_html,
            location => $sl->{location},
            location_id => $sl->{location_id},
            count => $sl->{current_count},
            weight_gram => $sl->{current_weight_gram},
            owners_string => $sl->{owners_string},
            organization => $sl->{organization},
            box => $sl->{box}
        };
    }

    #print STDERR Dumper(\@seedlots);

    $c->stash->{rest} = { data => \@seedlots, draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
}

sub seedlot_base : Chained('/') PathPart('ajax/breeders/seedlot') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $seedlot_id = shift;

    print STDERR "Seedlot id = $seedlot_id\n";

    $c->stash->{schema} = $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{phenome_schema} = $c->dbic_schema("CXGN::Phenome::Schema");
    $c->stash->{seedlot_id} = $seedlot_id;
    $c->stash->{seedlot} = CXGN::Stock::Seedlot->new(
        schema => $c->stash->{schema},
        phenome_schema => $c->stash->{phenome_schema},
        seedlot_id => $c->stash->{seedlot_id},
    );
}

sub seedlot_details :Chained('seedlot_base') PathPart('') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{rest} = {
        success => 1,
        uniquename => $c->stash->{seedlot}->uniquename(),
        seedlot_id => $c->stash->{seedlot}->seedlot_id(),
        current_count => $c->stash->{seedlot}->current_count(),
        current_weight => $c->stash->{seedlot}->current_weight(),
        location_code => $c->stash->{seedlot}->location_code(),
        breeding_program => $c->stash->{seedlot}->breeding_program_name(),
        organization_name => $c->stash->{seedlot}->organization_name(),
        population_name => $c->stash->{seedlot}->population_name(),
        accession => $c->stash->{seedlot}->accession(),
        cross => $c->stash->{seedlot}->cross(),
        box_name => $c->stash->{seedlot}->box_name(),
    };
}

sub seedlot_edit :Chained('seedlot_base') PathPart('edit') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in to edit seedlot details" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to edit seedlot detail. Please contact us." };
        $c->detach();
    }
    my $seedlot = $c->stash->{seedlot};

    my $saved_seedlot_name = $seedlot->uniquename;
    my $seedlot_name = $c->req->param('uniquename');
    my $breeding_program_name = $c->req->param('breeding_program');
    my $organization = $c->req->param('organization');
    my $population = $c->req->param('population');
    my $location = $c->req->param('location');
    my $box_name = $c->req->param('box_name');
    my $accession_uniquename = $c->req->param('accession');
    my $cross_uniquename = $c->req->param('cross');
    my $schema = $c->stash->{schema};
    my $breeding_program = $schema->resultset('Project::Project')->find({name=>$breeding_program_name});
    if (!$breeding_program){
        $c->stash->{rest} = { error => "The breeding program $breeding_program_name does not exist in the database. Please add it first or choose another." };
        $c->detach();
    }
    my $breeding_program_id = $breeding_program->project_id();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    if ($saved_seedlot_name ne $seedlot_name){
        my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_name, type_id=>$seedlot_cvterm_id});
        if ($previous_seedlot){
            $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
            $c->detach();
        }
    }
    my $accession_id;
    if ($accession_uniquename){
        $accession_id = $schema->resultset('Stock::Stock')->find({uniquename=>$accession_uniquename, type_id=>$accession_cvterm_id})->stock_id();
    }
    my $cross_id;
    if ($cross_uniquename){
        $cross_id = $schema->resultset('Stock::Stock')->find({uniquename=>$cross_uniquename, type_id=>$cross_cvterm_id})->stock_id();
    }
    if ($accession_uniquename && !$accession_id){
        $c->stash->{rest} = {error=>'The given accession name is not in the database! Seedlots can only be added onto existing accessions.'};
        $c->detach();
    }
    if ($cross_uniquename && !$cross_id){
        $c->stash->{rest} = {error=>'The given cross name is not in the database! Seedlots can only be added onto existing crosses.'};
        $c->detach();
    }
    if ($accession_id && $cross_id){
        $c->stash->{rest} = {error=>'A seedlot must have either an accession OR a cross as contents. Not both.'};
        $c->detach();
    }
    if (!$accession_id && !$cross_id){
        $c->stash->{rest} = {error=>'A seedlot must have either an accession or a cross as contents.'};
        $c->detach();
    }

    $seedlot->name($seedlot_name);
    $seedlot->uniquename($seedlot_name);
    $seedlot->breeding_program_id($breeding_program_id);
    $seedlot->organization_name($organization);
    $seedlot->location_code($location);
    $seedlot->box_name($box_name);
    $seedlot->accession_stock_id($accession_id);
    $seedlot->cross_stock_id($cross_id);
    $seedlot->population_name($population);
    my $return = $seedlot->store();
    if (exists($return->{error})){
        $c->stash->{rest} = { error => $return->{error} };
    } else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub seedlot_delete :Chained('seedlot_base') PathPart('delete') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in the delete seedlots" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to delete seedlots. Please contact us." };
        $c->detach();
    }

    my $error = $c->stash->{seedlot}->delete();
    if (!$error){
        $c->stash->{rest} = { success => 1 };
    }
    else {
        $c->stash->{rest} = { error => $error };
    }
}

sub create_seedlot :Path('/ajax/breeders/seedlot-create/') :Args(0) {
    my $self = shift;
    my $c = shift;
    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to add a seedlot transaction!'};
        $c->detach();
    }
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $seedlot_uniquename = $c->req->param("seedlot_name");
    my $location_code = $c->req->param("seedlot_location");
    my $box_name = $c->req->param("seedlot_box_name");
    my $accession_uniquename = $c->req->param("seedlot_accession_uniquename");
    my $cross_uniquename = $c->req->param("seedlot_cross_uniquename");

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_uniquename, type_id=>$seedlot_cvterm_id});
    if ($previous_seedlot){
        $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
        $c->detach();
    }
    my $accession_id;
    if ($accession_uniquename){
        # In case of synonyms, use stocklookup
        my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema, stock_name=>$accession_uniquename });
        my $stock_lookup_rs = $stock_lookup->get_stock($accession_cvterm_id);
        if (!$stock_lookup_rs){
            $c->stash->{rest} = {error=>'The accession name you provided does not match to a unique accession. Please make sure you are using the correct name or contact us.'};
            $c->detach();
        }
        $accession_id = $stock_lookup_rs->stock_id();
        $accession_uniquename = $stock_lookup_rs->uniquename();
    }
    my $cross_id;
    if ($cross_uniquename){
        $cross_id = $schema->resultset('Stock::Stock')->find({uniquename=>$cross_uniquename, type_id=>$cross_cvterm_id})->stock_id();
    }
    if ($accession_uniquename && !$accession_id){
        $c->stash->{rest} = {error=>'The given accession name is not in the database! Seedlots can only be added onto existing accessions.'};
        $c->detach();
    }
    if ($cross_uniquename && !$cross_id){
        $c->stash->{rest} = {error=>'The given cross name is not in the database! Seedlots can only be added onto existing crosses.'};
        $c->detach();
    }
    if ($accession_id && $cross_id){
        $c->stash->{rest} = {error=>'A seedlot must have either an accession OR a cross as contents. Not both.'};
        $c->detach();
    }
    if (!$accession_id && !$cross_id){
        $c->stash->{rest} = {error=>'A seedlot must have either an accession or a cross as contents.'};
        $c->detach();
    }

    my $from_stock_id = $accession_id ? $accession_id : $cross_id;
    my $from_stock_uniquename = $accession_uniquename ? $accession_uniquename : $cross_uniquename;
    my $population_name = $c->req->param("seedlot_population_name");
    my $organization = $c->req->param("seedlot_organization");
    my $amount = $c->req->param("seedlot_amount");
    my $weight = $c->req->param("seedlot_weight");
    my $timestamp = $c->req->param("seedlot_timestamp");
    my $description = $c->req->param("seedlot_description");
    my $breeding_program_id = $c->req->param("seedlot_breeding_program_id");

    if (!$weight && !$amount){
        $c->stash->{rest} = {error=>'A seedlot must have either a weight or an amount.'};
        $c->detach();
    }

    if (!$timestamp){
        $c->stash->{rest} = {error=>'A seedlot must have a timestamp for the transaction.'};
        $c->detach();
    }

    if (!$breeding_program_id){
        $c->stash->{rest} = {error=>'A seedlot must have a breeding program.'};
        $c->detach();
    }

    my $operator;
    if ($c->user) {
        $operator = $c->user->get_object->get_username;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    print STDERR "Creating new Seedlot $seedlot_uniquename\n";
    my $seedlot_id;

    eval {
        my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
        $sl->uniquename($seedlot_uniquename);
        $sl->location_code($location_code);
        $sl->box_name($box_name);
        $sl->accession_stock_id($accession_id);
        $sl->cross_stock_id($cross_id);
        $sl->organization_name($organization);
        $sl->population_name($population_name);
        $sl->breeding_program_id($breeding_program_id);
        my $return = $sl->store();
        my $seedlot_id = $return->{seedlot_id};

        my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
        $transaction->factor(1);
        $transaction->from_stock([$from_stock_id, $from_stock_uniquename]);
        $transaction->to_stock([$seedlot_id, $seedlot_uniquename]);
        if ($amount){
            $transaction->amount($amount);
        }
        if ($weight){
            $transaction->weight_gram($weight);
        }
        $transaction->timestamp($timestamp);
        $transaction->description($description);
        $transaction->operator($operator);
        $transaction->store();

        my $sl_new = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$seedlot_id);
        $sl_new->set_current_count_property();
        $sl_new->set_current_weight_property();

        $phenome_schema->resultset("StockOwner")->find_or_create({
            stock_id     => $seedlot_id,
            sp_person_id =>  $user_id,
        });
    };

    if ($@) {
	$c->stash->{rest} = { success => 0, seedlot_id => 0, error => $@ };
	print STDERR "An error condition occurred, was not able to create seedlot. ($@).\n";
	return;
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1, seedlot_id => $seedlot_id };
}


sub upload_seedlots : Path('/ajax/breeders/seedlot-upload/') : ActionClass('REST') { }

sub upload_seedlots_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlots!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlots!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $breeding_program_id = $c->req->param("upload_seedlot_breeding_program_id");
    my $location = $c->req->param("upload_seedlot_location");
    my $population = $c->req->param("upload_seedlot_population_name");
    my $organization = $c->req->param("upload_seedlot_organization_name");
    my $upload_from_accessions = $c->req->upload('seedlot_uploaded_file');
    my $upload_harvested_from_crosses = $c->req->upload('seedlot_harvested_uploaded_file');
    if (!$upload_from_accessions && !$upload_harvested_from_crosses){
        $c->stash->{rest} = {error=>'You must upload a seedlot file!'};
        $c->detach();
    }
    my $upload;
    my $parser_type;
    if ($upload_from_accessions){
        $upload = $upload_from_accessions;
        $parser_type = 'SeedlotXLS';
    }
    if ($upload_harvested_from_crosses){
        $upload = $upload_harvested_from_crosses;
        $parser_type = 'SeedlotHarvestedXLS';
    }
    print STDERR "$parser_type \n";
    my $subdirectory = "seedlot_upload";
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
    my $parser = CXGN::Stock::Seedlot::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin($parser_type);
    my $parsed_data = $parser->parse();
    #print STDERR Dumper $parsed_data;

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_accessions => $parse_errors->{'missing_accessions'}, missing_crosses => $parse_errors->{'missing_crosses'}};
        $c->detach();
    }

    my @added_stocks;
    eval {
        while (my ($key, $val) = each(%$parsed_data)){
            my $sl;
            if (defined($val->{seedlot_id})){
                $sl = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$val->{seedlot_id}); #this allows update of existing seedlot
            } else {
                $sl = CXGN::Stock::Seedlot->new(schema => $schema);
            }
            $sl->uniquename($key);
            $sl->location_code($location);
            $sl->box_name($val->{box_name});
            $sl->accession_stock_id($val->{accession_stock_id});
            $sl->cross_stock_id($val->{cross_stock_id});
            $sl->organization_name($organization);
            $sl->population_name($population);
            $sl->breeding_program_id($breeding_program_id);
            $sl->check_name_exists(0); #already validated
            my $return = $sl->store();
            my $seedlot_id = $return->{seedlot_id};

            my $from_stock_id;
            my $from_stock_name;
            if ($val->{accession_stock_id}){
                $from_stock_id = $val->{accession_stock_id};
                $from_stock_name = $val->{accession};
            }
            elsif ($val->{cross_stock_id}){
                $from_stock_id = $val->{cross_stock_id};
                $from_stock_name = $val->{cross_name};
            }
            if (!$from_stock_id || !$from_stock_name){
                die "A source accession or source cross must be given to make a seedlot transaction.\n";
            }

            my $transaction_amount;
            my $transaction_weight;
            # If seedlot already exists in database, the system will update so that the current weight and current count match what was uploaded.
            if (defined($val->{seedlot_id})){
                my $sl = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $val->{seedlot_id});
                my $current_stored_count = $sl->get_current_count_property() && $sl->get_current_count_property() ne 'NA' ? $sl->get_current_count_property() : 0;
                my $current_stored_weight = $sl->get_current_weight_property() && $sl->get_current_weight_property() ne 'NA' ? $sl->get_current_weight_property() : 0;

                $val->{description} .= " Info: Seedlot XLS upload update.";

                if ($val->{weight_gram} ne 'NA'){
                    my $weight_difference = $val->{weight_gram} - $current_stored_weight;
                    my $weight_factor;
                    if ($weight_difference >= 0){
                        $weight_factor = 1;
                    } else {
                        $weight_factor = -1;
                        $weight_difference = $weight_difference * -1; #Store positive values only
                    }
                    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                    $transaction->from_stock([$seedlot_id, $key]);
                    $transaction->to_stock([$seedlot_id, $key]);
                    $transaction->weight_gram($weight_difference);
                    $transaction->timestamp($timestamp);
                    $transaction->description($val->{description});
                    $transaction->operator($val->{operator_name});
                    $transaction->factor($weight_factor);
                    $transaction->store();
                }

                if ($val->{amount} ne 'NA'){
                    my $amount_difference = $val->{amount} - $current_stored_count;
                    my $amount_factor;
                    if ($amount_difference >= 0){
                        $amount_factor = 1;
                    } else {
                        $amount_factor = -1;
                        $amount_difference = $amount_difference * -1; #Store positive values only
                    }
                    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                    $transaction->from_stock([$seedlot_id, $key]);
                    $transaction->to_stock([$seedlot_id, $key]);
                    $transaction->amount($amount_difference);
                    $transaction->timestamp($timestamp);
                    $transaction->description($val->{description});
                    $transaction->operator($val->{operator_name});
                    $transaction->factor($amount_factor);
                    $transaction->store();
                }
            }
            # If this is not updating an existing seedlot, then it just the initial transaction
            else {
                my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
                $transaction->factor(1);
                $transaction->from_stock([$from_stock_id, $from_stock_name]);
                $transaction->to_stock([$seedlot_id, $key]);
                $transaction->amount($val->{amount});
                $transaction->weight_gram($val->{weight_gram});
                $transaction->timestamp($timestamp);
                $transaction->description($val->{description});
                $transaction->operator($val->{operator_name});
                $transaction->store();
            }

            my $sl_new = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$seedlot_id);
            $sl_new->set_current_count_property();
            $sl_new->set_current_weight_property();
            push @added_stocks, $seedlot_id;
        }
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload seedlots. ($@).\n";
        $c->detach();
    }

    foreach my $stock_id (@added_stocks) {
        $phenome_schema->resultset("StockOwner")->find_or_create({
            stock_id     => $stock_id,
            sp_person_id =>  $user_id,
        });
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}

sub upload_seedlots_inventory : Path('/ajax/breeders/seedlot-inventory-upload/') : ActionClass('REST') { }
sub upload_seedlots_inventory_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlot inventory!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload seedlot inventory!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $upload = $c->req->upload('seedlot_uploaded_inventory_file');
    my $subdirectory = "seedlot_upload";
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
    my $parser = CXGN::Stock::Seedlot::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin('SeedlotInventoryCSV');
    my $parsed_data = $parser->parse();
    #print STDERR Dumper $parsed_data;

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_seedlots => $parse_errors->{'missing_seedlots'} };
        $c->detach();
    }

    eval {
        while (my ($key, $val) = each(%$parsed_data)){
            my $sl = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $val->{seedlot_id});
            $sl->box_name($val->{box_id});
            my $return = $sl->store();
            my $current_stored_count = $sl->get_current_count_property();
            my $current_stored_weight = $sl->get_current_weight_property();

            my $weight_difference = $val->{weight_gram} - $current_stored_weight;
            my $factor;
            if ($weight_difference >= 0){
                $factor = 1;
            } else {
                $factor = -1;
                $weight_difference = $weight_difference * -1; #Store positive values only
            }

            my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
            $transaction->factor($factor);
            $transaction->from_stock([$val->{seedlot_id}, $val->{seedlot_name}]);
            $transaction->to_stock([$val->{seedlot_id}, $val->{seedlot_name}]);
            $transaction->weight_gram($weight_difference);
            $transaction->timestamp($val->{inventory_date});
            $transaction->description('Seed inventory CSV upload.');
            $transaction->operator($val->{inventory_person});
            $transaction->store();

            my $sl_new = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $val->{seedlot_id});
            $sl_new->set_current_count_property();
            $sl_new->set_current_weight_property();
        }
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload seedlots inventory. ($@).\n";
        $c->detach();
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1 };
}



sub seedlot_transaction_base :Chained('seedlot_base') PathPart('transaction') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $transaction_id = shift;
    my $t_obj = CXGN::Stock::Seedlot::Transaction->new(schema=>$schema, transaction_id=>$transaction_id);
    $c->stash->{transaction_id} = $transaction_id;
    $c->stash->{transaction_object} = $t_obj;
}

sub seedlot_transaction_details :Chained('seedlot_transaction_base') PathPart('') Args(0) {
    my $self = shift;
    my $c = shift;
    my $t = $c->stash->{transaction_object};
    $c->stash->{rest} = {
        success => 1,
        transaction_id => $t->transaction_id,
        description=>$t->description,
        amount=>$t->amount,
        weight_gram=>$t->weight_gram,
        operator=>$t->operator,
        timestamp=>$t->timestamp
    };
}

sub edit_seedlot_transaction :Chained('seedlot_transaction_base') PathPart('edit') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in to edit seedlot transactions" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to edit seedlot transactions. Please contact us." };
        $c->detach();
    }

    my $t = $c->stash->{transaction_object};
    my $edit_operator = $c->req->param('operator');
    my $edit_amount = $c->req->param('amount');
    my $edit_weight = $c->req->param('weight_gram');
    my $edit_desc = $c->req->param('description');
    my $edit_timestamp = $c->req->param('timestamp');
    $t->operator($edit_operator);
    $t->amount($edit_amount);
    $t->weight_gram($edit_weight);
    $t->description($edit_desc);
    $t->timestamp($edit_timestamp);
    my $transaction_id = $t->store();
    $c->stash->{seedlot}->set_current_count_property();
    $c->stash->{seedlot}->set_current_weight_property();
    if ($transaction_id){
        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

        $c->stash->{rest} = { success => 1 };
    } else {
        $c->stash->{rest} = { error => "Something went wrong with the transaction update" };
    }
}

sub list_seedlot_transactions :Chained('seedlot_base') :PathPart('transactions') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $transactions = $c->stash->{seedlot}->transactions();
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "plot", "stock_type")->cvterm_id();
    my %types_hash = ( $type_id => 'seedlot', $accession_type_id => 'accession', $plot_type_id => 'plot', $cross_type_id => 'cross' );

    #print STDERR Dumper $transactions;
    my @transactions;
    foreach my $t (@$transactions) {
        my $value_field = '';
        if ($t->factor == 1 && $t->amount() ne 'NA'){
            $value_field = '<span style="color:green">+'.$t->factor()*$t->amount().'</span>';
        }
        if ($t->factor == -1 && $t->amount() ne 'NA'){
            $value_field = '<span style="color:red">'.$t->factor()*$t->amount().'</span>';
        }
        if ($t->amount() eq 'NA'){
            $value_field = $t->amount;
        }
        my $weight_value_field = '';
        if ($t->factor == 1 && $t->weight_gram() ne 'NA'){
            $weight_value_field = '<span style="color:green">+'.$t->factor()*$t->weight_gram().'</span>';
        }
        if ($t->factor == -1 && $t->weight_gram() ne 'NA'){
            $weight_value_field = '<span style="color:red">'.$t->factor()*$t->weight_gram().'</span>';
        }
        if ($t->weight_gram() eq 'NA'){
            $weight_value_field = $t->weight_gram;
        }
        my $from_url;
        my $to_url;
        if ($t->from_stock()->[2] == $type_id){
            $from_url = '<a href="/breeders/seedlot/'.$t->from_stock()->[0].'" >'.$t->from_stock()->[1].'</a> ('.$types_hash{$t->from_stock()->[2]}.')';
        } elsif ($t->from_stock()->[2] == $cross_type_id){
            $from_url = '<a href="/cross/'.$t->from_stock()->[0].'" >'.$t->from_stock()->[1].'</a> ('.$types_hash{$t->from_stock()->[2]}.')';
        } else {
            $from_url = '<a href="/stock/'.$t->from_stock()->[0].'/view" >'.$t->from_stock()->[1].'</a> ('.$types_hash{$t->from_stock()->[2]}.')';
        }
        if ($t->to_stock()->[2] == $type_id){
            $to_url = '<a href="/breeders/seedlot/'.$t->to_stock()->[0].'" >'.$t->to_stock()->[1].'</a> ('.$types_hash{$t->to_stock()->[2]}.')';
        } elsif ($t->from_stock()->[2] == $cross_type_id){
            $to_url = '<a href="/cross/'.$t->to_stock()->[0].'" >'.$t->to_stock()->[1].'</a> ('.$types_hash{$t->to_stock()->[2]}.')';
        } else {
            $to_url = '<a href="/stock/'.$t->to_stock()->[0].'/view" >'.$t->to_stock()->[1].'</a> ('.$types_hash{$t->to_stock()->[2]}.')';
        }
        push @transactions, { "transaction_id"=>$t->transaction_id(), "timestamp"=>$t->timestamp(), "from"=>$from_url, "to"=>$to_url, "value"=>$value_field, "weight"=>$weight_value_field, "operator"=>$t->operator, "description"=>$t->description() };
    }

    $c->stash->{rest} = { data => \@transactions };

}

sub add_seedlot_transaction :Chained('seedlot_base') :PathPart('transaction/add') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to add a seedlot transaction!'};
        $c->detach();
    }
    my $operator = $c->user->get_object->get_username;
    my $user_id = $c->user->get_object->get_sp_person_id;

    my $to_new_seedlot_name = $c->req->param('to_new_seedlot_name');
    my $stock_id;
    my $stock_uniquename;
    my $new_sl;
    if ($to_new_seedlot_name){
        $stock_uniquename = $to_new_seedlot_name;
        eval {
            my $location_code = $c->req->param('to_new_seedlot_location_name');
            my $box_name = $c->req->param('to_new_seedlot_box_name');
            my $accession_uniquename = $c->req->param('to_new_seedlot_accession_name');
            my $cross_uniquename = $c->req->param('to_new_seedlot_cross_name');
            my $organization = $c->req->param('to_new_seedlot_organization');
            my $population_name = $c->req->param('to_new_seedlot_population_name');
            my $breeding_program_id = $c->req->param('to_new_seedlot_breeding_program_id');
            my $amount = $c->req->param('to_new_seedlot_amount');
            my $weight = $c->req->param('to_new_seedlot_weight');
            my $timestamp = $c->req->param('to_new_seedlot_timestamp');
            my $description = $c->req->param('to_new_seedlot_description');

            my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
            my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
            my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

            my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$stock_uniquename, type_id=>$seedlot_cvterm_id});
            if ($previous_seedlot){
                $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
                $c->detach();
            }
            my $accession_id;
            if ($accession_uniquename){
                $accession_id = $schema->resultset('Stock::Stock')->find({uniquename=>$accession_uniquename, type_id=>$accession_cvterm_id})->stock_id();
            }
            my $cross_id;
            if ($cross_uniquename){
                $cross_id = $schema->resultset('Stock::Stock')->find({uniquename=>$cross_uniquename, type_id=>$cross_cvterm_id})->stock_id();
            }
            if ($accession_uniquename && !$accession_id){
                $c->stash->{rest} = {error=>'The given accession name is not in the database! Seedlots can only be added onto existing accessions.'};
                $c->detach();
            }
            if ($cross_uniquename && !$cross_id){
                $c->stash->{rest} = {error=>'The given cross name is not in the database! Seedlots can only be added onto existing crosses.'};
                $c->detach();
            }
            if ($accession_id && $cross_id){
                $c->stash->{rest} = {error=>'A seedlot must have either an accession OR a cross as contents. Not both.'};
                $c->detach();
            }
            if (!$accession_id && !$cross_id){
                $c->stash->{rest} = {error=>'A seedlot must have either an accession or a cross as contents.'};
                $c->detach();
            }

            my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
            $sl->uniquename($to_new_seedlot_name);
            $sl->location_code($location_code);
            $sl->box_name($box_name);
            $sl->accession_stock_id($accession_id);
            $sl->cross_stock_id($cross_id);
            $sl->organization_name($organization);
            $sl->population_name($population_name);
            $sl->breeding_program_id($breeding_program_id);
            #TO DO
            #$sl->cross_id($cross_id);
            my $return = $sl->store();
            my $seedlot_id = $return->{seedlot_id};
            $stock_id = $seedlot_id;

            my $from_stock_name = $accession_uniquename ? $accession_uniquename : $cross_uniquename;
            my $from_stock_id = $accession_id ? $accession_id : $cross_id;
            my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
            $transaction->factor(1);
            $transaction->from_stock([$from_stock_id, $from_stock_name]);
            $transaction->to_stock([$seedlot_id, $to_new_seedlot_name]);
            $transaction->amount($amount);
            $transaction->weight_gram($weight);
            $transaction->timestamp($timestamp);
            $transaction->description($description);
            $transaction->operator($operator);
            $transaction->store();

            my $sl_new = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id=>$seedlot_id);
            $new_sl = $sl_new;

            $phenome_schema->resultset("StockOwner")->find_or_create({
                stock_id     => $seedlot_id,
                sp_person_id =>  $user_id,
            });
        };

        if ($@) {
            $c->stash->{rest} = { success => 0, seedlot_id => 0, error => $@ };
            print STDERR "An error condition occurred, was not able to create new seedlot. ($@).\n";
            $c->detach();
        }
    }
    my $existing_sl;
    my $from_existing_seedlot_id = $c->req->param('from_existing_seedlot_id');
    if ($from_existing_seedlot_id){
        $stock_id = $from_existing_seedlot_id;
        $stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$stock_id})->uniquename();
        $existing_sl = CXGN::Stock::Seedlot->new(
            schema => $c->stash->{schema},
            seedlot_id => $stock_id,
        );
    }
    my $to_existing_seedlot_id = $c->req->param('to_existing_seedlot_id');
    if ($to_existing_seedlot_id){
        $stock_id = $to_existing_seedlot_id;
        $stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$stock_id})->uniquename();
        $existing_sl = CXGN::Stock::Seedlot->new(
            schema => $c->stash->{schema},
            seedlot_id => $stock_id,
        );
    }

    my $amount = $c->req->param("amount");
    my $weight = $c->req->param("weight");
    my $timestamp = $c->req->param("timestamp");
    my $description = $c->req->param("description");
    my $factor = $c->req->param("factor");
    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $c->stash->{schema});
    $transaction->factor($factor);
    if ($factor == 1){
        $transaction->from_stock([$stock_id, $stock_uniquename]);
        $transaction->to_stock([$c->stash->{seedlot_id}, $c->stash->{uniquename}]);
    } elsif ($factor == -1){
        $transaction->to_stock([$stock_id, $stock_uniquename]);
        $transaction->from_stock([$c->stash->{seedlot_id}, $c->stash->{uniquename}]);
    } else {
        die "factor not specified!\n";
    }
    $transaction->amount($amount);
    $transaction->weight_gram($weight);
    $transaction->timestamp($timestamp);
    $transaction->description($description);
    $transaction->operator($c->user->get_object->get_username);
    my $transaction_id = $transaction->store();

    if ($new_sl){
        $new_sl->set_current_count_property();
        $new_sl->set_current_weight_property();
    }
    if ($existing_sl){
        $existing_sl->set_current_count_property();
        $existing_sl->set_current_weight_property();
    }
    $c->stash->{seedlot}->set_current_count_property();
    $c->stash->{seedlot}->set_current_weight_property();

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1, transaction_id => $transaction_id };
}

1;

no Moose;
__PACKAGE__->meta->make_immutable;
