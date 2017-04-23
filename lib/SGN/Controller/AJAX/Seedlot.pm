
package SGN::Controller::AJAX::Seedlot;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

use Data::Dumper;
use CXGN::Seedlot;
use SGN::Model::Cvterm;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub list_seedlots :Path('/ajax/breeders/seedlots') :Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $list = CXGN::Seedlot->list_seedlots($c->dbic_schema("Bio::Chado::Schema"));
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), "seedlot", "stock_property");
    my @seedlots;
    foreach my $sl (@$list) { 
	my $sl_obj = CXGN::Seedlot->new(schema => $c->dbic_schema("Bio::Chado::Schema"), $sl->[0]);
	push @seedlots, [ '<a href="/breeders/seedlot/'.$sl->[0].'">'.$sl->[1].'</a>', $sl->[2], $sl_obj->current_count() ];
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
    $c->stash->{seedlot} = CXGN::Seedlot->new( 
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

    my $uniquename = $c->req->param("seedlot_name");
    my $location_code = $c->req->param("seedlot_location");
    my $accession_id = $c->req->param("seedlot_accession_id");
    my $population_name = $c->req->param("seedlot_population_name");
    my $organization = $c->req->param("seedlot_organization");


    print STDERR "Creating new Seedlot $uniquename\n";
    my $seedlot_id;

    eval { 
        my $sl = CXGN::Seedlot->new(schema => $c->dbic_schema("Bio::Chado::Schema"));
        $sl->uniquename($uniquename);
        $sl->location_code($location_code);
        $sl->accession_stock_ids([$accession_id]);
        $sl->organization_name($organization);
        $sl->population_name($population_name);

        #TO DO
        #$sl->cross_id($cross_id);

        $seedlot_id = $sl->store();
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
    
    my $transactions = $c->stash->{seedlot}->transactions();
    
    my @transactions;
    foreach my $t (@$transactions) { 
	push @transactions, [ $t->transaction_id(), $t->seedlot_id, $t->source_id, $t->amount() ];
    }

    $c->stash->{rest} = { result => \@transactions };
    
}

sub add_seedlot_transaction :Chained('seedlot_base') :PathPart('transaction/add') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $source_id = $c->req->param("source_id");
    my $amount = $c->req->param("amount");
    my $transaction = CXGN::Seedlot::Transaction->new(schema => $c->stash->{schema});
    $transaction->source_id($source_id);
    $transaction->seedlot_id($c->stash->{seedlot_id});
    $transaction->amount($amount);

    my $transaction_id = $transaction->store();
    
    $c->stash->{rest} = { success => 1, transaction_id => $transaction_id };
}

1;

no Moose;
__PACKAGE__->meta->make_immutable;
