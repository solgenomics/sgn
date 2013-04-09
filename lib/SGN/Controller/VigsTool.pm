
package SGN::Controller::VigsTool;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use File::Basename;
use File::Slurp;
use File::Spec;
use File::Temp qw | tempfile |; 
use POSIX;
use Storable qw | nstore |;
use Tie::UrlEncoder;

use Bio::SeqIO;
use CXGN::Graphics::BlastGraph;
use CXGN::Graphics::VigsGraph;
use CXGN::DB::Connection;
use CXGN::BlastDB;
use CXGN::Page::FormattingHelpers qw| page_title_html info_table_html hierarchical_selectboxes_html |;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/evens distinct/;
use CXGN::Tools::Run;

our %urlencode;

sub input :Path('/tools/vigs/')  :Args(0) { 
    my ($self, $c) = @_;
    my $dbh = CXGN::DB::Connection->new;
    our $prefs = CXGN::Page::UserPrefs->new( $dbh );

    # get database ids from a string in the configuration file 
    my @database_ids = split /\s+/, $c->config->{vigs_tool_blast_datasets};

    print STDERR "DATABASE ID: ".join(",", @database_ids)."\n";
    
    # check databases ids exists at SGN
    my @databases;
    foreach my $d (@database_ids) { 
	my $bdb = CXGN::BlastDB->from_id($d);
	if ($bdb) { push @databases, $bdb; }
    }

    $c->stash->{template} = '/tools/vigs/input.mas';
    $c->stash->{databases} = \@databases;
    
}

