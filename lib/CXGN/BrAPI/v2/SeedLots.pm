package CXGN::BrAPI::v2::SeedLots;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $params = shift;
	my $c = shift;
    my $status = $self->status;
    my $phenome_schema = $self->phenome_schema();
    my $people_schema = $self->people_schema();

    my $seedlot_name = $params->{seedLotName} || '';
    my $seedlot_id = $params->{seedLotDbId}->[0] || '';
    my $breeding_program = $params->{breeding_program} || '';
    my $location = $params->{location} || '';
    my $minimum_count = $params->{minimum_count} || '';
    my $minimum_weight = $params->{minimum_weight} || '';
    my $accession_id = $params->{germplasmDbId} || '';
    my $accession_name = $params->{germplasmName} || '';
    my $cross = $params->{cross} || '';   

    my $reference_ids_arrayref = $params->{externalReferenceID} || ();
    my $reference_sources_arrayref = $params->{externalReferenceSource} || ();

    if (($reference_ids_arrayref && scalar(@$reference_ids_arrayref)>0) || ($reference_sources_arrayref && scalar(@$reference_sources_arrayref)>0) ){
        push @$status, { 'error' => 'The following search parameters are not implemented: externalReferenceID, externalReferenceSources' };
    }

	my $page_size = $self->page_size;
	my $page = $self->page;
    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;
	my @data;

    my ($list, $records_total) = CXGN::Stock::Seedlot->list_seedlots(
        $self->bcs_schema,
        $people_schema,
        $phenome_schema,
        $offset,
        $limit,
        $seedlot_name,
        $breeding_program,
        $location,
        $minimum_count,
        $accession_name,
        $cross,
        1,
        $minimum_weight,
        $seedlot_id,
        $accession_id
    );

    foreach (@$list){
        push @data, {
            additionalInfo=>{},
            amount=>$_->{current_count},
            createdDate=>undef,
            externalReferences=>[],
            germplasmDbId=>qq|$_->{source_stocks}->[0][0]|,
            lastUpdated=>undef,
            locationDbId=>qq|$_->{location_id}|,
            programDbId=>qq|$_->{breeding_program_id}|,
            seedLotDbId=>qq|$_->{seedlot_stock_id}|,
            seedLotDescription=>$_->{seedlot_stock_description},
            seedLotName=>$_->{seedlot_stock_uniquename},
            sourceCollection=>undef,
            storageLocation=>$_->{location},
            units=>'seeds',
        };
    }
	my %result = (data=>\@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($records_total,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Seed lots result constructed');
}

sub detail {
    my $self = shift;
    my $seedlot_id = shift;
    
    my $schema = $self->bcs_schema;
    my $phenome_schema = $self->phenome_schema();
    my $page_size = $self->page_size;
    my $status = $self->status;
    my $page = $self->page;
    my %result;
    my $count = 0;
    my $seedlot;

    eval { $seedlot = CXGN::Stock::Seedlot->new(
        schema => $schema,
        phenome_schema => $phenome_schema,
        seedlot_id => $seedlot_id,
    );};

    if ($seedlot){
        my $accession = $seedlot->accession()->[0];
        my $location = $seedlot->nd_geolocation_id();
        my $program = $seedlot->breeding_program_id();


        %result = (
                additionalInfo=>{},
                amount=>$seedlot->current_count(),
                createdDate=>undef,
                externalReferences=>[],
                germplasmDbId=>qq|$accession|,
                lastUpdated=>undef,
                locationDbId=>qq|$location|,
                programDbId=>qq|$program|,
                seedLotDbId=>qq|$seedlot_id|,
                seedLotDescription=>$seedlot->description(),
                seedLotName=>$seedlot->uniquename(),
                sourceCollection=>undef,
                storageLocation=>$seedlot->location_code(),
                units=>'seeds',
        );
        $count++;
    }

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Seed lots result constructed');
}

sub all_transactions {
    my $self = shift;
    my $params = shift;
    my $c = shift;

    my $status = $self->status;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $schema = $self->bcs_schema;
    my @data;

    my $transaction_id = $params->{transactionDbId}->[0];
    my $seedlot_id = $params->{seedLotDbId};
    my $germplasm_id = $params->{germplasmDbId}->[0];

    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;

    my ($transactions, $records_total) = CXGN::Stock::Seedlot::Transaction->get_transactions($schema, $seedlot_id->[0], $transaction_id, $germplasm_id, $limit, $offset);

    foreach my $t (@$transactions) {
        my $from = $t->from_stock->[0];
        my $to = $t->to_stock->[0];
        my $id = $t->transaction_id;    
        my $timestamp = format_date($t->timestamp);
        push @data , {
            additionalInfo=>{},
            amount=>$t->amount,
            externalReferences=>[],
            fromSeedLotDbId=>qq|$from|,
            toSeedLotDbId=>qq|$to|,
            transactionDbId=>qq|$id|,
            transactionDescription=>$t->description,
            transactionTimestamp=>$timestamp,
            units=>"seeds",
        };
    }

    my @data_files;
    my %result = (data=>\@data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($records_total,$page_size,$page);

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Transactions result constructed');

}

sub transactions {
    my $self = shift;
    my $seedlot_id = shift;
    my $params = shift;

    my $transaction_id = $params->{transactionDbId}->[0];
    my $direction = $params->{transactionDirection}->[0];

    my $status = $self->status;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
    my $counter = 0;
    my $schema = $self->bcs_schema;
    my $phenome_schema = $self->phenome_schema();
    my @data;

    my $seedlot = CXGN::Stock::Seedlot->new(
        schema => $schema,
        phenome_schema => $phenome_schema,
        seedlot_id => $seedlot_id,
    );

    my $transactions = $seedlot->transactions();

    foreach my $t (@$transactions) {
        my $id = $t->transaction_id();
        if ((!$transaction_id && $counter >= $start_index && $counter <= $end_index) || ($transaction_id eq $id) )  {
            my $from = $t->from_stock()->[0];
            my $to = $t->to_stock()->[0];
            my $timestamp = format_date($t->timestamp());
            push @data , {
                additionalInfo=>{},
                amount=>$t->amount(),
                externalReferences=>[],
                fromSeedLotDbId=>qq|$from|,
                toSeedLotDbId=>qq|$to|,
                transactionDbId=>qq|$id|,
                transactionDescription=>$t->description(),
                transactionTimestamp=>$timestamp,
                units=>"seeds",
            };
        }
        $counter++;
    }
    my @data_files;
    my %result = (data=>\@data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Transactions result constructed');
}

sub store_seedlots {
    my $self = shift;
    my $params = shift;
    my $c = shift;
    my $user_id = shift;

    if (!$user_id){
        $c->stash->{rest} = {error=>'You must be logged in to add a seedlot!'};
        $c->detach();
    }

    my $page_size = $self->page_size;
    my $status = $self->status;
    my $page = $self->page;

    my $schema = $self->bcs_schema;
    my $phenome_schema = $self->phenome_schema();
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $seedlot_uniquename = $params->{seedLotName} ? $params->{seedLotName}[0] : undef;
    my $location_id = $params->{locationDbId} ? $params->{locationDbId}[0] : undef;
    my $box_name = $params->{additionalInfo} ? $params->{additionalInfo}[0] : undef;
    my $source_collection = $params->{sourceCollection} ? $params->{sourceCollection}[0] : undef;
    my $accession_id = $params->{germplasmDbId} ? $params->{germplasmDbId}[0] : undef;
    my $cross_uniquename = $params->{crossName} ? $params->{crossName}[0] : undef;
    my $organization = $params->{organization} ? $params->{organization}[0] : undef;
    my $amount = $params->{amount} ? $params->{amount}[0] : undef;
    my $weight = $params->{weight} ? $params->{weight}[0] : undef;
    my $timestamp = $params->{lastUpdated} ? $params->{lastUpdated}[0] : undef;
    my $description = $params->{seedLotDescription} ? $params->{seedLotDescription}[0] : undef;
    my $breeding_program_id = $params->{programDbId} ? $params->{programDbId}[0] : undef;

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_uniquename, type_id=>$seedlot_cvterm_id});
    if ($previous_seedlot){
        $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
        $c->detach();
    }
    my $accession_uniquename;

    if ($accession_id){
        my $accession = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$accession_id});
        if (!$accession) {
            $c->stash->{rest} = {error=>'GermplasmDbId does not exist in the database'};
            $c->detach();
        }
        $accession_uniquename =  $accession->name();
    }
    if (!$accession_id || !$accession_uniquename ){
        $c->stash->{rest} = {error=>'A seedlot must have a valid accession.'};
        $c->detach();
    }

    my $from_stock_id = $accession_id;
    my $from_stock_uniquename = $accession_uniquename;
    
    if (!$weight && !$amount){
        $c->stash->{rest} = {error=>'A seedlot must have either a weight or an amount.'};
        $c->detach();
    }

    if (!$timestamp){
        $c->stash->{rest} = {error=>'A seedlot must have a timestamp for the transaction.'};
        $c->detach();
    } 
    my $timestamp_format = check_timestamp($timestamp);
    if (!$timestamp_format){
        $c->stash->{rest} = {error=>'A seedlot must have a proper timestamp for the transaction.'};
        $c->detach();
    }
    if (!$breeding_program_id){
        $c->stash->{rest} = {error=>'A seedlot must have a breeding program.'};
        $c->detach();
    }
    my $location_code;
    if ($location_id){
        my $locations = CXGN::Trial::get_all_locations($schema, $location_id);
        $location_code = $locations->[0]->[1];

        if (!$location_code){
            $c->stash->{rest} = {error=>'LocationDbId does not exist in the database'};
            $c->detach();
        }
    }
    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $operator = $person->get_username;

    print STDERR "Creating new Seedlot $seedlot_uniquename\n";
    my $seedlot_id;

    eval {
        my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
        $sl->uniquename($seedlot_uniquename);
        $sl->location_code($location_code);
        $sl->box_name($box_name);
        $sl->accession_stock_id($accession_id);
        $sl->organization_name($organization);
        $sl->breeding_program_id($breeding_program_id);
        $sl->description($description);
        my $return = $sl->store();
        $seedlot_id = $return->{seedlot_id};

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

    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1, seedlot_id => $seedlot_id };

    my $seedlot;
    my %result;
    my $count;
    eval { $seedlot = CXGN::Stock::Seedlot->new(
        schema => $schema,
        phenome_schema => $phenome_schema,
        seedlot_id => $seedlot_id,
    );};

    if ($seedlot){
        my $accession = $seedlot->accession()->[0];
        my $location = $seedlot->nd_geolocation_id();
        my $program = $seedlot->breeding_program_id();


        %result = (
                additionalInfo=>{},
                amount=>$seedlot->current_count(),
                createdDate=>undef,
                externalReferences=>[],
                germplasmDbId=>qq|$accession|,
                lastUpdated=>undef,
                locationDbId=>qq|$location|,
                programDbId=>qq|$program|,
                seedLotDbId=>qq|$seedlot_id|,
                seedLotDescription=>$seedlot->description(),
                seedLotName=>$seedlot->uniquename(),
                sourceCollection=>undef,
                storageLocation=>$seedlot->location_code(),
                units=>'seeds',
        );
        $count++;
    }

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Seed lots result constructed');

}

