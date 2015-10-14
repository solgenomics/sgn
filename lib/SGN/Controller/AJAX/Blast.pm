
package SGN::Controller::AJAX::Blast;

use Moose;

use Bio::SeqIO;
use Config::Any;
use Data::Dumper;
use Storable qw | nstore retrieve |;
use Try::Tiny;
use Tie::UrlEncoder; our %urlencode;
use File::Temp qw | tempfile |;
use File::Basename qw | basename |;
use File::Copy qw | copy |;
use File::Spec qw | catfile |;
use File::Slurp qw | read_file write_file |;
use File::NFSLock qw | uncache |;
use CXGN::Tools::Run;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/distinct evens/;
use CXGN::Blast::Parse;
use CXGN::Blast::SeqQuery;

BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub run : Path('/tools/blast/run') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params();

    my $input_query = CXGN::Blast::SeqQuery->new();
	
    my $valid = $input_query->validate($c, $params->{input_options}, $params->{sequence});
    
    if ($valid ne "OK") { 
	$c->stash->{rest} = { error => "Your input contains illegal characters. Please verify your input." };
	return;
    }
	
    $params->{sequence} = $input_query->process($c, $params->{input_options}, $params->{sequence});

    # print STDERR "SEQUENCE now : ".$params->{sequence}."\n";
	
	if ($params->{input_options} eq 'autodetect') {
		my $detected_type = $input_query->autodetect_seq_type($c, $params->{input_options}, $params->{sequence});
		
		# print STDERR "SGN BLAST detected your sequence is: $detected_type\n";
		
		# create a hash with the valid options =1 and check and if result 0 return error
		my %blast_seq_db_program = (
			nucleotide => {
				nucleotide => {
					blastn => 1,
					tblastx => 1,
				},
				protein => {
					blastx => 1,
				},
			},
			protein => {
				protein => {
					blastp => 1,
				},
				nucleotide => {
					tblastn => 1,
				},
			},
		);

		if (!$blast_seq_db_program{$detected_type}{$params->{db_type}}{$params->{program}}) {
			$c->stash->{rest} = { error => "the program ".$params->{program}." can not be used with a ".$detected_type." sequence (autodetected) and a ".$params->{db_type}." database.\n\nPlease, use different options and disable the autodetection of the query type if it is wrong." };
			return;
		}
	}
	
    my $seq_count = 1;
    my $blast_tmp_output = $c->config->{cluster_shared_tempdir}."/blast";
    mkdir $blast_tmp_output if ! -d $blast_tmp_output;
	if ($params->{sequence} =~ /\>/) {
		$seq_count= $params->{sequence} =~ tr/\>/\>/;
	}
    print STDERR "SEQ COUNT = $seq_count\n";
    my ($seq_fh, $seqfile) = tempfile( 
	"blast_XXXXXX",
	DIR=> $blast_tmp_output,
	);
    
    my $jobid = basename($seqfile);

    print STDERR "JOB ID CREATED: $jobid\n";

    my $schema = $c->dbic_schema("SGN::Schema");

    my %arg_handlers =
	(

	 sequence =>
	 sub {
	     my $sequence = $params->{sequence};
	      if( $sequence ) {
	      	 $sequence =~ s/^\s+|\s+$|\n\s*\n//g; #< trim out leading and trailing whitespace and blank lines
	     # 	 if ($sequence !~ /^\s*>/) {
	      #	     $sequence = ">WEB-USER-SEQUENCE (Unknown)\n$sequence";
	      #	 }
	      #	 $sequence .= "\n"; #< add a final newline
	 
	         print STDERR "Opening file for sequence ($seqfile)... ";
		 open(my $FH, ">", $seqfile) || die "Can't open file for query ($seqfile)\n";
		 print $FH $sequence if $sequence;
		 close($FH);
		 
		 print STDERR "Done.\n";
		 
#	     if(my $file_upload = $page->get_upload) {
#		 if ( my $fh = $file_upload->fh ) {
#		     print $seq_fh $_ while <$fh>;
#		 }
#	     }
	     
		 print STDERR "Parsing with bioperl... ";
		 my $i = Bio::SeqIO->new(
		     -format   => 'fasta',
		     -file       => $seqfile,
		     );
		 
		 try {
		     while ( my $s = $i->next_seq ) {
			 $s->length or $c->throw(
			     message  => 'Sequence '.encode_entities('"'.$s->id.'"').' is empty, this is not allowed by BLAST.',
			     is_error => 0, 
			     );
		     }
		 } catch {
		     print STDERR $@;
		     die $_ if ref; #< throw it onward if it's an exception
		     my $full_error = $_;
		     if( /MSG:([^\n]+)/ ) {
			 $_ = $1;
		     }
		     s/at \/[\-\w \/\.]+ line \d+.+//; # remove anything resembling backtraces
		     $c->throw( message  => $_,
				is_error => 0,
				developer_message => $full_error,
			 );
		 };
	     
		 $seq_count >= 1 or $c->throw( message => 'no sequence submitted, cannot run BLAST',
					       is_error => 0,
					       developer_message => Data::Dumper::Dumper({
						   '$seq_count' => $seq_count,
						   '$seq_filename' => $seqfile,
							}),
		);
		
		return -i => $seqfile;
	      }
	 },
	 
	 matrix =>
	 sub {
	     my $m = $params->{matrix};
	     $m =~ /^(BLOSUM|PAM)\d+$/
		 or $c->throw( is_error => 0, message => "invalid matrix '$m'" );
	     return -M => $m;
	 },
	 
	 
	 expect =>
	 sub {
	     $params->{evalue} =~ s/[^\d\.e\-\+]//gi; #can only be these characters
	     return -e =>  $params->{evalue} ? $params->{evalue} : 1;
	 },
	 
	 maxhits =>
	 sub {
	     my $h = $params->{maxhits} || 20;
	     $h =~ s/\D//g; #only digits allowed
	     return -b => $h;
	 },
	 
	 hits_list =>
	 sub {
	     my $h = $params->{maxhits} || 20;
	     $h =~ s/\D//g; #only digits allowed
	     return -v => $h;
	 },
	 
	 filterq =>
	 sub {
	     return -F => $params->{filterq} ? 'T' : 'F';
	 },
	 
	 # outformat =>
	 # sub {
	 #     $params->{outformat} =~ s/\D//g; #only digits allowed
	 #     return -m => $params->{outformat};
	 # },
	 
	 database => 
                  
	 sub {
	     my $bdb = $schema->resultset("BlastDb")->find($params->{database} )
		 or die "could not find bdb with file_base '$params->{database}'";
	     
	     my $basename = File::Spec->catfile($c->config->{blast_db_path},$bdb->file_base());
	     #returns '/data/shared/blast/databases/genbank/nr'
	     #remember the ID of the blast db the user just blasted with
	     
	     return -d => $basename;  
	 },
	 
	 program =>
	 sub {
	     $params->{program} =~ s/[^a-z]//g; #only lower-case letters
	     return -p => $params->{program};
	 },
	);

    print STDERR "BUILDING COMMAND...\n";
	
	
    # build our command with our arg handlers
    #
    my @command = ('blastall');
    foreach my $k (keys %arg_handlers) { 
	
	print STDERR "evaluating $k..."; 
	my @x = $arg_handlers{$k}->(); 
	print STDERR "component:
  ", (join ",", @x)."\n"; 
	@command = (@command, @x);
    } 
	
    print STDERR "COMMAND: ".join(" ", @command);
    print STDERR "\n";
    
    # save our prefs
    # $prefs->save;
    
    # now run the blast
    #

  my $job;
  eval { 
	  $job = CXGN::Tools::Run->run_cluster(
	    @command,
	    { 
        temp_base => $blast_tmp_output,
        queue => $c->config->{'web_cluster_queue'},
        working_dir => $blast_tmp_output,
        
        # temp_base => $c->config->{'cluster_shared_tempdir'},
        # queue => $c->config->{'web_cluster_queue'},
        # working_dir => $c->config->{'cluster_shared_tempdir'},

		    # don't block and wait if the cluster looks full
		    max_cluster_jobs => 1_000_000_000,
	    }
	  );
	 
	 print STDERR "Saving job state to $seqfile.job for id ".$job->job_id()."\n";

	 $job->do_not_cleanup(1);

	 nstore( $job, $seqfile.".job" )
	     or die 'could not serialize job object';

    };

    if ($@) { 
	print STDERR "An error occurred! $@\n";
	$c->stash->{rest} = { error => $@ };
    }
    else { 
		# write data in blast.log
		my $blast_log_path = $c->config->{blast_log};
		my $blast_log_fh;
		if (-e $blast_log_path) {
			open($blast_log_fh, ">>", $blast_log_path) || print STDERR "cannot create $blast_log_path\n";
		} else {
			open($blast_log_fh, ">", $blast_log_path) || print STDERR "cannot open $blast_log_path\n";
			print $blast_log_fh "Seq_num\tDB_id\tProgram\teval\tMaxHits\tMatrix\tDate\n";
		}
		print $blast_log_fh "$seq_count\t".$params->{database}."\t".$params->{program}."\t".$params->{evalue}."\t".$params->{maxhits}."\t".$params->{matrix}."\t".localtime()."\n";
		
		
		print STDERR "Passing jobid code ".(basename($jobid))."\n";
		$c->stash->{rest} = { jobid =>  basename($jobid), 
	                      seq_count => $seq_count, 
		};
    }
}