sub calculate :Path('/tools/vigs/result') :Args(0) { 
    my ($self, $c) = @_;

    my @errors; #to store erros as they happen
 
    # get variables from catalyst object
    my $params = $c->req->body_params();
    my $sequence = $c->req->param("sequence");
    my $fragment_size = $c->req->param("fragment_size");

    #--------------------------------------------------------------------------- clean sequence 
    # more than one sequence pasted
    if ($sequence =~ tr/>/>/ > 1) {
	push ( @errors , "Please, paste only one sequence at time.\n");	
    }
    my $id = "pasted_sequence";

    $sequence =~ s/[^\w> \-\_\#\(\)\%\'\"\[\]\{\}\:\;\=\+\\\/]/\n/gi;
    my @seq = split(/\n/,$sequence);

    if ($seq[0] =~ />(\S+)/) {
	shift(@seq);
	$id = $1;
    }
    $sequence = join("",@seq);
    
    print STDERR "*********************\nseq:$sequence\n*********************\n";
    #---------------------------------------------------- Check input sequence and fragment size    
    if (length($sequence) < 15) { 
	push ( @errors , "You should paste a valid sequence (15 bp or longer) in the VIGS Tool Sequence window.\n");	
    }
    elsif ($sequence =~ /([^ACGT]+)/i) {
	push ( @errors , "Unexpected characters found in the sequence: $1\n");	
    }
    elsif (length($sequence) < $fragment_size) {
	push ( @errors , "Fragment size must be lower or equal to sequence length.\n");
    }

    if (!$fragment_size ||$fragment_size < 15 || $fragment_size > 30 ) { 
	push @errors, "Fragment size ($fragment_size) should be a value between 15-30 bp.\n";
    }

    #--------------------------------------- Send error message to the web if something is wrong
    if (scalar (@errors) > 0){
	user_error(join("<br />" , @errors));
	my $sample = substr($sequence,0,49);
	push @errors, "<b>ID:</b> $id<br /><b>Sequence:</b>$sample...\n";
	my $user_errors = join("<br />", @errors);
       	$c->throw( message => "$user_errors", is_error => 0);
    }

    #------------------- generate a file with fragments of 'sequence' of length 'fragment_size'
    #------------------- for analysis with Bowtie2.
    my ($seq_fh, $seq_filename) = tempfile("vigsXXXXXX", DIR=> $c->config->{'cluster_shared_tempdir'},);

    #----------------------------------------------------- Lets create the fragment fasta file
    my $query = Bio::Seq->new(-seq=>$sequence, -id=> $id || "temp");
    my $io = Bio::SeqIO->new(-format=>'fasta', -file=>">".$seq_filename.".fragments");    
    foreach my $i (1..$query->length()-$fragment_size) { 
	my $subseq = $query->subseq($i, $i + $fragment_size -1);
	my $subseq_obj = Bio::Seq->new(-seq=>$subseq, -display_id=>"tmp_$i");
	$io->write_seq($subseq_obj);
    }

    $c->stash->{query} = $query;
    $io->close();

    #-------------------------------------------------------- Lets create the query fasta file
    my $query_file = $seq_filename;
    my $seq = Bio::Seq->new(-seq=>$sequence, -id=> $id || "temp");
    $io = Bio::SeqIO->new(-format=>'fasta', -file=>">".$query_file);
    
    $io->write_seq($seq);
    $io->close();

    if (! -e $query_file) { die "Query file failed to be created."; }

    #------------------------------------------------------------ get arguments to Run Bowtie2
    print STDERR "DATABASE SELECTED: $params->{database}\n";
    my $bdb = CXGN::BlastDB->from_id($params->{database});
    
    #my $basename = $bdb->full_file_basename;
    my $basename = $c->config->{blast_db_path};
    my $database = $bdb->file_base;
    my $database_fullpath = File::Spec->catfile($basename, $database);
    print STDERR "BASENAME: $basename\n";
    my $database_title = $bdb->title;

    # THIS IS A TMP VARIABLE FOR DEVELOPING
#    $basename = "/home/noe/cxgn/blast_dbs/niben_bt2_index";
    
    #----------------------------------------------------------------------------- run bowtie2
    print STDERR "\n\nSYSTEM CALL: /data/shared/bin/bt2_wrapper.sh $basename $seq_filename.fragments $seq_filename.bt2.out\n\n";

    my $bowtie2_path = $c->config->{bowtie2_path};
    
    my @command = (File::Spec->catfile($bowtie2_path, "bowtie2"), 
	   " --threads 1", 
	   " --very-fast", 
	   " --no-head", 
	   " --end-to-end", 
	   " -a", 
	   " --no-unal", 
	   " -x ". $database_fullpath,
	   " -f",
	   " -U ". $query_file.".fragments",
	   " -S ". $query_file.".bt2.out",
	);

    print STDERR "COMMAND: ".(join ", ",@command)."\n";
    
    my $err = system(@command);

    if ($err) { die "bowtie2 run failed."; }

    $id = $urlencode{basename($seq_filename)};
    $c->res->redirect("/tools/vigs/view/?id=$id&fragment_size=$fragment_size&database=$database_title&targets=0");
}


sub view :Path('/tools/vigs/view') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $seq_filename = $c->req->param("id");
    my $fragment_size = $c->req->param("fragment_size") || 21;
    my $coverage = $c->req->param("targets");
    my $database = $c->req->param("database");

    $seq_filename = File::Spec->catfile($c->config->{cluster_shared_tempdir}, $seq_filename);

    $c->stash->{query_file} = $seq_filename;

    $seq_filename =~ s/\%2F/\//g;

    print $seq_filename;
    my $io = Bio::SeqIO->new(-file=>$seq_filename, -format=>'fasta');
    my $query = $io->next_seq();

    $c->stash->{query} = $query;
    $c->stash->{template} = '/tools/vigs/view.mas';
    
#    open(my $F, "<", $job_file_tempdir."/".$file) || die "Can't open file $file.";
    my %matches;
    my @queries = ();
    
    #graph variables for just Evan's graph package
    my $graph_img_filename = basename($c->tempfile(TEMPLATE=>'imgXXXXXX', UNLINK=>0) . ".png");
    my $graph_img_path = File::Spec->catfile($c->config->{basepath}, $c->tempfiles_subdir('vigs'), $graph_img_filename);
    my $graph_img_url  = File::Spec->catfile($c->tempfiles_subdir('vigs'), $graph_img_filename);

    my $vg = CXGN::Graphics::VigsGraph->new();
    $vg->bwafile($seq_filename.".bt2.out");
    $vg->fragment_size($fragment_size);
    $vg->query_seq($query->seq());
    #$vg->seq_window_size($seq_window_size);
    $vg->parse();    

    if (!$coverage) { 
	$coverage = $vg->get_best_coverage;
    }

    #print STDERR "BEST COVERAGE: $coverage\n";
    my @regions = $vg->longest_vigs_sequence($coverage);
    
    #print STDERR "REGION: ", join ", ", @{$regions[0]};
    #print STDERR "\n";

    $vg->hilite_regions( [ [ $regions[0]->[4], $regions[0]->[5] ] ] );
    
    my $image_map = $vg->render($graph_img_path, $coverage);

    $c->stash->{image_map} = $image_map;
    $c->stash->{ids} = [ $vg->subjects_by_match_count($vg->matches()) ];
    $c->stash->{regions} =  [ [ $regions[0]->[4], $regions[0]->[5] ] ];
    $c->stash->{scores}  =  [ [ $regions[0]->[1] ] ];
    $c->stash->{graph_url} = $graph_img_url;
    $c->stash->{coverage} = $coverage;
    $c->stash->{seq_filename} = basename($seq_filename);
    $c->stash->{database} = $database;
    $c->stash->{fragment_size} = $fragment_size;
}

sub user_error {
    my ($reason) = @_;
    
    print <<EOF;
    
    <h4>VIGS Tool Error</h4>
	
	<p>$reason</p>
EOF

return;

}

sub hash2param {
  my %args = @_;
  return join '&', map "$urlencode{$_}=$urlencode{$args{$_}}", distinct evens @_;
}


1;
