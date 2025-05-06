
package SGN::Controller::AJAX::Blast;

use Moose;

use Bio::SeqIO;
use Config::Any;
use Data::Dumper;
use Try::Tiny;
use Tie::UrlEncoder; our %urlencode;
use File::Temp qw | tempfile |;
use File::Basename qw | basename |;
use File::Copy qw | copy |;
use File::Spec qw | catfile |;
use File::Slurp qw | read_file write_file |;
use File::NFSLock qw | uncache |;
use CXGN::Tools::Run;
use CXGN::Job;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/distinct evens/;
use CXGN::Blast::Parse;
use CXGN::Blast::SeqQuery;

use JSON::Any;
my $json = JSON::Any->new;

use Time::HiRes qw(gettimeofday tv_interval);

BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
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
    my $blast_tmp_output = $c->config->{cluster_shared_tempdir}."/cluster";
    mkdir $blast_tmp_output if ! -d $blast_tmp_output;
    if ($params->{sequence} =~ /\>/) {
    	$seq_count= $params->{sequence} =~ tr/\>/\>/;
    }

    print STDERR "SEQ COUNT = $seq_count\n";
    my ($seq_fh, $seqfile) = tempfile(
      "blast_XXXXXX",
      DIR=> $blast_tmp_output,
    );

#    my $jobid = basename($seqfile);

#    print STDERR "JOB ID CREATED: $jobid\n";
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("SGN::Schema", undef, $sp_person_id);

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

     # print STDERR "Done.\n";

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
		 
		 return -query => $seqfile;
		 
	      }
	 },


	 expect =>
	 sub {
	     $params->{evalue} =~ s/[^\d\.e\-\+]//gi; #can only be these characters
	     return -evalue =>  $params->{evalue} ? $params->{evalue} : 1;
	 },

	 word_size =>
	 sub {
	     print STDERR "WORD SIZE = $params->{word_size}\n";
	     $params->{word_size} =~ s/[^\d]//gi; # filter numbers only
	     return -word_size => $params->{word_size} ? $params->{word_size} : 11;
	 },

	 maxhits =>
	 sub {
	     my $h = $params->{maxhits} || 20;
	     $h =~ s/\D//g; #only digits allowed
	     return -max_hsps => $h;
	 },

	 # hits_list =>
	 # sub {
	 #     my $h = $params->{maxhits} || 20;
	 #     $h =~ s/\D//g; #only digits allowed
	 #     return -v => $h;
	 # },

	 filterq =>
	 sub {
	     if ($params->{program} eq "blastn") { 
		 return -dust  => $params->{filterq} ? 'yes' : 'no';
	     }
	     else { 
		 return ""; 
	     }
	     
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

	     return -db => $basename;
	 },

	 # program =>
	 # sub {
	 #     $params->{program} =~ s/[^a-z]//g; #only lower-case letters
	 #     return -p => $params->{program};
	 # },
	);


    if (! $params->{program} eq "blastn") { 
	$arg_handlers{matrix} = sub {
	    my $m = $params->{matrix};
	    $m =~ /^(BLOSUM|PAM)\d+$/
		or $c->throw( is_error => 0, message => "invalid matrix '$m'" );
	    return -M => $m;
	};
    }
    
    print STDERR "BUILDING COMMAND...\n";


    # build our command with our arg handlers
    #
    my @command = ($params->{program});
    foreach my $k (keys %arg_handlers) {

      print STDERR "evaluating $k...";
      my @x = $arg_handlers{$k}->();
      print STDERR "component:
      ", (join ",", @x)."\n";
      @command = (@command, @x);
    }

    # To get the proper format for gi sequences (CitrusGreening.org case)
    push(@command, '-show_gis');