sub check : Path('/tools/blast/check') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $jobid = shift;
    
    my $blast_tmp_output = $c->get_conf('cluster_shared_tempdir')."/blast";
    
    #my $jobid =~ s/\.\.//g; # prevent hacks
    my $job = retrieve($blast_tmp_output."/".$jobid.".job");
    
    if ( $job->alive ){
	sleep(1);
	$c->stash->{rest} = { status => 'running', };
	return;
    }
    else {
	# the job has finished
	# copy the cluster temp file back into "apache space"
	#
	my $result_file = $self->jobid_to_file($c, $jobid.".out");

	my $job_out_file = $job->out_file();
	for( 1..10 ) {
	    uncache($job_out_file);
	    last if -f $job_out_file;
	    sleep 1;
	}
	
	-f $job_out_file or die "job output file ($job_out_file) doesn't exist";
	-r $job_out_file or die "job output file ($job_out_file) not readable";

	# You may wish to provide a different output file to send back
	# rather than STDOUT from the job.  Use the out_file_override
	# parameter if this is the case.
	#my $out_file = $out_file_override || $job->out_file();
	system("ls $blast_tmp_output 2>&1 >/dev/null");
  # system("ls $c->{config}->{cluster_shared_tempdir} 2>&1 >/dev/null");
	copy($job_out_file, $result_file)
	    or die "Can't copy result file '$job_out_file' to $result_file ($!)";
	
	#clean up the job tempfiles
	$job->cleanup();
	
	#also delete the job file
	
	$c->stash->{rest} = { status => "complete" };
    }
}

