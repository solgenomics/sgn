
package SGN::Controller::AJAX::SequencedAccessions;

use Moose;

use Data::Dumper;
use CXGN::Stock::SequencingInfo;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


BEGIN { extends 'Catalyst::Controller::REST' };

sub get_all_sequenced_stocks :Path('/ajax/genomes/sequenced_stocks') {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my @sequenced_stocks = CXGN::Stock::SequencingInfo->all_sequenced_stocks($schema);
    
    my @info = $self->retrieve_sequencing_infos($schema, @sequenced_stocks);
    
    $c->stash->{rest} = { data => \@info };
}
    
sub get_sequencing_info_for_stock :Path('/ajax/genomes/sequenced_stocks') Args(1) {
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;

    print STDERR "Retrieving sequencing info for stock $stock_id...\n";
    my @info = $self->retrieve_sequencing_infos($c->dbic_schema("Bio::Chado::Schema"), $stock_id);

    print STDERR "SEQ INFOS: ".Dumper(\@info);
    
    $c->stash->{rest} = { data => \@info };
}

sub retrieve_sequencing_infos {
    my $self = shift;
    my $schema = shift;
    my @stock_ids = @_;

    print STDERR Dumper(\@stock_ids);
    
    my @data = ();
    
    foreach my $stock_id (@stock_ids) {
	print STDERR "retrieving data for stock stock_id...\n";
	my $infos = CXGN::Stock::SequencingInfo->get_sequencing_project_infos($schema, $stock_id);

	print STDERR "INFO = ".Dumper($infos);

	if ($infos) {
	    foreach my $info (@$infos) {
		
		my $website = "";
		if ($info->{website}) {
		    $website = qq | <a href="'.$info->{website}.'">$website</a> |;
		}
		    
		my $blast_link = "BLAST";
		if ($info->{blast_link}) {
		    $blast_link = qq | <a href="'.$info->{blast_link}.'">BLAST</a> |;
		}
		
		my $jbrowse_link = "Jbrowse";
		if ($info->{jbrowse_link}) {
		    $jbrowse_link = qq | <a href="'.$info->{jbrowse_link}.'">JBrowse</a> |;
		}

		push @data, [
		    "<a href=\"/stock/$stock_id\">".$info->{uniquename}."</a>",
		    $info->{year},
		    $info->{organization},
		    $info->{website},
		    $blast_link." | ".$jbrowse_link,
		    '<a href="">Edit</a> | <a href="javascript:alert(\'HELLO\')">Delete</a>'
		];
	    }
	}
    }

    print STDERR "Sequencing Data for this stock: ".Dumper(\@data);
    return @data;
}

sub store_sequencing_info :Path('/ajax/genomes/store_sequencing_info') Args(0) {
    my $self =shift;
    my $c = shift;

    my $params = $c->req->params();

    print STDERR "Params for store: ".Dumper($params);
    
    if (!$c->user()->check_roles("curator")) {
	$c->stash->{error => "You need to be logged in as a curator to submit this information" };
    }
	
    print STDERR "store_sequecing_info PARAMS = ".Dumper($params);
    
    my $stockprop_id = $params->{stockprop_id}; # if available, then we update
    my $stock_id = $params->{stock_id};
    
    my $si = CXGN::Stock::SequencingInfo->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    $si->from_hash($params);
    $si->store();
}


sub delete_sequencing_info :Path('/ajax/genomes/sequencing_info/delete') Args(1) {
    my $self = shift;
    my $c = shift;
    
    my $stockprop_id = shift;

    if (!$c->user() && !$c->user()->check_roles("curator")) {
	$c->stash->{rest} = { error => "Log in required for sequencing info deletion." };
	return;
    }
    
    my $si = CXGN::Stock::SequencingInfo->new( { schema => $c->dbic_schema("Bio::Chado::Schema"), $stockprop_id });

    my $success;
    if ($si->stockprop_id()) {
	eval { 
	    $success = $si->delete();
	};
	if ($@) {
	    $c->stash->{rest} = { error => "An error occurred while deleting sequencing info. ($@)" };
	    return;
	}
    }
    
    if ($success) {
	$c->stash->{rest} = { success => 1 };
    }
    else {
	$c->stash->{rest} = { error => "An error occurred during deletion." }
    }
}



1;