#    push(@command, 'T');  # show_gis is a flag, no parameter needed

    print STDERR "COMMAND: ".join(" ", @command);
    print STDERR "\n";

    # save our prefs
    # $prefs->save;

    # now run the blast
    #


    my $job;
    my $jobid;
    my $blast_record;
    eval {
	my $config = { 
	    backend => $c->config->{backend},
	    submit_host => $c->config->{cluster_host},
	    temp_base => $blast_tmp_output,
	    queue => $c->config->{'web_cluster_queue'},
	    do_cleanup => 0,
	    # don't block and wait if the cluster looks full
	    max_cluster_jobs => 1_000_000_000,
	    
	};

  my $cmd_str = join(' ', @command);

  $blast_record = CXGN::Job->new({
      schema => $c->dbic_schema("Bio::Chado::Schema"),
      people_schema => $c->dbic_schema("CXGN::People::Schema"),
      sp_person_id => $sp_person_id,
      name => $params->{program}.' analysis',
      job_type => 'sequence_analysis',
      cmd => $cmd_str,
      cxgn_tools_run_config => $config,
      finish_logfile => $c->config->{job_finish_log}
  });

  $blast_record->update_status('submitted');

  push @command, $blast_record->generate_finish_timestamp_cmd();
	    
	$job = CXGN::Tools::Run->new($config);
	$job->do_not_cleanup(1);
	$job->run_cluster(@command);
   
	

   
    };

    if ($@) {
	print STDERR "An error occurred! $@\n";
  $blast_record->update_status('failed');
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
	
	
	print STDERR "Passing jobid code ".$job->jobid()."\n";
	$c->stash->{rest} = { jobid => $job->jobid(),
  	                      seq_count => $seq_count,
	};
    }
}


