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
    my $seedlot_description = $params->{seedLotDescription} || '';
    my $seedlot_id = $params->{seedLotDbId} || '';
    my $breeding_program = $params->{breeding_program} || '';
    my $location = $params->{location} || '';
    my $minimum_count = $params->{minimum_count} || '';
    my $minimum_weight = $params->{minimum_weight} || '';
    my $accession_id = $params->{germplasmDbId} || '';
    my $accession_name = $params->{germplasmName} || '';
    my $cross_id = $params->{crossDbId} || '';
    my $cross_name = $params->{crossName} || '';

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
        $seedlot_description,
        $breeding_program,
        $location,
        $minimum_count,
        $accession_name,
        $cross_name,
        1,
        $minimum_weight,
        $seedlot_id,
        $accession_id,
        undef,
        undef,
        undef,
        $cross_id,
    );

    foreach (@$list){
        my $accession_id;
        my $cross_id;
        my $accession_name;
        my $cross_name;

        if ($_->{source_stocks}->[0][2] eq 'accession'){
            $accession_id = $_->{source_stocks}->[0][0];
            $accession_name = $_->{source_stocks}->[0][1];
        } else {
            $cross_id = $_->{source_stocks}->[0][0];
            $cross_name = $_->{source_stocks}->[0][1];
        }

        push @data, {
            additionalInfo=>{},
            amount=>$_->{current_count},
            contentMixture => [{
                crossDbId=>$cross_id ? qq|$cross_id| : undef,
                crossName=>$cross_name,
                germplasmDbId =>$accession_id ? qq|$accession_id| : undef,
                germplasmName => $accession_name,
                mixturePercentage=> 100 #since are passing 1 germplasm
            }],
            createdDate=>undef,
            externalReferences=>[],
            lastUpdated=>undef,
            locationDbId=>qq|$_->{location_id}|,
            locationName=>$_->{location},
            programDbId=>qq|$_->{breeding_program_id}|,
            programName=>$_->{breeding_program_name},
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
        my $accession_id = $seedlot->accession() ? $seedlot->accession()->[0] : undef;
        my $accession_name = $seedlot->accession() ? $seedlot->accession()->[1] : undef;
        my $location_id = $seedlot->nd_geolocation_id();
        my $location_name = $seedlot->location_code();
        my $program_id = $seedlot->breeding_program_id();
        my $program_name = $seedlot->breeding_program_name();
        my $cross_id = $seedlot->cross() ? qq|$seedlot->cross()->[0]| : undef;
        my $cross_name = $seedlot->cross() ? qq|$seedlot->cross()->[1]| : undef;

        %result = (
                additionalInfo=>{},
                amount=>$seedlot->current_count(),
                contentMixture => [{
                    crossDbId=>$cross_id,
                    crossName=>$cross_name,
                    germplasmDbId =>qq|$accession_id|,
                    germplasmName => $accession_name,
                    mixturePercentage=> 100 #since are passing 1 germplasm
                }],
                createdDate=>undef,
                externalReferences=>[],
                lastUpdated=>undef,
                locationDbId=>qq|$location_id|,
                locationName=>$location_name,
                programDbId=>qq|$program_id|,
                programName=>$program_name,
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
    my $data = shift;
    my $c = shift;
    my $user_id = shift;

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
    }

    my $page_size = $self->page_size;
    my $status = $self->status;
    my $page = $self->page;

    my $schema = $self->bcs_schema;
    my $phenome_schema = $self->phenome_schema();
    my $people_schema = $self->people_schema();
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $seedlot_ids;

    foreach my $params (@$data){
        my $seedlot_uniquename = $params->{seedLotName} ? $params->{seedLotName} : undef;
        my $location_id = $params->{locationDbId} ? $params->{locationDbId} : undef;
        my $box_name = $params->{additionalInfo}->{boxName} ? $params->{additionalInfo}->{boxName} : undef;
        my $source_collection = $params->{sourceCollection} ? $params->{sourceCollection} : undef;
        my $accession_id = $params->{germplasmDbId} ? $params->{germplasmDbId} : undef;
        my $cross_id = $params->{crossDbId} ? $params->{crossDbId} : undef;
        my $organization = $params->{organization} ? $params->{organization} : undef;
        my $amount = $params->{amount} ? $params->{amount} : undef;
        my $weight = $params->{weight} ? $params->{weight} : undef;
        my $timestamp = $params->{lastUpdated} ? $params->{lastUpdated} : undef;
        my $description = $params->{seedLotDescription} ? $params->{seedLotDescription} : undef;
        my $breeding_program_id = $params->{programDbId} ? $params->{programDbId} : undef;

        my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
        my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

        my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_uniquename, type_id=>$seedlot_cvterm_id});
        if ($previous_seedlot){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'));
        }
        my $accession_uniquename;

        if ($accession_id){
            my $accession = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$accession_id});
            if (!$accession) {
                return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('GermplasmDbId does not exist in the database'));
            }
            $accession_uniquename =  $accession->name();
        }
        if ($accession_id && !$accession_uniquename ){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have a valid accession.'));
        }
        my $cross_uniquename;
        if ($cross_id){
            $cross_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$cross_id, type_id=>$cross_cvterm_id})->stock_id();
        }
        if ($cross_id && !$cross_uniquename ){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have a valid cross id.'));
        }

        if ($accession_id && $cross_id){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have either an accession OR a cross as contents. Not both.'));
        }
        if (!$accession_id && !$cross_id){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have either an accession or a cross as contents.'));
        }

        my $from_stock_id = $accession_id ? $accession_id : $cross_id;
        my $from_stock_uniquename = $accession_uniquename ? $accession_uniquename : $cross_uniquename;

        if (!$weight && !$amount){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have either a weight or an amount.'));
        }

        if (!$timestamp){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have a timestamp for the transaction.'));
        }
        my $timestamp_format = check_timestamp($timestamp);
        if (!$timestamp_format){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have a formatted timestamp for the transaction.'));
        }

        if (!$breeding_program_id){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have a breeding program.'));
        }

        my $location_code;
        if ($location_id){
            my $locations = CXGN::Trial::get_all_locations($schema, $location_id);
            $location_code = $locations->[0]->[1];

            if (!$location_code){
                return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Provided locationDbId does not exist in the database.'));
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
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('An error condition occurred, was not able to create seedlot.'));
        }
        push @$seedlot_ids, $seedlot_id;
    }
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    my $seedlot;
    my %result;
    my @data;
    my $count=0;

    my ($list, $records_total) = CXGN::Stock::Seedlot->list_seedlots(
        $self->bcs_schema,
        $people_schema,
        $phenome_schema,
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        1,
        '',
        $seedlot_ids,
        '',
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
        $count++;
    }
    %result = (data=>\@data);

    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Seed lots stored');

}

