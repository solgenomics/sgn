
package SGN::Controller::Blast;

use Moose;

use POSIX;
use Data::Dumper;
use Storable qw | nstore retrieve |;
use List::Util qw/sum/;
use Bio::SeqIO;
use CXGN::Tools::Text qw/ sanitize_string /;
#use SGN::Schema;
use CXGN::Blast;
use CXGN::Blast::SeqQuery;


BEGIN { extends 'Catalyst::Controller'; }

sub AUTO { 
    my $self = shift;
    my $c = shift;
    SGN::Schema::BlastDb->dbpath($c->config->{blast_db_path});
}

sub index :Path('/tools/blast/') :Args(0) { 
  my $self = shift;
  my $c = shift;

  my $db_id = $c->req->param('db_id');

  my $seq = $c->req->param('seq');
  my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
  my $schema = $c->dbic_schema("SGN::Schema", undef, $sp_person_id);
  
  my $blast_db_icons = $c->config->{blast_db_icons};
  my $group_rs = $schema->resultset("BlastDbGroup")->search( undef, { order_by=>'ordinal' });

  my $databases = {};
  my $dataset_groups = [];
  
  my $preselected_database = $c->config->{preselected_blastdb};
  my $preselected_category = '';
  
  # 224 is the database id for tomato cDNA ITAG 2.40 on production
  # $preselected_database = 224;
  
  if ($db_id) { 
    my $rs = $schema->resultset("BlastDb")->search( { 'me.blast_db_id' => $db_id }, { join => 'blast_db_blast_db_groups' });
    
    if ($rs == 0) {
      $c->throw( is_error => 0, message => "The blast database with id $db_id could not be found.");
    }
    
    $preselected_database = $rs->first()->blast_db_id(); # first database of the category
    $preselected_category = $rs->first()->blast_db_group_id();
  }
    
  foreach my $g ($group_rs->all()) { 
    my @blast_dbs = $g->blast_dbs();
    push @$dataset_groups, [ $g->blast_db_group_id, $g->name() ];

    my @dbs_AoA;

    foreach my $db (@blast_dbs) {
      push @dbs_AoA, [ $db->blast_db_id(), $db->title(), $db->type() ];
    }

    my @arr = sort {$a->[1] cmp $b->[1]} @dbs_AoA;
    $databases->{ $g->blast_db_group_id } = \@arr;
  }

  my $cbsq = CXGN::Blast::SeqQuery->new();
  my @input_options = sort {$a->[0] cmp $b->[0]} ( map { [ $_->name(), $_->name(), $_->type(), $_->example() ] } $cbsq->plugins() );
  
  my $cbp = CXGN::Blast::Parse->new();
  my @parse_options = sort { $b->[0] cmp $a->[0] } ( map { [ $_->name(), $_->name() ] } $cbp->plugins() );

  # # remove the Basic option from the list (it will still be the default if nothing is selected)
  # #
  # for (my $i=0; $i<@parse_options; $i++) {
  #   if ($parse_options[$i]->[0] eq 'Basic') {
  #       delete($parse_options[$i]);
  #   }
  # }

  #print STDERR "INPUT OPTIONS: ".Data::Dumper::Dumper(\@input_options);
  #print STDERR "GROUPS: ".Data::Dumper::Dumper($dataset_groups);
  #print STDERR "DATASETS: ".Data::Dumper::Dumper($databases);

  # print STDERR "controller pre-selected db: $preselected_database\n";

  $c->stash->{input_options} = \@input_options;
  $c->stash->{parse_options} = \@parse_options;
  $c->stash->{preselected_database} = $preselected_database;
  $c->stash->{preselected_category} = $preselected_category;
  $c->stash->{seq} = $seq;
  $c->stash->{preload_id} = $c->req->param('preload_id');
  $c->stash->{preload_type} = $c->req->param('preload_type');

  $c->stash->{blast_db_icons} = $blast_db_icons;

  $c->stash->{databases} = $databases;
  $c->stash->{dataset_groups} = $dataset_groups;
  $c->stash->{preload_seq} = $seq;
  $c->stash->{programs} = [
    [ 'blastn', 'blastn (nucleotide to nucleotide db)' ],
    [ 'blastp', 'blastp (protein to protein db)' ], 
    [ 'blastx', 'blastx (translated nucleotide to protein db)'],
    [ 'tblastn', 'tblastn (protein to translated nucleotide db)'], 
    [ 'tblastx', 'tblastx (translated nucleotide to translated nucleotide db)'],
  ];
  $c->stash->{template} = '/tools/blast/index.mas';
}

