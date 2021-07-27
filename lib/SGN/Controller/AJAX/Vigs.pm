
package SGN::Controller::AJAX::Vigs;

use Moose;

use File::Basename;
use File::Slurp;
use File::Spec;

use Bio::SeqIO;
use Bio::BLAST2::Database;
use Data::Dumper;
use File::Temp qw | tempfile |; 
use CXGN::Graphics::VigsGraph;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );

our %urlencode;

# check input data, create Bowtie2 input data and run Bowtie2
sub run_bowtie2 :Path('/tools/vigs/result') :Args(0) { 
    my ($self, $c) = @_;
    
    # to store erros as they happen
    my @errors; 
 
    # get variables from catalyst object
    my $params = $c->req->body_params();
    my $sequence = $c->req->param("sequence");
    my $fragment_size = $c->req->param("fragment_size");
    my $seq_fragment = $c->req->param("seq_fragment");
    my $missmatch = $c->req->param("missmatch");
    my $db_id = $c->req->param("database");
	
    # clean the sequence and check if there are more than one sequence pasted
    if ($sequence =~ tr/>/>/ > 1) {
		push ( @errors , "Please, paste only one sequence.\n");	
    }
    my $id = "pasted_sequence";
    my @seq = [];

    if ($sequence =~ /^>/) {
		$sequence =~ s/[ \,\-\.\#\(\)\%\'\"\[\]\{\}\:\;\=\+\\\/]/_/gi;
		@seq = split(/\s/,$sequence);

		if ($seq[0] =~ />(\S+)/) {
		    shift(@seq);
		    $id = $1;
		}
		$sequence = join("",@seq);
    } elsif ($sequence =~ tr/acgtACGT/acgtACGT/ < 30) {
		
		# save pasted gene name
		my $pasted_gene_name = $sequence;
		$sequence =~ s/\.\d//;
		$sequence =~ s/\.\d//;
		
		# print STDERR "seq: $sequence\n";
		
		# get databases path from the configuration file
		my $db_path = $c->config->{vigs_db_path};
			
		# get database names from their path
		# my @tmp_dbs = glob("$db_path/*.rev.1.bt2");
		my @tmp_dbs = glob("$db_path/*.rev.1.ebwt");
		
		# find the pasted gene name in the BLAST dbs and leave the loop when the name is found
		foreach my $db_path (@tmp_dbs) {
			# $db_path =~ s/\.rev\.1\.bt2//;
			$db_path =~ s/\.rev\.1\.ebwt//;
			# print STDERR "DB: $db_path\n";
			
			my $fs = Bio::BLAST2::Database->open(full_file_basename => "$db_path",);
			
			if ($fs->get_sequence($sequence)) {
				my $seq_obj = $fs->get_sequence($sequence);
				$sequence = $seq_obj->seq();
				last;
			}
		}
		# print STDERR "seq: $sequence\n";
		
		if ($sequence =~ tr/acgtACGT/acgtACGT/ < 30) {
			push ( @errors , "Your input sequence is not valid: $pasted_gene_name\n");
		}
		
    } else {
		$sequence =~ s/[^ACGT]+//gi;
    }

    # Check input sequence and fragment size    
    if (length($sequence) < 100) { 
		push ( @errors , "You should paste a valid sequence (100 bp or longer) in the VIGS Tool Sequence window.\n");	
    }
    elsif ($sequence =~ /([^ACGT]+)/i) {
		push (@errors, "Unexpected characters found in the sequence: $1\n");	
    }
    elsif (length($sequence) < $fragment_size) {
		push (@errors, "n-mer size must be lower or equal to sequence length.\n");
    }

    if (!$fragment_size ||$fragment_size < 18 || $fragment_size > 24 ) { 
		push (@errors, "n-mer size ($fragment_size) value must be between 18-24 bp.\n");
    }
    if (!$seq_fragment || $seq_fragment < 100 || $seq_fragment > length($sequence)) {
		push (@errors, "Wrong fragment size ($seq_fragment), it must be higher than 100 bp and lower than sequence length\n");
    }
    if ($missmatch =~ /[^\d]/ || $missmatch < 0 || $missmatch > 2 ) { 
		push (@errors, "miss-match value ($missmatch) must be between 0-2\n");
    }
		#     if ($missmatch =~ /[^\d]/ || $missmatch < 0 || $missmatch > 1 ) { 
		# push (@errors, "miss-match value ($missmatch) must be between 0-1\n");
		#     }

    # Send error message to the web if something is wrong
	if (scalar (@errors) > 0){
		my $user_errors = join("<br />", @errors);
		$c->stash->{rest} = {error => $user_errors};
		return;
	}
	
	# generate temporary file name for analysis with Bowtie2.
	my ($seq_fh, $seq_filename) = tempfile("vigsXXXXXX", DIR=> $c->config->{'cluster_shared_tempdir'},);

    # Lets create the fragment fasta file
    my $query = Bio::Seq->new(-seq=>$sequence, -id=> $id || "temp");
    my $io = Bio::SeqIO->new(-format=>'fasta', -file=>">".$seq_filename.".fragments");    
    foreach my $i (1..$query->length()-$fragment_size) { 
		my $subseq = $query->subseq($i, $i + $fragment_size -1);
		my $subseq_obj = Bio::Seq->new(-seq=>$subseq, -display_id=>"tmp_$i");
		$io->write_seq($subseq_obj);
    }

    $c->stash->{query} = $query;
    $io->close();

    # Lets create the query fasta file
    my $query_file = $seq_filename;
    my $seq = Bio::Seq->new(-seq=>$sequence, -id=> $id || "temp");
    $io = Bio::SeqIO->new(-format=>'fasta', -file=>">".$query_file);
    
    $io->write_seq($seq);
    $io->close();

    if (! -e $query_file) { die "Query file failed to be created."; }

    # get arguments to Run Bowtie2
    # print STDERR "DATABASE SELECTED: $db_id\n";
    
    my $basename = $c->config->{vigs_db_path};
    my $database = $db_id;
    my $database_fullpath = File::Spec->catfile($basename, $database);
    my $database_title = $db_id;
    
    # run bowtie2
    my $bowtie2_path = $c->config->{cluster_shared_bindir};
    
	# bowtie2 command
	# my @command = (File::Spec->catfile($bowtie2_path, "bowtie2"), 
	# 	" --threads 1", 
	# 	" --very-fast", 
	# 	" --no-head", 
	# 	" --omit-sec-seq",
	# 	" --end-to-end",
	# 	" -L ".$fragment_size, 
	# 	" -N 1", 
	# 	" -a", 
	# 	" -x ".$database_fullpath,
	# 	" -f",
	# 	" -U ".$query_file.".fragments",
	# 	" -S ".$query_file.".bt2.out",
	# );
	
    # print STDERR "Bowtie2 COMMAND: ".(join " ",@command)."\n";
    # my $err = system(@command);
	 
	# bowtie command allowing 2 missmatch
	my $err = system("$bowtie2_path/bowtie  --all -v 2 --threads 1 --seedlen $fragment_size --sam --sam-nohead $database_fullpath -f $query_file.fragments $query_file.bt2.out");
   

	if ($err) {
		$c->stash->{rest} = {error => "Bowtie execution failed"};
	} 
	else {
		$id = $urlencode{basename($seq_filename)};
		$c->stash->{rest} = {jobid =>basename($seq_filename),
							seq_length => length($sequence),
							db_name => $database_title,
		};
	}
}


sub get_expression_hash {
    my $expr_file = shift;
    
    my %expr_values;

    open (my $expr_fh, $expr_file);
    my @file = <$expr_fh>;
    
    # get header
    my $first_line = shift(@file);
    chomp($first_line);
    $first_line =~ s/\"//g;
    my @header = split(/\t/,$first_line);
    $expr_values{"header"} = \@header;

	# print "header: ".Dumper(@header)."\n";
    
    # save gene data
    foreach my $line (@file) {
	chomp($line);
	$line =~ s/\"//g;
	my @line_cols = split(/\t/, $line);
	my $gene_id = shift(@line_cols);
	
	$gene_id =~ s/\.\d//;
	$gene_id =~ s/\.\d//;
	
	$expr_values{$gene_id} = \@line_cols;
    }

    return \%expr_values
}

sub view :Path('/tools/vigs/view') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $sequence = $c->req->param("sequence");
    my $seq_filename = $c->req->param("id");
    my $fragment_size = $c->req->param("fragment_size") || 21;
    my $seq_fragment = $c->req->param("seq_fragment") || 300;
    my $missmatch = $c->req->param("missmatch") || 0;
    my $coverage = $c->req->param("targets") || 0;
    my $db = $c->req->param("database")||undef;
    my $expr_file = $c->req->param("expr_file") || undef;
    my $expr_hash = undef;
    my $status = $c->req->param("status") || 1;
    
    if (defined($expr_file)) {
		my $expr_dir = $c->generated_file_uri('expr_files', $expr_file);
		my $expr_path = $c->path_to($expr_dir);
    
		$expr_hash = get_expression_hash($expr_path);
		# print STDERR "hash header: ".Dumper($$expr_hash{"header"})."\n";
    }

    $seq_filename = File::Spec->catfile($c->config->{cluster_shared_tempdir}, $seq_filename);
    $seq_filename =~ s/\%2F/\//g;
    
    my $io = Bio::SeqIO->new(-file=>$seq_filename, -format=>'fasta');
    my $query = $io->next_seq();
    
    my %matches;
    my @queries = ();

    my $basename = $c->config->{vigs_db_path};
    my $database = $db;
    my $bdb_full_name = File::Spec->catfile($basename, $database);

    # send variables to VigsGraph
    my $vg = CXGN::Graphics::VigsGraph->new();
    $vg->bwafile($seq_filename.".bt2.out");
    $vg->fragment_size($fragment_size);
    $vg->seq_fragment($seq_fragment);
    $vg->query_seq($sequence);

    if (defined($expr_hash)) {
	$vg->expr_hash($expr_hash);
    }
    
    # parse Bowtie 2 result file
    if ($status == 1) {
        $vg->parse($missmatch);
    }

    
    # get best region and scores
    my @regions = [0,0,0,1,1,1];
    my @best_region = [1,1];
    my $seq_length = length($query->seq());
	
    if ($coverage == 0) { 
		$coverage = $vg->get_best_coverage;
	
		my $counter = 0;
		while (!$regions[1] || $regions[1] <= 0) {
			$counter++;
			@regions = $vg->longest_vigs_sequence($coverage, $seq_length);
		
			print STDERR "score: $regions[1], loop iteration: $counter, coverage: $coverage\n";
			
			if ($counter >= 3) {
				last;
			}
			if ($regions[1] <= 0) {
				$coverage = $coverage + 1;
			}
		}
	} 
	else {
		@regions = $vg->longest_vigs_sequence($coverage, $seq_length);
	}
	
	
    @best_region = [$regions[4], $regions[5]];
    
    if ($coverage == 0) {
	$coverage = 1;
    }
    
    # get si_rna coords and image height
    my $matches_AoA = $vg->get_matches();
    my $img_height = $vg->get_img_height();
    
    # get fasta for best sequence
    my $tmp_str="";
    $tmp_str = substr($query->seq(), $regions[4], $regions[5]-$regions[4]+1);
    my @seq60 = $tmp_str =~ /(.{1,60})/g;
    my $seq_str = join('<br />',@seq60);
   
    # add expression values to subjects names
    my $expr_msg;
    if (defined($$expr_hash{"header"})) {
	$expr_msg = [$vg->add_expression_values($expr_hash)];
    } else {
	$expr_msg = [$vg->subjects_by_match_count(0, $vg->matches())];
    }

    # return variables
    $c->stash->{rest} = {
						score => sprintf("%.2f",($regions[1]*100/$seq_fragment)/$coverage),
						coverage => $coverage,
						f_size => $seq_fragment,
						cbr_start => ($regions[4]+1),
						cbr_end => ($regions[5]+1),
						expr_msg => $expr_msg,
						ids => [ $vg->subjects_by_match_count($bdb_full_name, $vg->matches()) ],
						best_seq => $seq_str,
						query_seq => $query->seq(),
						all_scores => $regions[2],
						matches_aoa => $matches_AoA,
						missmatch => $missmatch,
						img_height => ($img_height+52)};
}

sub hash2param {
  my %args = @_;
  return join '&', map "$urlencode{$_}=$urlencode{$args{$_}}", distinct evens @_;
}


sub upload_expression_file_for_vigs : Path('/ajax/upload_expression_file') : ActionClass('REST') { }

sub upload_expression_file_for_vigs_POST : Args(0) {
    my ($self, $c) = @_;

    my $upload = $c->req->upload("expression_file");
    my $expr_file = undef;

    if (defined($upload)) {
	$expr_file = $upload->tempname;    
	$expr_file =~ s/\/tmp\///;
    
	my $expr_dir = $c->generated_file_uri('expr_files', $expr_file);
	my $final_path = $c->path_to($expr_dir);

	write_file($final_path, $upload->slurp);
    }
    
    $c->stash->{rest} = {
      expr_file => $expr_file,
      success => "1",
    };
}




1;
