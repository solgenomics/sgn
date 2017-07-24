
package SGN::Controller::AJAX::Seedlot;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

use Data::Dumper;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;
use SGN::Model::Cvterm;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub list_seedlots :Path('/ajax/breeders/seedlots') :Args(0) { 
    my $self = shift;
    my $c = shift;

    my $list = CXGN::Stock::Seedlot->list_seedlots($c->dbic_schema("Bio::Chado::Schema"));
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), "seedlot", "stock_property");
    my @seedlots;
    foreach my $sl (@$list) { 
	my $sl_obj = CXGN::Stock::Seedlot->new(schema => $c->dbic_schema("Bio::Chado::Schema"), seedlot_id=>$sl->[0]);
    my $accessions = $sl_obj->accessions();
    my $accessions_html = '';
    foreach (@$accessions){
        $accessions_html .= '<a href="/stock/'.$_->[0].'/view">'.$_->[1].'</a> ';
    }
	push @seedlots, [ $sl_obj->breeding_program_name, '<a href="/breeders/seedlot/'.$sl->[0].'">'.$sl->[1].'</a>', $accessions_html, $sl_obj->location_code, $sl_obj->current_count() ];
    }

    #print STDERR Dumper(\@seedlots);

    $c->stash->{rest} = { data => \@seedlots };
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
    };

    if ($@) { 
	$c->stash->{rest} = { success => 0, seedlot_id => 0, error => $@ };
	print STDERR "An error condition occurred, was not able to create seedlot. ($@).\n";
	return;
    }

    $c->stash->{rest} = { success => 1, seedlot_id => $seedlot_id };
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
        };

        if ($@) { 
            $c->stash->{rest} = { success => 0, seedlot_id => 0, error => $@ };
            print STDERR "An error condition occurred, was not able to create new seedlot. ($@).\n";
            $c->detach();
        }
    }
    my $from_existing_seedlot_id = $c->req->param('from_existing_seedlot_id');
    if ($from_existing_seedlot_id){
        $stock_id = $from_existing_seedlot_id;
        $stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$stock_id})->uniquename();
    }
    my $to_existing_seedlot_id = $c->req->param('to_existing_seedlot_id');
    if ($to_existing_seedlot_id){
        $stock_id = $to_existing_seedlot_id;
        $stock_uniquename = $schema->resultset('Stock::Stock')->find({stock_id=>$stock_id})->uniquename();
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
    
    $c->stash->{rest} = { success => 1, transaction_id => $transaction_id };
}

1;

no Moose;
__PACKAGE__->meta->make_immutable;