sub dbinfo : Path('/tools/blast/dbinfo') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $data = [];

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("SGN::Schema", undef, $sp_person_id);

    # 
    my $cache = $c->config->{basepath}."/".$c->tempfiles_subdir("blast")."/dbinfo_cache";
    if ((-e $cache) && ($c->req->param("force") != 1)) { 
	$data = retrieve($cache);
    }
    else { 
	my $group_rs = $schema->resultset('BlastDbGroup')->search({}, { order_by => 'ordinal, name' });
	while (my $group_row = $group_rs->next()) { 
	    my $db_rs = $group_row->blast_dbs->search({ web_interface_visible => 't'});
	    my @groups = ();
	   
	    while (my $db_row = $db_rs->next()) { 
        my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
		my $db = CXGN::Blast->new( sgn_schema => $c->dbic_schema("SGN::Schema", undef, $sp_person_id), blast_db_id => $db_row->blast_db_id(), dbpath => $c->config->{blast_db_path}); 
		if ($db->files_are_complete()) { 
		    
		    push @groups, { 
			title              => $db->title(),
			sequence_type      => $db->type(),
			sequence_count     => $db->sequences_count(),
			update_freq        => $db->update_freq(),
			description        => $db->description(),
			source_url         => $db->source_url(),
			current_as_of      => strftime('%m-%d-%y %R GMT',gmtime $db->file_modtime),
			needs_update       => $db->needs_update(),
		    };
		}
	    }
	    push @$data, [ $group_row->blast_db_group_id(), $group_row->name(), \@groups ];
	}
	
	my $ungrouped_rs = $schema->resultset('BlastDb')->search(
	    { blast_db_group_id => undef, 
	      web_interface_visible => 't' }, 
	    {order_by => 'title'} 
	    );
	
	my @other_groups = ();
	if ($ungrouped_rs) {
	    while (my $db_row = $ungrouped_rs->next()) { 
        my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
		my $db = CXGN::Blast->new( sgn_schema => $c->dbic_schema("SGN::Schema", undef, $sp_person_id), blast_db_id => $db_row->blast_db_id(), dbpath => $c->config->{blast_db_path}); 
		if ($db->files_are_complete()) { 
		    push @other_groups, { 
			title              => $db->title(),
			sequence_type      => $db->type(),
			sequence_count     => $db->sequences_count(),
			update_freq        => $db->update_freq(),
			description        => $db->description(),
			source_url         => $db->source_url(),
			current_as_of      => strftime('%m-%d-%y %R GMT',gmtime $db->file_modtime),
			needs_update       => $db->needs_update(),
		    };
		}
	    }
	    push @$data, [ 0, 'Other', \@other_groups ];
	}
	nstore($data, $cache);
	
    }
    $c->stash->{template} = '/tools/blast/dbinfo.mas';
    $c->stash->{groups} = $data;
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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("SGN::Schema", undef, $sp_person_id);
#    my $bdbo = $schema->resultset("BlastDb")->find($blast_db_id)
#    	or $c->throw( is_error => 0,
#		      message => "The blast database with id $blast_db_id could not be found (please set the blast_db_id parameter).");
    my $bo = CXGN::Blast->new( { 
	sgn_schema => $schema,  
	blast_db_id => $blast_db_id,
	dbpath => $c->config->{blast_db_path}	       
			       });

    print STDERR "Path:". $c->config->{blast_db_path}." db_id: ".$blast_db_id."\n";

    my $seq = $bo->get_sequence($id) # returns a Bio::Seq object.
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
	
	my $view_link     = "/tools/blast/match/show?format=fasta_text&blast_db_id=$blast_db_id&id=$id";
	my $download_link = "/tools/blast/match/show?format=fasta_file&blast_db_id=$blast_db_id&id=$id"; #do { $format => 'fasta_file'; '?'.$c->req->body };
	
	$c->stash->{template} = '/blast/show_seq/html.mas';
	$c->stash->{seq} = $seq;
	$c->stash->{highlight_coords} = \@coords;
	$c->stash->{source} = '"'.$bo->title().'" BLAST dataset ';
	$c->stash->{format_links} = [
            ( $seq->length > 500_000 ? () : [ 'View as FASTA' => $view_link ] ),
            [ 'Download as FASTA' => $download_link ],
	    ];
        $c->stash->{blast_url} = '/tools/blast';

    } 
    elsif($format eq 'fasta_file' || $format eq 'fasta_text') {


	my $attachment =  $format eq 'fasta_file' ? 'attachment;' : '';

	$c->res->headers->content_type("text/plain");
		      
	if ($attachment) { 
	    $c->res->headers->header("Content-Disposition" => "$attachment filename=$id.fa");
	}
	
	$c->res->body(">".$seq->id()." sequence match in blast db ".$bo->title()."\n". $seq->seq() );
    }
}

sub blast_help :Path('/help/tools/blast') :Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/help/blast.mas';

}
    

1;
