
package SGN::Controller::Blast;

use Moose;

use POSIX;
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
    my $dataset_groups = {};
    foreach my $d (@dataset_rows) { 
	print STDERR "processing dataset $d...\n";
	if ($d->blast_db_group()) { 
	    push @{$databases->{ $d->blast_db_group->blast_db_group_id }}, [ $d->blast_db_id, $d->title ];
	    $dataset_groups->{ $d->blast_db_group->blast_db_group_id } =  $d->blast_db_group->name();
	}
	else { 
	    push @{$databases->{ 'other' }}, [ $d->blast_db_id, $d->title ];
	    $dataset_groups->{'0'}= 'other';
	} 
    }

    my $cbsq = CXGN::Blast::SeqQuery->new();
    my @input_options = sort map { $_->name() } $cbsq->plugins();
    
    print STDERR "GROUPS: ".Data::Dumper::Dumper($dataset_groups);
    print STDERR "DATASETS: ".Data::Dumper::Dumper($databases);
    $c->stash->{input_options} = \@input_options;
    $c->stash->{db_id} = $db_id;
    $c->stash->{seq} = $seq;
    $c->stash->{databases} = $databases;
    @{ $c->stash->{dataset_groups}} = map { [ $_, $dataset_groups->{$_} ] } keys %$dataset_groups;
    $c->stash->{programs} = [ 'blastn', 'blastp', 'blastx', 'tblastx' ];
    $c->stash->{template} = '/tools/blast/index.mas';
}

sub dbinfo : Path('/tools/blast/dbinfo') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("SGN::Schema");

    # my @groups = map {
    # 	my $grp = $_;
    # 	if( my @dbs = $grp->blast_dbs->search({ web_interface_visible => 't'})->all() ) {
    # 	    [$grp->name, @dbs ]
    # 	} else {
    # 	    ()
    #     }
    # } $schema->resultset('BlastDbGroup')->search({}, {order_by => 'ordinal, name'})->all();

    my @data = ();

    my $group_rs = $schema->resultset('BlastDbGroup')->search({}, { order_by => 'ordinal, name' });
    while (my $group_row = $group_rs->next()) { 
	my $db_rs = $group_row->blast_dbs->search({ web_interface_visible => 't'});
	my @groups = ();
	while (my $db_row = $db_rs->next()) { 
	    if ($db_row->files_exist()) { 
		my $source_url = $db_row->source_url();
		if ($source_url && $source_url =~ m/^http|^ftp/) { 
		    $source_url = qq | <a href="$source_url">$source_url</a> |;
		}
		my $needs_update = $db_row->needs_update() ?  qq|<span style="background: #c22; padding: 3px; color: white">needs update</span>| : qq|<span style="background: #2c2; padding: 3ppx; color: white">up to date</span>|;
		push @groups, { 
		    title              => $db_row->title(),
		    sequence_type      => $db_row->type(),
                    sequence_count     => $db_row->sequences_count(),
		    update_freq        => $db_row->update_freq(),
		    description        => $db_row->description(),
		    source_url         => $source_url,
		    current_as_of      => strftime('%m-%d-%y %R GMT',gmtime $db_row->file_modtime),
		    needs_update       => $needs_update,
		};
	    }
	}
	push @data, [ $group_row->blast_db_group_id(), $group_row->name(), \@groups ];
    }
    
    #my @groups = ();
    #if (my @ungrouped = grep $_->file_modtime, $schema->resultset('BlastDb')->search( { blast_db_group_id => undef, web_interface_visible => 't' }, {order_by => 'title'} ) ) {
#	push @groups, ['Other', @ungrouped ];
#    }
    
    #my $grpcount = @groups;
    #my $dbcount = sum(map scalar(@$_),@groups)-$grpcount;

    $c->stash->{template} = '/tools/blast/dbinfo.mas';
    $c->stash->{groups} = \@data;
}

1;
