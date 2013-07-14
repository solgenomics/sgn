
package SGN::Controller::Blast;

use Moose;

use POSIX;
use Data::Dumper;
use List::Util qw/sum/;
use Bio::SeqIO;
use CXGN::Tools::Text qw/ sanitize_string /;
#use SGN::Schema;
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

    my $group_rs = $schema->resultset("BlastDbGroup")->search( undef, { order_by=>'ordinal' });

    my $databases = {};
    my $dataset_groups = [];

    foreach my $g ($group_rs->all()) { 
	my @blast_dbs = $g->blast_dbs();
	push @$dataset_groups, [ $g->blast_db_group_id, $g->name() ];
	foreach my $db (@blast_dbs) { 
	    push @{$databases->{ $g->blast_db_group_id  }},
    	    [ $db->blast_db_id(), $db->title(), $db->type() ];
	}
    }
    # else { 
    #     push @{$databases->{ 'other' }}, 
    #     [ $g->blast_dbs->blast_db_id, $g->blast_dbs->title, $g->blast_dbs->type ];
    #     $dataset_groups->{'0'}= 'other';
    # } 


my $cbsq = CXGN::Blast::SeqQuery->new();
    my @input_options = sort map { [ $_->name(), $_->name(), $_->type()] } $cbsq->plugins();


    print STDERR "GROUPS: ".Data::Dumper::Dumper($dataset_groups);
    print STDERR "DATASETS: ".Data::Dumper::Dumper($databases);
    $c->stash->{input_options} = \@input_options;

    $c->stash->{db_id} = $db_id;
    $c->stash->{seq} = $seq;
    $c->stash->{databases} = $databases;
    $c->stash->{dataset_groups} = $dataset_groups;
    $c->stash->{preload_seq} = $seq;
    $c->stash->{programs} = [ 'blastn', 'blastp', 'blastx', 'tblastx' ];
    $c->stash->{template} = '/tools/blast/index.mas';
}

sub dbinfo : Path('/tools/blast/dbinfo') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("SGN::Schema");

    my @data = ();

    my $group_rs = $schema->resultset('BlastDbGroup')->search({}, { order_by => 'ordinal, name' });
    while (my $group_row = $group_rs->next()) { 
	my $db_rs = $group_row->blast_dbs->search({ web_interface_visible => 't'});
	my @groups = ();
	while (my $db_row = $db_rs->next()) { 
	    if ($db_row->files_exist()) { 

		push @groups, { 
		    title              => $db_row->title(),
		    sequence_type      => $db_row->type(),
                    sequence_count     => $db_row->sequences_count(),
		    update_freq        => $db_row->update_freq(),
		    description        => $db_row->description(),
		    source_url         => $db_row->source_url(),
		    current_as_of      => strftime('%m-%d-%y %R GMT',gmtime $db_row->file_modtime),
		    needs_update       => $db_row->needs_update(),
		};
	    }
	}
	push @data, [ $group_row->blast_db_group_id(), $group_row->name(), \@groups ];
    }
    
    my $ungrouped_rs = $schema->resultset('BlastDb')->search(
	{ blast_db_group_id => undef, 
	  web_interface_visible => 't' }, 
	{order_by => 'title'} 
	);

    my @other_groups = ();
    if ($ungrouped_rs) {
	while (my $db_row = $ungrouped_rs->next()) { 
	    if ($db_row->files_exist()) { 
		push @other_groups, { 
		    title              => $db_row->title(),
		    sequence_type      => $db_row->type(),
		    sequence_count     => $db_row->sequences_count(),
		    update_freq        => $db_row->update_freq(),
		    description        => $db_row->description(),
		    source_url         => $db_row->source_url(),
		    current_as_of      => strftime('%m-%d-%y %R GMT',gmtime $db_row->file_modtime),
		    needs_update       => $db_row->needs_update(),
		};
	    }
	}
	push @data, [ 0, 'Other', \@other_groups ];
    }
    
    $c->stash->{template} = '/tools/blast/dbinfo.mas';
    $c->stash->{groups} = \@data;
}

sub show_match_seq : Path('/tools/blast/match/show') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $id = $c->req->param('id');
    my $blast_db_id = $c->req->param('blast_db_id');
    my $format = $c->req->param('format');
    my $hilite_coords  = $c->req->param('hilite_coords');
    
    $format ||= 'html';
    $blast_db_id += 0;
    $id = sanitize_string( $id );
    
    $c->stash->{template} = '/blast/show_seq/input.mas' unless $blast_db_id && defined $id;
 
    # look up our blastdb
    my $schema = $c->dbic_schema("SGN::Schema");
    my $bdbo = $schema->resultset("BlastDb")->find($blast_db_id)
    	or $c->throw( is_error => 0,
		      message => "The blast database with id $blast_db_id could not be found (please set the blast_db_id parameter).");
    my $seq = $bdbo->get_sequence($id) # returns a Bio::Seq object.
	or $c->throw( is_error => 0,
		      message => "The sequence could not be found in the blast database with id $blast_db_id.");

    # parse the coords param
    my @coords =
	map {
	    my ($s, $e) = split "-", $_;
	    defined $_ or die 'parse error' for $s, $e;
	    [ $s, $e ]
    }
    grep length,
    split ',', ( $hilite_coords || '' );
    
    # dispatch to the proper view
    if ($format eq 'html') {
	
	my $view_link     = '';
	my $download_link = ''; #do { $format => 'fasta_file'; '?'.$c->req->body };
	
	$c->stash->{template} = '/blast/show_seq/html.mas';
	$c->stash->{seq} = $seq;
	$c->stash->{highlight_coords} = \@coords;
	$c->stash->{source} = '"'.$bdbo->title().'" BLAST dataset ';
	$c->stash->{format_links} = [
            ( $seq->length > 500_000 ? () : [ 'View as FASTA' => $view_link ] ),
            [ 'Download as FASTA' => $download_link ],
	    ];
        $c->stash->{blast_url} = '/tools/blast';

    } 
    elsif($format eq 'fasta_file' || $format eq 'fasta_text') {


	my $attachment =  $format eq 'fasta_file' ? 'attachment;' : '';
	$c->res->body(qq | Content-Type: text/plain\n\n | . 
		      
		      "Content-Disposition: $attachment filename=$id.fa\n\n".
		      Bio::SeqIO->new( -fh => \*STDOUT, -format => 'fasta' )
		      ->write_seq( $seq ));
    }
}



1;