sub store_seedlot_transaction {
    my $self = shift;
    my $data = shift;
    my $c = shift;
    my $user_id = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $schema = $self->bcs_schema;
    my $phenome_schema = $self->phenome_schema();
    my $dbh = $self->bcs_schema()->storage()->dbh();

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
    }

    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $operator = $person->get_username;

    my $from_stock_uniquename;
    my $to_stock_uniquename;
    my $to_existing_sl;
    my $from_existing_sl;
    my $to_stock_id;
    my $transaction_id;

    foreach my $params (@$data){
        my $amount = $params->{amount} || undef;
        my $weight = $params->{weight} || undef;
        my $timestamp = $params->{transactionTimestamp} || undef;
        my $description = $params->{transactionDescription} || undef;
        my $from_stock_id = $params->{fromSeedLotDbId} || undef;
        $to_stock_id = $params->{toSeedLotDbId} || undef;
        my $additionalInfo = $params->{additionalInfo} || undef; #not implemented
        my $externalReferences = $params->{externalReferences} || undef; #not implemented
        my $units = $params->{units} || undef; #not implemented
        my $factor = '-1';

        if ($from_stock_id){
            $from_stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$from_stock_id})->uniquename();
            if (!$from_stock_uniquename){
                return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'));
            }
            $from_existing_sl = CXGN::Stock::Seedlot->new(
                schema => $schema,
                seedlot_id => $from_stock_id,
            );
        }

        if ($to_stock_id){
            $to_stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$to_stock_id})->uniquename();
            if (!$to_stock_uniquename){
                return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'));
            }
            $to_existing_sl = CXGN::Stock::Seedlot->new(
                schema => $schema,
                seedlot_id => $to_stock_id,
            );
        }
        if (!$weight && !$amount){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have either a weight or an amount.'));
        }
        my $timestamp_format = check_timestamp($timestamp);
        if (!$timestamp_format){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have a formatted timestamp for the transaction.'));
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
        $transaction_id = $transaction->store();

        if ($from_existing_sl){
            $from_existing_sl->set_current_count_property();
            $from_existing_sl->set_current_weight_property() if ($weight);
        }
        if ($to_existing_sl){
            $to_existing_sl->set_current_count_property();
            $to_existing_sl->set_current_weight_property() if ($weight);
        }
        $c->stash->{rest} = { success => 1, transaction_id => $transaction_id };
    }

    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

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

    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Transactions stored');
}

