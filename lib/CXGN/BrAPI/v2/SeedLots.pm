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
    my $reference_sources_arrayref = $params->{externalReferenceSources} || ();

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
            lastUpdated=>qq|$_->{source_stocks}->[0][1]|,
            locationDbId=>qq|$_->{location_id}|,
            programDbId=>qq|$_->{breeding_program_id}|,
            seedLotDbId=>qq|$_->{seedlot_stock_id}|,
            seedLotDescription=>$_->{seedlot_stock_description},
            seedLotName=>$_->{seedlot_stock_uniquename},
            sourceCollection=>$_->{box},
            storageLocation=>undef,
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
                sourceCollection=>$seedlot->box_name(),
                storageLocation=>undef,
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

1;