sub store_seedlot_transaction {
    my $self = shift;
    my $params = shift;
    my $c = shift;
    my $user_id = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $schema = $self->bcs_schema;
    my $phenome_schema = $self->phenome_schema();
    my $dbh = $self->bcs_schema()->storage()->dbh();

    if (!$user_id){
        $c->stash->{rest} = {error=>'You must be logged in to add a seedlot transaction!'};
        $c->detach();
    }

    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $operator = $person->get_username;

    my $from_stock_uniquename;
    my $to_stock_uniquename;
    my $to_existing_sl;
    my $from_existing_sl;

    my $amount = $params->{amount}->[0] || undef;
    my $weight = $params->{weight}->[0] || undef;
    my $timestamp = $params->{transactionTimestamp}->[0] || undef;
    my $description = $params->{transactionDescription}[0] || undef;
    my $from_stock_id = $params->{fromSeedLotDbId}->[0] || undef;
    my $to_stock_id = $params->{toSeedLotDbId}->[0] || undef;
    my $additionalInfo = $params->{additionalInfo} || undef; #not implemented
    my $externalReferences = $params->{externalReferences} || undef; #not implemented
    my $units = $params->{units} || undef; #not implemented
    my $factor = '-1';

    if ($from_stock_id){
        $from_stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$from_stock_id})->uniquename();
        if (!$from_stock_uniquename){
            $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
            $c->detach();
        }
        $from_existing_sl = CXGN::Stock::Seedlot->new(
            schema => $schema,
            seedlot_id => $from_stock_id,
        );
    }
    
    if ($to_stock_id){
        $to_stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$to_stock_id})->uniquename();
        if (!$to_stock_uniquename){
            $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
            $c->detach();
        }
        $to_existing_sl = CXGN::Stock::Seedlot->new(
            schema => $schema,
            seedlot_id => $to_stock_id,
        );
    }
    if (!$weight && !$amount){
        $c->stash->{rest} = {error=>'A seedlot must have either a weight or an amount.'};
        $c->detach();
    }
    my $timestamp_format = check_timestamp($timestamp);
    if (!$timestamp_format){
        $c->stash->{rest} = {error=>'A seedlot must have a proper timestamp for the transaction.'};
        $c->detach();
    }

    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
    $transaction->factor($factor);
    $transaction->to_stock([$to_stock_id, $to_stock_uniquename]);
    $transaction->from_stock([$from_stock_id, $from_stock_uniquename]);
    $transaction->amount($amount);
    $transaction->weight_gram($weight) if ($weight);
    $transaction->timestamp($timestamp);
    $transaction->description($description);
    $transaction->operator($operator);
    my $transaction_id = $transaction->store();

    if ($from_existing_sl){
        $from_existing_sl->set_current_count_property();
        $from_existing_sl->set_current_weight_property() if ($weight);
    }
    if ($to_existing_sl){
        $to_existing_sl->set_current_count_property();
        $to_existing_sl->set_current_weight_property() if ($weight);
    }

    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = { success => 1, transaction_id => $transaction_id };

    my $seedlot = CXGN::Stock::Seedlot->new(
        schema => $schema,
        phenome_schema => $phenome_schema,
        seedlot_id => $to_stock_id,
    );

    my $transactions = $seedlot->transactions();
    my $counter;
    my @data;

    foreach my $t (@$transactions) {
        my $id = $t->transaction_id();
        if ($transaction_id eq $id) {
            my $from = $t->from_stock()->[0];
            my $to = $t->to_stock()->[0];
            my $timestamp = format_date($t->timestamp());
            push @data , {
                additionalInfo=>{},
                amount=>$t->amount(),
                externalReferences=>[],
                fromSeedLotDbId=>qq|$from|,
                toSeedLotDbId=>qq|$to|,
                transactionDbId=>qq|$id|,
                transactionDescription=>$t->description(),
                transactionTimestamp=>$timestamp,
                units=>"seeds",
            };
            $counter++;
        }
    }
    my @data_files;
    my %result = (data=>\@data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Transactions result constructed');
}