sub update_seedlot {
    my $self = shift;
    my $seedlot_id = shift;
    my $params = shift;
    my $c = shift;
    my $user_id = shift;

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
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
    my $seedlot_name = $params->{seedLotName} ? $params->{seedLotName} : undef;
    my $location_id = $params->{locationDbId} ? $params->{locationDbId} : undef;
    my $box_name = $params->{additionalInfo}->{boxName} ? $params->{additionalInfo}->{boxName} : undef;
    my $source_collection = $params->{sourceCollection} ? $params->{sourceCollection} : undef; # not implemented
    my $accession_id = $params->{germplasmDbId} ? $params->{germplasmDbId} : undef;
    my $cross_id = $params->{crossDbId} ? $params->{crossDbId} : undef;
    my $organization = $params->{organization} ? $params->{organization} : undef;
    my $amount = $params->{amount} ? $params->{amount} : undef; # not implemented
    my $weight = $params->{weight} ? $params->{weight} : undef; # not implemented
    my $timestamp = $params->{lastUpdated} ? $params->{lastUpdated} : undef; # not implemented
    my $description = $params->{seedLotDescription} ? $params->{seedLotDescription} : undef;
    my $breeding_program_id = $params->{programDbId} ? $params->{programDbId} : undef;
    my $accession_uniquename;

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    if ($saved_seedlot_name ne $seedlot_name){
        my $previous_seedlot = $schema->resultset('Stock::Stock')->find({uniquename=>$seedlot_name, type_id=>$seedlot_cvterm_id});
        if ($previous_seedlot){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('The given seedlot uniquename has been taken. Please use another name or use the existing seedlot.'));
        }
    }
    if ($accession_id){
        my $accession = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$accession_id});
        if (!$accession) {
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('GermplasmDbId does not exist in the database.'));
        }
        $accession_uniquename =  $accession->name();
    }
    if ($cross_id){
        my $cross = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$cross_id});
        if (!$cross) {
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('crossDbId does not exist in the database.'));
        }
    }
    if ($accession_id && $cross_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have either an accession OR a cross as contents. Not both.'));
    }
    if (!$accession_id && !$cross_id ){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have a valid accession or cross.'));
    }
    if (!$breeding_program_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('A seedlot must have a breeding program.'));
    }
    my $location_code;
    if ($location_id){
        my $locations = CXGN::Trial::get_all_locations($schema, $location_id);
        $location_code = $locations->[0]->[1];

        if (!$location_code){
            return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('LocationDbId does not exist in the database.'));
        }
    }

    $seedlot->name($seedlot_name);
    $seedlot->uniquename($seedlot_name);
    $seedlot->breeding_program_id($breeding_program_id);
    $seedlot->organization_name($organization);
    $seedlot->location_code($location_code);
    # $seedlot->box_name($box_name);
    $seedlot->accession_stock_id($accession_id);
    $seedlot->cross_stock_id($cross_id);
    $seedlot->description($description);

    my $return = $seedlot->store();
    if (exists($return->{error})){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('An error occurred, seed lot can not be stored.'));
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
        my $cross = $seedlot_r->cross();

        %result = (
                additionalInfo=>{},
                amount=>$seedlot_r->current_count(),
                createdDate=>undef,
                externalReferences=>[],
                germplasmDbId=>qq|$accession|,
                crossDbId=>qq|$cross|,
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
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Seed lots updated');
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