# fetch some html/js required for displaying the parse report
# sub get_prereqs : Path('/tools/blast/prereqs') Args(1) { 
#     my $self = shift;
#     my $c = shift;
#     my $jobid = shift;

#     my $format=$c->req->param('format');
#     my $parser = CXGN::Blast::Parse->new();
#     my $prereqs = $parser->prereqs($format);
#     $c->stash->{rest} = { prereqs => $prereqs };
# }

sub get_result : Path('/tools/blast/result') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $jobid = shift;
    
    my $format = $c->req->param('format');
    my $db_id = $c->req->param('db_id');
    
    my $result_file = $self->jobid_to_file($c, $jobid.".out");
    my $blast_tmp_output = $c->get_conf('cluster_shared_tempdir')."/blast";
    
    system("ls $blast_tmp_output 2>&1 >/dev/null");
    # system("ls ".($c->config->{cluster_shared_tempdir})." 2>&1 >/dev/null");

    my $schema = $c->dbic_schema("SGN::Schema");
    my $db = $schema->resultset("BlastDb")->find($db_id);
    if (!$db) { die "Can't find database with id $db_id"; }
    my $parser = CXGN::Blast::Parse->new();
    my $parsed_data = $parser->parse($c, $format, $result_file, $db);
    
    $c->stash->{rest} = $parsed_data; # { blast_report => '<pre>'.(join("\n", read_file($parsed_file))).'</pre>', };
}


sub jobid_to_file { 
    my $self = shift;
    my $c = shift;
    my $jobid = shift;
    return File::Spec->catfile($c->config->{basepath}, $c->tempfiles_subdir('blast'), "$jobid");
    
}

sub search_gene_ids { 
	my $ids_array = shift;
	my $blastdb_path = shift;
	my @ids = @{$ids_array};
	my @output_seqs;
	
	my $fs = Bio::BLAST::Database->open(full_file_basename => "$blastdb_path",);
	
	foreach my $input_string (@ids) {
		
		if ($fs->get_sequence($input_string)) {
			my $seq_obj = $fs->get_sequence($input_string);
			my $seq = $seq_obj->seq();
			my $id = $seq_obj->id();
			my $desc = $seq_obj->desc();
			my $new_seq = "";
		
			for (my $i=0; $i<length($seq); $i=$i+60) {
				$new_seq = $new_seq.substr($seq,$i,60)."<br>"; 
			}
		
			push(@output_seqs, ">$id $desc<br>$new_seq");
		}
	}
	return join('', @output_seqs);
}

sub search_desc : Path('/tools/blast/desc_search/') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my @ids;
    my $schema = $c->dbic_schema("SGN::Schema");
    my $params = $c->req->params();
    my $input_string = $params->{blast_desc};
    my $db_id = $params->{database};
    
    my $bdb = $schema->resultset("BlastDb")->find($db_id) || die "could not find bdb with file_base $db_id";
    my $blastdb_path = File::Spec->catfile($c->config->{blast_db_path}, $bdb->file_base());
    
    my $grepcmd = "grep -i \"$input_string\" $blastdb_path \| sed 's/>//' \| cut -d ' ' -f 1";	
    my $output_seq = `$grepcmd`;
    my $output_seqs;
    
    if ($output_seq) {
      @ids = split(/\n/, $output_seq);	
      $output_seqs = search_gene_ids(\@ids,$blastdb_path);
    } 
    else {
      $output_seqs = "There were not results for your search\n";
    }
    $c->stash->{rest} = {output_seq => "$output_seqs"};
}

1;
