
package SGN::Controller::Blast;

use Moose;

use Data::Dumper;
use List::Util qw/sum/;
use CXGN::Blast::SeqQuery;

BEGIN { extends 'Catalyst::Controller'; }

sub AUTO { 
    my $self = shift;
    my $c = shift;
    SGN::Schema::BlastDb->dbpath($c->config->{blast_db_path});
}

sub index :Path('/tools/new-blast/') :Args(0) { 
    my $self = shift;
    my $c = shift;

    my $db_id = $c->req->param('db_id');
    my $seq = $c->req->param('seq');

    my $schema = $c->dbic_schema("SGN::Schema");

    my @dataset_rows = $schema->resultset("BlastDb")->search( {}, { order_by=>'ordinal', join=>'blast_db_group' })->all();

    my $databases = {};
    my $dataset_groups = [];
    foreach my $d (@dataset_rows) { 
	print STDERR "processing dataset $d...\n";
	if ($d->blast_db_group()) { 
	    push @{$databases->{ $d->blast_db_group->blast_db_group_id }}, [ $d->blast_db_id, $d->title ];
	    push @$dataset_groups, [ $d->blast_db_group->blast_db_group_id, $d->blast_db_group->name ];
	}
	else { 
	    push @{$databases->{ 'other' }}, [ $d->blast_db_id, $d->title ];
	    push @$dataset_groups-> [ 0, 'other' ];
	} 

    }

    my $cbsq = CXGN::Blast::SeqQuery->new();
    my @input_options = sort map { $_->name() } $cbsq->plugins();
    

    print STDERR "GROUPS: ".Data::Dumper::Dumper($dataset_groups);
    $c->stash->{input_options} = \@input_options;
    $c->stash->{db_id} = $db_id;
    $c->stash->{seq} = $seq;
    $c->stash->{databases} = $databases;
    $c->stash->{dataset_groups} = $dataset_groups;
    $c->stash->{programs} = [ 'blastn', 'blastp', 'blastx', 'tblastx' ];
    $c->stash->{template} = '/tools/blast/index.mas';

}

sub dbinfo : Path('/tools/blast/dbinfo') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("SGN::Schema");

    my @groups = map {
	my $grp = $_;
	if( my @dbs = $grp->blast_dbs->search({ web_interface_visible => 't'}) ) {
	    [$grp->name, @dbs ]
	} else {
	    ()
        }
    } $schema->resultset('BlastDbGroup')->search({}, {order_by => 'ordinal, name'});
    
    if (my @ungrouped = grep $_->file_modtime, $schema->resultset('BlastDb')->search( { blast_db_group_id => undef, web_interface_visible => 't' }, {order_by => 'title'} ) ) {
	push @groups, ['Other', @ungrouped ];
    }
    
    my $grpcount = @groups;
    my $dbcount = sum(map scalar(@$_),@groups)-$grpcount;

    $c->stash->{template} = '/tools/blast/dbinfo.mas';
    $c->stash->{groups} = \@groups;
}

1;