sub check : Path('/tools/blast/check') Args(1) {
    my $self = shift;
    my $c = shift;
    my $jobid = shift;

    # my $t0 = [gettimeofday]; #-------------------------- TIME CHECK

    my $cluster_tmp_dir = $c->get_conf('cluster_shared_tempdir')."/cluster";

    #my $jobid =~ s/\.\.//g; # prevent hacks
    my $job_file = File::Spec->catfile($cluster_tmp_dir, $jobid, "job");

    my $job = CXGN::Tools::Run->new( 
	{ 
	    job_file => $job_file, 
	    submit_host => $c->config->{cluster_host},
	    backend => $c->config->{backend},
	});

    if ( $job->alive()) {
      # my $t1 = [gettimeofday]; #-------------------------- TIME CHECK

      sleep(1);
      $c->stash->{rest} = { status => 'running', };

      #       my $t2 = [gettimeofday]; #-------------------------- TIME CHECK
      #
      # my $t1_t2 = tv_interval $t1, $t2;
      #       print STDERR "Job alive: $t1_t2\n";

      return;
    }
    else {

      # my $t3 = [gettimeofday]; #-------------------------- TIME CHECK

      # the job has finished
      # copy the cluster temp file back into "apache space"
      #
      my $result_file = $self->jobid_to_file($c, $jobid.".out");

      my $job_out_file = $job->out_file();

      print STDERR "Job out file = $job_out_file...\n";
      for( 1..10 ) {
  	    uncache($job_out_file);
  	    last if -f $job_out_file;
  	    sleep 1;
        #         my $t4 = [gettimeofday]; #-------------------------- TIME CHECK
        # my $t3_t4 = tv_interval $t3, $t4;
        #         print STDERR "Job not alive loop: $t3_t4\n";

      }
      # my $t5 = [gettimeofday]; #-------------------------- TIME CHECK

      -f $job_out_file or die "job output file ($job_out_file) doesn't exist";
      -r $job_out_file or die "job output file ($job_out_file) not readable";

      # my $t6 = [gettimeofday]; #-------------------------- TIME CHECK

      # You may wish to provide a different output file to send back
      # rather than STDOUT from the job.  Use the out_file_override
      # parameter if this is the case.
      #my $out_file = $out_file_override || $job->out_file();
      # system("ls $blast_tmp_output 2>&1 >/dev/null");

      # my $t7 = [gettimeofday]; #-------------------------- TIME CHECK

      # system("ls $c->{config}->{cluster_shared_tempdir} 2>&1 >/dev/null");
      print STDERR "Copying result file to website tempdir...\n";
      copy($job_out_file, $result_file) or die "Can't copy result file '$job_out_file' to $result_file ($!)";

      # my $t8 = [gettimeofday]; #-------------------------- TIME CHECK

    	#clean up the job tempfiles
      #	CXGN::Tools::Run->cleanup($jobid);

      # my $t9 = [gettimeofday]; #-------------------------- TIME CHECK

    	#also delete the job file

      #       my $t10 = [gettimeofday]; #-------------------------- TIME CHECK
      #
      # my $t5_t6 = tv_interval $t5, $t6;
      # my $t6_t7 = tv_interval $t6, $t7;
      # my $t7_t8 = tv_interval $t7, $t8;
      # my $t8_t9 = tv_interval $t8, $t9;
      # my $t9_t10 = tv_interval $t9, $t10;
      #
      # my $t3_t10 = tv_interval $t3, $t10;
      # my $t0_t10 = tv_interval $t0, $t10;
      #
      #       print STDERR "check 5-6 interval: $t5_t6\n";
      #       print STDERR "check 6-7 interval: $t6_t7\n";
      #       print STDERR "check 7-8 interval: $t7_t8\n";
      #       print STDERR "check 8-9 interval: $t8_t9\n";
      #       print STDERR "check 9-10 interval: $t9_t10\n";
      #
      #       print STDERR "Job not alive (else): $t3_t10\n";
      #       print STDERR "CHECK SUB TIME: $t0_t10\n";


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

    # my $t0 = [gettimeofday]; #-------------------------- TIME CHECK

    my $format = $c->req->param('format');
    my $db_id = $c->req->param('db_id');

    my $result_file = $self->jobid_to_file($c, $jobid.".out");
    my $blast_tmp_output = $c->get_conf('cluster_shared_tempdir')."/cluster";

    # system("ls $blast_tmp_output 2>&1 >/dev/null");
    # system("ls ".($c->config->{cluster_shared_tempdir})." 2>&1 >/dev/null");
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("SGN::Schema", undef, $sp_person_id);
    my $db = $schema->resultset("BlastDb")->find($db_id);
    if (!$db) { die "Can't find database with id $db_id"; }
    my $parser = CXGN::Blast::Parse->new();
    my $parsed_data = $parser->parse($c, $format, $result_file, $db);

    # my $t1 = [gettimeofday]; #-------------------------- TIME CHECK
    # my $t0_t1 = tv_interval $t0, $t1;
    # print STDERR "GET RESULT SUB TIME: $t0_t1\n";

    $c->stash->{rest} = $parsed_data; # { blast_report => '<pre>'.(join("\n", read_file($parsed_file))).'</pre>', };
}




sub render_canvas_graph : Path('/tools/blast/render_graph') Args(1) {
    my $self = shift;
    my $c = shift;
    my $jobid = shift;
    my $db_id = $c->req->param('db_id');

    my $file = $self->jobid_to_file($c, $jobid.".out");
    my $blast_tmp_output = $c->get_conf('cluster_shared_tempdir')."/cluster";

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("SGN::Schema", undef, $sp_person_id);
    my $bdb = $schema->resultset("BlastDb")->find($db_id);
    if (!$bdb) { die "Can't find database with id $db_id"; }


    my $jbrowse_path = $c->config->{jbrowse_path};;
    # my $db_id = $bdb->blast_db_id();
    my $jbr_src = $bdb->jbrowse_src();

    my $query = "";
    my $subject = "";
    my $id = 0.0;
    my $aln = 0;
    my $qstart = 0;
    my $qend = 0;
    my $sstart = 0;
    my $send = 0;
    my $evalue = 0.0;
    my $score = 0;
    my $desc = "";

    my $one_hsp = 0;
    my $start_aln = 0;
    my $append_desc = 0;
    my $query_line_on = 0;
    my $query_length = 0;

    my @res_html;
    my @aln_html;
    push(@aln_html, "<br><pre>");

    # variables for the canvas graph
    my @json_array;

    open (my $blast_fh, "<", $file);

    push(@res_html, "<table id=\"blast_table\" class=\"table\">");
    push(@res_html, "<tr><th>SubjectId</th><th>id%</th><th>Aln</th><th>evalue</th><th>Score</th><th>Description</th></tr>");

    while (my $line = <$blast_fh>) {
      chomp($line);

      $line =~ s/lcl\|//g;
      
      if ($line =~ /Query\=\s*(\S+)/) {
        $query = $1;
        unshift(@res_html, "<center><h3>".$query." vs ".$bdb->title()."</h3></center>");
        $query_line_on = 1;
      }

      if ($query_line_on && $line =~ /Length=(\d+)/) {
	  $query_length = $1;
	  print STDERR "Query length = $query_length\n";

      }

      if ($append_desc) {
        if ($line =~ /\w+/) {
          my $new_desc_line = $line;
          $new_desc_line =~ s/\s+/ /g;
          $desc .= $new_desc_line;
        }
        else {
          $append_desc = 0;
        }
      }

      if ($line =~ /^>/) {
        $start_aln = 1;
        $append_desc = 1;
	$query_line_on = 0;
	
        if ($subject) {
          my $jbrowse_url = _build_jbrowse_url($jbr_src,$subject,$sstart,$send,$jbrowse_path);
          ($sstart,$send) = _check_coordinates($sstart,$send);

          push(@res_html, "<tr><td><a id=\"$subject\" class=\"blast_match_ident\" href=\"/tools/blast/match/show?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" onclick=\"return resolve_blast_ident( '$subject', '$jbrowse_url', '/tools/blast/match/show?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send', null )\">$subject</a></td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");

          if (length($desc) > 150) {
            $desc = substr($desc,0,150)." ...";
          }

          my %description_hash;

          $description_hash{"name"} = $subject;
          $description_hash{"id_percent"} = $id;
          $description_hash{"score"} = $score;
          $description_hash{"description"} = $desc;
          $description_hash{"qstart"} = $qstart;
          $description_hash{"qend"} = $qend;
	  print STDERR "HSPS: ".Dumper(\%description_hash);
          push(@json_array, \%description_hash);

        }
        $subject = "";
        $id = 0.0;
        $aln = 0;
        $qstart = 0;
        $qend = 0;
        $sstart = 0;
        $send = 0;
        $evalue = 0.0;
        $score = 0;
        $desc = "";
        $one_hsp = 0;

        if ($line =~ /^>(\S+)\s*(.*)/) {
          $subject = $1;
          $desc = $2;
          # print STDERR "subject: $subject\n";
        }
      }


      if ($line =~ /Score\s*=/ && $one_hsp == 1) {
        my $jbrowse_url = _build_jbrowse_url($jbr_src,$subject,$sstart,$send,$jbrowse_path);
        ($sstart,$send) = _check_coordinates($sstart,$send);

        push(@res_html, "<tr><td><a id=\"$subject\" class=\"blast_match_ident\" href=\"/tools/blast/match/show?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" onclick=\"return resolve_blast_ident( '$subject', '$jbrowse_url', '/tools/blast/match/show?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send', null )\">$subject</a></td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");

        if (length($desc) > 150) {
          $desc = substr($desc,0,150)." ...";
        }

        my %description_hash;

        $description_hash{"name"} = $subject;
        $description_hash{"id_percent"} = $id;
        $description_hash{"score"} = $score;
        $description_hash{"description"} = $desc;
        $description_hash{"qstart"} = $qstart;
        $description_hash{"qend"} = $qend;

	print STDERR "FOUND HSP: ".Dumper(\%description_hash);
	
        push(@json_array, \%description_hash);

        $id = 0.0;
        $aln = 0;
        $qstart = 0;
        $qend = 0;
        $sstart = 0;
        $send = 0;
        $evalue = 0.0;
        $score = 0;
      }

      if ($line =~ /Score\s*=\s*([\d\.]+)/) {
        $score = $1;
        $one_hsp = 1;
        $append_desc = 0;
      }


      if ($line =~ /Expect\s*=\s*([\d\.\-e]+)/) {
        $evalue = $1;
      }

      if ($line =~ /Identities\s*=\s*(\d+)\/(\d+)/) {
        my $aln_matched = $1;
        my $aln_total = $2;
        $aln = "$aln_matched/$aln_total";
        $id = sprintf("%.2f", $aln_matched*100/$aln_total);
      }

      if (($line =~ /^Query\:?\s+(\d+)/) && ($qstart == 0)) {
        $qstart = $1;
      }
      if (($line =~ /^Sbjct\:?\s+(\d+)/) && ($sstart == 0)) {
        $sstart = $1;
      }

      if (($line =~ /^Query\:?/) && ($line =~ /(\d+)\s*$/)) {
        $qend = $1;
      }
      if (($line =~ /^Sbjct\:?/) && ($line =~ /(\d+)\s*$/)) {
        $send = $1;
      }

      if ($start_aln) {
        push(@aln_html, $line);
      }


    } # while_end


    my $jbrowse_url = _build_jbrowse_url($jbr_src,$subject,$sstart,$send,$jbrowse_path);
    ($sstart,$send) = _check_coordinates($sstart,$send);

    push(@res_html, "<tr><td><a id=\"$subject\" class=\"blast_match_ident\" href=\"/tools/blast/match/show?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send\" onclick=\"return resolve_blast_ident( '$subject', '$jbrowse_url', '/tools/blast/match/show?blast_db_id=$db_id;id=$subject;hilite_coords=$sstart-$send', null )\">$subject</a></td><td>$id</td><td>$aln</td><td>$evalue</td><td>$score</td><td>$desc</td></tr>");

    push(@res_html, "</table>");



    if (length($desc) > 150) {
      $desc = substr($desc,0,150)." ...";
    }

    my %description_hash;

    $description_hash{"name"} = $subject;
    $description_hash{"id_percent"} = $id;
    $description_hash{"score"} = $score;
    $description_hash{"description"} = $desc;
    $description_hash{"qstart"} = $qstart;
    $description_hash{"qend"} = $qend;
    push(@json_array, \%description_hash);
    
    
    
    
    my $prereqs = <<EOJS;

        <div class="modal fade" id="xref_menu_popup" role="dialog">
          <div class="modal-dialog">

            <!-- Modal content-->
            <div class="modal-content">
              <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal">&times;</button>
                <h4 id="match_name" class="modal-title">Match Information</h4>
              </div>
              <div class="modal-body">
	      <dl>
	      <dt>Sequence match</dt>
                    <dd>
		    <div style="margin: 0.5em 0"><a class="match_details" href="" target="_blank">View matched sequence</a></div>
		    </dd>
	      <dt> JBrowse match </dt>
		   <dd>
                      <div id="jbrowse_div" style="display:none"><a id="jbrowse_link" href="" target="_blank">View in genome context</a></div>
                    </dd>
		    <dt>Genome Feature match</dt>
		    <dd class="subject_sequence_xrefs">
                    </dd>
                </dl>
              </div>
            </div>
  
          </div>
        </div>


        <script>
          function resolve_blast_ident( id, jbrowse_url, match_detail_url, identifier_url ) {
    
            var popup = jQuery( "#xref_menu_popup" );
    
            jQuery('#match_name').html( id );
    
            popup.find('a.match_details').attr( 'href', match_detail_url );
            popup.find('#jbrowse_link').attr( 'href', jbrowse_url );
    
            if (jbrowse_url) {
              popup.find('#jbrowse_div').css( 'display', 'inline' );
            }
    
            // look up xrefs for overall subject sequence
            var subj = popup.find('.subject_sequence_xrefs');
    
            subj.html( '<img src="/img/throbber.gif" /> searching ...' );
            subj.load( '/api/v1/feature_xrefs?q='+id );
    
            popup.modal("show");

            return false;
          }
        </script>

EOJS
    
  
  push(@aln_html, "</pre></div><br>");
  my $blast_table = join('', @res_html);
  my $aln_text = join('<br>', @aln_html);
  
    
  $c->stash->{rest} = {
    sgn_html => $blast_table."<br>".$aln_text,
    desc_array => \@json_array,
    sequence_length => $query_length,
    prereqs => $prereqs
  };
  
}




sub _build_jbrowse_url {
  my $jbr_src = shift;
  my $subject = shift;
  my $sstart = shift;
  my $send = shift;
  my $jbrowse_path = shift;

  my $jbrowse_url = "";

  if ($jbr_src) {
    if ($jbr_src =~ /(.+)_gene/) {
      $jbrowse_url = $jbrowse_path."/".$1."&loc=".$subject."&tracks=DNA,gene_models";
    }
    elsif ($jbr_src =~ /(.+)_genome/) {
      $jbrowse_url = $jbrowse_path."/".$1."&loc=".$subject."%3A".$sstart."..".$send."&tracks=DNA,gene_models";
    }
  }

  return $jbrowse_url;
}

sub _check_coordinates {
  my $tmp_start = shift;
  my $tmp_end = shift;

  my $final_start = $tmp_start;
  my $final_end = $tmp_end;

  if ($tmp_start > $tmp_end) {
    $final_start = $tmp_end;
    $final_end = $tmp_start;
  }

  return ($final_start, $final_end);
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

	my $fs = Bio::BLAST2::Database->open(full_file_basename => "$blastdb_path",);

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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("SGN::Schema", undef, $sp_person_id);
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