sub update_seedlot {
    my $self = shift;
    my $seedlot_id = shift;
    my $params = shift;
    my $c = shift;
    my $user_id = shift;

    if (!$user_id){
        $c->stash->{rest} = {error=>'You must be logged in to add a seedlot!'};
        $c->detach();
    }

    my $schema = $self->bcs_schema;
    my $phenome_schema = $self->phenome_schema();
    my $page_size = $self->page_size;
    my $status = $self->status;
    my $page = $self->page;

    my $seedlot = CXGN::Stock::Seedlot->new(
        schema => $schema,
        phenome_schema => $phenome_schema,
        seedlot_id => $seedlot_id,
    );

    my $saved_seedlot_name = $seedlot->uniquename;
    my $seedlot_name = $params->{seedLotName} ? $params->{seedLotName}[0] : undef;
    my $location_id = $params->{locationDbId} ? $params->{locationDbId}[0] : undef;
    my $box_name = $params->{additionalInfo} ? $params->{additionalInfo}[0] : undef;
    my $source_collection = $params->{sourceCollection} ? $params->{sourceCollection}[0] : undef; # not implemented
    my $accession_id = $params->{germplasmDbId} ? $params->{germplasmDbId}[0] : undef;
    my $organization = $params->{organization} ? $params->{organization}[0] : undef;
    my $amount = $params->{amount} ? $params->{amount}[0] : undef; # not implemented
    my $weight = $params->{weight} ? $params->{weight}[0] : undef; # not implemented
    my $timestamp = $params->{lastUpdated} ? $params->{lastUpdated}[0] : undef; # not implemented
    my $description = $params->{seedLotDescription} ? $params->{seedLotDescription}[0] : undef;
    my $breeding_program_id = $params->{programDbId} ? $params->{programDbId}[0] : undef;
    my $accession_uniquename;

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    if ($saved_seedlot_name ne $seedlot_name){
        my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_name, type_id=>$seedlot_cvterm_id});
        if ($previous_seedlot){
            $c->stash->{rest} = {error=>'The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'};
            $c->detach();
        }
    }
    if ($accession_id){
        my $accession = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$accession_id});
        if (!$accession) {
            $c->stash->{rest} = {error=>'GermplasmDbId does not exist in the database'};
            $c->detach();
        }
        $accession_uniquename =  $accession->name();
    }
    if (!$accession_id || !$accession_uniquename ){
        $c->stash->{rest} = {error=>'A seedlot must have a valid accession.'};
        $c->detach();
    }
    if (!$breeding_program_id){
        $c->stash->{rest} = {error=>'A seedlot must have a breeding program.'};
        $c->detach();
    }
    my $location_code;
    if ($location_id){
        my $locations = CXGN::Trial::get_all_locations($schema, $location_id);
        $location_code = $locations->[0]->[1];

        if (!$location_code){
            $c->stash->{rest} = {error=>'LocationDbId does not exist in the database'};
            $c->detach();
        }
    }

    $seedlot->name($seedlot_name);
    $seedlot->uniquename($seedlot_name);
    $seedlot->breeding_program_id($breeding_program_id);
    $seedlot->organization_name($organization);
    $seedlot->location_code($location_code);
    $seedlot->box_name($box_name);
    $seedlot->accession_stock_id($accession_id);
    $seedlot->description($description);

    my $return = $seedlot->store();
    if (exists($return->{error})){
        $c->stash->{rest} = { error => $return->{error} };
    } else {
        $c->stash->{rest} = { success => 1 };
    }
    $phenome_schema->resultset("StockOwner")->find_or_create({
            stock_id     => $seedlot_id,
            sp_person_id =>  $user_id,
    });
    my $seedlot_r;
    my %result;
    my $count;
    eval { $seedlot_r = CXGN::Stock::Seedlot->new(
        schema => $schema,
        phenome_schema => $phenome_schema,
        seedlot_id => $seedlot_id,
    );};

    if ($seedlot_r){
        my $accession = $seedlot_r->accession()->[0];
        my $location = $seedlot_r->nd_geolocation_id();
        my $program = $seedlot_r->breeding_program_id();


        %result = (
                additionalInfo=>{},
                amount=>$seedlot_r->current_count(),
                createdDate=>undef,
                externalReferences=>[],
                germplasmDbId=>qq|$accession|,
                lastUpdated=>undef,
                locationDbId=>qq|$location|,
                programDbId=>qq|$program|,
                seedLotDbId=>qq|$seedlot_id|,
                seedLotDescription=>$seedlot_r->description(),
                seedLotName=>$seedlot_r->uniquename(),
                sourceCollection=>undef,
                storageLocation=>$seedlot_r->location_code(),
                units=>'seeds',
        );
        $count++;
    }

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Seed lots result constructed');
}

sub format_date {

    my $str_date = shift;
    my $date;

    if ($str_date =~ /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s(Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s(\d{2})\s(\d\d:\d\d:\d\d)\s(\d{4})$/) {
        my  $formatted_time = Time::Piece->strptime($str_date, '%a %b %d %H:%M:%S %Y');
        $date =  $formatted_time->strftime("%Y-%m-%dT%H:%M:%S%z");
    }
    else { $date = $str_date;}

    return $date;
}

sub check_timestamp {
    my $str_date = shift;
    my $ok;

    if ($str_date =~ /^(\d{4})-(\d{2})-(\d{2})T(\d\d:\d\d:\d\d)\D(\d{4})$/) {
        $ok = 1;
    }
    return $ok;
}

1;
