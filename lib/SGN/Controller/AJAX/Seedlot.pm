
package SGN::Controller::AJAX::Seedlot;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

use Data::Dumper;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;
use SGN::Model::Cvterm;
use CXGN::Stock::Seedlot::ParseUpload;
use CXGN::Login;

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
    my $contents = $params->{contents} || '';
    my $rows = $params->{length} || 10;
    my $offset = $params->{start} || 0;
    my $limit = ($offset+$rows)-1;
    my $draw = $params->{draw};
    $draw =~ s/\D//g; # cast to int

    my ($list, $records_total) = CXGN::Stock::Seedlot->list_seedlots(
        $c->dbic_schema("Bio::Chado::Schema"),
        $offset,
        $limit,
        $seedlot_name,
        $breeding_program,
        $location,
        $minimum_count,
        $contents
    );
    my @seedlots;
    my %unique_seedlots;
    foreach my $sl (@$list) {
        my $source_stocks = $sl->{source_stocks};
        my $contents_html = '';
        foreach (@$source_stocks){
            $contents_html .= '<a href="/stock/'.$_->[0].'/view">'.$_->[1].'</a> ';
        }
        push @seedlots, {
            breeding_program_id => $sl->{breeding_program_id},
            breeding_program_name => $sl->{breeding_program_name},
            seedlot_stock_id => $sl->{seedlot_stock_id},
            seedlot_stock_uniquename => $sl->{seedlot_stock_uniquename},
            contents_html => $contents_html,
            location => $sl->{location},
            location_id => $sl->{location_id},
            count => $sl->{current_count}
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
    $c->stash->{seedlot_id} = $seedlot_id;
    $c->stash->{seedlot} = CXGN::Stock::Seedlot->new( 
	schema => $c->stash->{schema},
	seedlot_id => $c->stash->{seedlot_id},
	);
}

sub seedlot_details :Chained('seedlot_base') PathPart('') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    $c->stash->{rest} = { 
	uniquename => $c->stash->{seedlot}->uniquename(),
	seedlot_id => $c->stash->{seedlot}->seedlot_id(),
	current_count => $c->stash->{seedlot}->current_count(),
    };
    
}

sub seedlot_delete :Chained('seedlot_base') PathPart('delete') Args(0) { 
    my $self = shift;
    my $c = shift;

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
    my $uniquename = $c->req->param("seedlot_name");
    my $location_code = $c->req->param("seedlot_location");
    my $accession_uniquename = $c->req->param("seedlot_accession_uniquename");
    my $accession_id = $schema->resultset('Stock::Stock')->find({uniquename=>$accession_uniquename})->stock_id();
    my $population_name = $c->req->param("seedlot_population_name");
    my $organization = $c->req->param("seedlot_organization");
    my $amount = $c->req->param("seedlot_amount");
    my $timestamp = $c->req->param("seedlot_timestamp");
    my $description = $c->req->param("seedlot_description");
    my $breeding_program_id = $c->req->param("seedlot_breeding_program_id");

    my $operator;
    if ($c->user) {
        $operator = $c->user->get_object->get_username;
    }

    print STDERR "Creating new Seedlot $uniquename\n";
    my $seedlot_id;

    eval { 
        my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
        $sl->uniquename($uniquename);
        $sl->location_code($location_code);
        $sl->accession_stock_ids([$accession_id]);
        $sl->organization_name($organization);
        $sl->population_name($population_name);
        $sl->breeding_program_id($breeding_program_id);
        #TO DO
        #$sl->cross_id($cross_id);
        $seedlot_id = $sl->store();

        my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
        $transaction->factor(1);
        $transaction->from_stock([$accession_id, $accession_uniquename]);
        $transaction->to_stock([$seedlot_id, $uniquename]);
        $transaction->amount($amount);
        $transaction->timestamp($timestamp);
        $transaction->description($description);
        $transaction->operator($operator);
        $transaction->store();

        $sl->set_current_count_property();
    };

    if ($@) { 
	$c->stash->{rest} = { success => 0, seedlot_id => 0, error => $@ };
	print STDERR "An error condition occurred, was not able to create seedlot. ($@).\n";
	return;
    }

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
    my $breeding_program_id = $c->req->param("upload_seedlot_breeding_program_id");
    my $location = $c->req->param("upload_seedlot_location");
    my $population = $c->req->param("upload_seedlot_population_name");
    my $organization = $c->req->param("upload_seedlot_organization_name");
    my $upload = $c->req->upload('seedlot_uploaded_file');
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
    $parser->load_plugin('SeedlotXLS');
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
        $c->stash->{rest} = {error_string => $return_error, missing_accessions => $parse_errors->{'missing_accessions'}};
        $c->detach();
    }


    eval {
        while (my ($key, $val) = each(%$parsed_data)){
            my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
            $sl->uniquename($key);
            $sl->location_code($location);
            $sl->accession_stock_ids([$val->{accession_stock_id}]);
            $sl->organization_name($organization);
            $sl->population_name($population);
            $sl->breeding_program_id($breeding_program_id);
            $sl->check_name_exists(0); #already validated
            #TO DO
            #$sl->cross_id($cross_id);
            my $seedlot_id = $sl->store();

            my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
            $transaction->factor(1);
            $transaction->from_stock([$val->{accession_stock_id}, $val->{accession}]);
            $transaction->to_stock([$seedlot_id, $key]);
            $transaction->amount($val->{amount});
            $transaction->timestamp($timestamp);
            $transaction->description($val->{description});
            $transaction->operator($user_name);
            $transaction->store();

            $sl->set_current_count_property();
        }
    };
    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload seedlots. ($@).\n";
        $c->detach();
    }

    $c->stash->{rest} = { success => 1 };
}

sub list_seedlot_transactions :Chained('seedlot_base') :PathPart('transactions') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $transactions = $c->stash->{seedlot}->transactions();
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    #print STDERR Dumper $transactions;
    my @transactions;
    foreach my $t (@$transactions) {
        my $value_field = '';
        if ($t->factor == 1){
            $value_field = '<span style="color:green">+'.$t->factor()*$t->amount().'</span>';
        }
        if ($t->factor == -1){
            $value_field = '<span style="color:red">'.$t->factor()*$t->amount().'</span>';
        }
        my $from_url;
        my $to_url;
        if ($t->from_stock()->[2] == $type_id){
            $from_url = '<a href="/breeders/seedlot/'.$t->from_stock()->[0].'" >'.$t->from_stock()->[1].'</a>';
        } else {
            $from_url = '<a href="/stock/'.$t->from_stock()->[0].'/view" >'.$t->from_stock()->[1].'</a>';
        }
        if ($t->to_stock()->[2] == $type_id){
            $to_url = '<a href="/breeders/seedlot/'.$t->to_stock()->[0].'" >'.$t->to_stock()->[1].'</a>';
        } else {
            $to_url = '<a href="/stock/'.$t->to_stock()->[0].'/view" >'.$t->to_stock()->[1].'</a>';
        }
        push @transactions, [ $t->transaction_id(), $t->timestamp(), $from_url, $to_url, $value_field, $t->operator, $t->description() ];
    }

    $c->stash->{rest} = { data => \@transactions };
    
}

sub add_seedlot_transaction :Chained('seedlot_base') :PathPart('transaction/add') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to add a seedlot transaction!'};
        $c->detach();
    }
    my $operator = $c->user->get_object->get_username;

    my $to_new_seedlot_name = $c->req->param('to_new_seedlot_name');
    my $stock_id;
    my $stock_uniquename;
    my $newly_created_seedlot;
    if ($to_new_seedlot_name){
        $stock_uniquename = $to_new_seedlot_name;
        eval { 
            my $location_code = $c->req->param('to_new_seedlot_location_name');
            my $accession_uniquename = $c->req->param('to_new_seedlot_accession_name');
            my $accession_id = $schema->resultset('Stock::Stock')->find({uniquename=>$accession_uniquename})->stock_id();
            my $organization = $c->req->param('to_new_seedlot_organization');
            my $population_name = $c->req->param('to_new_seedlot_population_name');
            my $breeding_program_id = $c->req->param('to_new_seedlot_breeding_program_id');
            my $amount = $c->req->param('to_new_seedlot_amount');
            my $timestamp = $c->req->param('to_new_seedlot_timestamp');
            my $description = $c->req->param('to_new_seedlot_description');
            my $sl = CXGN::Stock::Seedlot->new(schema => $schema);
            $sl->uniquename($to_new_seedlot_name);
            $sl->location_code($location_code);
            $sl->accession_stock_ids([$accession_id]);
            $sl->organization_name($organization);
            $sl->population_name($population_name);
            $sl->breeding_program_id($breeding_program_id);
            #TO DO
            #$sl->cross_id($cross_id);
            my $seedlot_id = $sl->store();
            $stock_id = $seedlot_id;

            my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema);
            $transaction->factor(1);
            $transaction->from_stock([$accession_id, $accession_uniquename]);
            $transaction->to_stock([$seedlot_id, $to_new_seedlot_name]);
            $transaction->amount($amount);
            $transaction->timestamp($timestamp);
            $transaction->description($description);
            $transaction->operator($operator);
            $transaction->store();

            $sl->set_current_count_property();
            $newly_created_seedlot = $sl;
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
    $transaction->timestamp($timestamp);
    $transaction->description($description);
    $transaction->operator($c->user->get_object->get_username);

    my $transaction_id = $transaction->store();
    $c->stash->{seedlot}->set_current_count_property();

    if ($existing_sl){
        $existing_sl->set_current_count_property();
    }
    if($newly_created_seedlot){
        $newly_created_seedlot->set_current_count_property();
    }

    $c->stash->{rest} = { success => 1, transaction_id => $transaction_id };
}

1;

no Moose;
__PACKAGE__->meta->make_immutable;
