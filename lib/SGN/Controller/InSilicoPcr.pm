
package SGN::Controller::InSilicoPcr;

use Moose;


use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }

sub AUTO { 
    my $self = shift;
    my $c = shift;
    SGN::Schema::BlastDb->dbpath($c->config->{blast_db_path});
}

sub index :Path('/tools/in_silico_pcr/') :Args(0) { 
  my $self = shift;
  my $c = shift;

  my $db_id = $c->req->param('db_id');

  my $seq = $c->req->param('seq');
  my $schema = $c->dbic_schema("SGN::Schema");
  
  my $group_rs = $schema->resultset("BlastDbGroup")->search( name => "Genome Sequences", { order_by=>'ordinal' });
  # my $group_rs = $schema->resultset("BlastDbGroup")->search( undef, { order_by=>'ordinal' });

  my $databases = {};
  my $dataset_groups = [];
  
  my $preselected_database = $c->config->{preselected_blastdb};
  my $preselected_category = '';
  
  # 224 is the database id for tomato cDNA ITAG 2.40 on production
  # $preselected_database = 224;
  
  if ($db_id) { 
    my $rs = $schema->resultset("BlastDb")->search( { blast_db_id => $db_id }, { join => 'blast_db_group' });
    
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



  $c->stash->{preselected_database} = $preselected_database;
  $c->stash->{preselected_category} = $preselected_category;
  $c->stash->{preload_id} = $c->req->param('preload_id');
  $c->stash->{preload_type} = $c->req->param('preload_type');

  $c->stash->{databases} = $databases;
  $c->stash->{dataset_groups} = $dataset_groups;
  
  $c->stash->{template} = '/tools/in_silico_pcr/in_silico_pcr.mas';
}


sub _reverse_complement{
	my $seq = shift;
	my $rev_seq = reverse $seq;
  $rev_seq =~ tr/ACGTacgt/TGCAtgca/;
  
	return $rev_seq;
}


sub run_pcr_blast :Path('/tools/pcr_results') :Args(0) {
  my ($self, $c) = @_;
  
  my @errors; #to store erros as they happen
  
  #processing the primers 
  my $min_primer_length = 15;

  my $fprimer = $c->req->param("fprimer");
  my $rprimer = $c->req->param("rprimer");
  my $productLength = $c->req->param("productLength");
  my $allowedMismatches = $c->req->param('allowedMismatches');
  my $frevcom = $c->req->param('frevcom'); #forward primer reverse complement
  my $rrevcom = $c->req->param('rrevcom'); #reverse primer reverse complement
  
  my $params = $c->req->params();
  # my $blast_db_id = $c->req->param('database');
  # my $matrix = $c->req->param('matrix');
  # my $evalue = $c->req->param('expect');
  # my $lc_filter = $c->req->param('filterq');
  
  #reverse complement if checked
  if ($frevcom){
  	$fprimer = _reverse_complement($fprimer);
  }
  if ($rrevcom){
  	$rprimer = _reverse_complement($rprimer);
  }

  # print STDERR "fprimer: $fprimer, rprimer: $rprimer\n";
  # print STDERR "DB id: $blast_db_id\n";

  #getting the length of the primers
  my $flength = length($fprimer);
  my $rlength = length($rprimer);

  
  
  #validating the primers input
  if  (!$fprimer){
      push ( @errors , "Forward Primer was not provided!\n");
  }
  elsif (length($fprimer) <= $min_primer_length ){
  	push ( @errors , "Forward Primer length should be at least $min_primer_length!\n");
  }
  elsif ($fprimer =~ /[^a-zA-Z]/g){
       push (  @errors , "Forward Primer Can only hold letters (no numbers are allowed)\n");
  }
  if (!$rprimer){
      push (  @errors , "Reverse Primer was not provided!\n");
  }

  elsif (length($rprimer) <= $min_primer_length ){
  	push ( @errors , "Reverse Primer length should be at least $min_primer_length!\n");
  }

  elsif ($rprimer =~ /[^a-zA-Z]/g){
       push (  @errors , "Reverse Primer Can only hold letters (no numbers are allowed)\n");
  }

  #validating productLength
  push (  @errors , "Max Product Length should be a positive digit\n")
  	if ($productLength <= 0 or $productLength !~ /^[\d]*$/g);

  #validating AllowedMismatches
  push (  @errors , "Allowed mismatches should be a positive digit\n")
  	if ($allowedMismatches < 0 or $allowedMismatches !~ /^[\d]*$/g);
  
  
  # return errors
  if (scalar (@errors) > 0){
    $c->stash->{errors} = join("<BR>" , @errors);
    $c->stash->{template} = '/tools/in_silico_pcr/insilicopcr_output.mas';
  }
  
  ##giving them a fasta format
  $fprimer = ">FORWARD-PRIMER\n$fprimer";
  $rprimer = ">REVERSE-PRIMER\n$rprimer";

  my $sequence = "$fprimer\n$rprimer\n";
  
  
  
  
  
  my $seq_count = 0;
  
  
  
  
  
  
    my $blast_tmp_output = $c->config->{cluster_shared_tempdir}."/blast";
    mkdir $blast_tmp_output if ! -d $blast_tmp_output;
	if ($sequence =~ /\>/) {
		$seq_count= $sequence =~ tr/\>/\>/;
	}

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
	     
    #  print STDERR "Parsing with bioperl... ";
    #  my $i = Bio::SeqIO->new(
    #      -format   => 'fasta',
    #      -file       => $seqfile,
    #      );
    #
    #  try {
    #      while ( my $s = $i->next_seq ) {
    #    $s->length or $c->throw(
    #        message  => 'Sequence '.encode_entities('"'.$s->id.'"').' is empty, this is not allowed by BLAST.',
    #        is_error => 0,
    #        );
    #      }
    #  } catch {
    #      print STDERR $@;
    #      die $_ if ref; #< throw it onward if it's an exception
    #      my $full_error = $_;
    #      if( /MSG:([^\n]+)/ ) {
    #    $_ = $1;
    #      }
    #      s/at \/[\-\w \/\.]+ line \d+.+//; # remove anything resembling backtraces
    #      $c->throw( message  => $_,
    #     is_error => 0,
    #     developer_message => $full_error,
    #    );
    #  };
    #
    #  $seq_count >= 1 or $c->throw( message => 'no sequence submitted, cannot run BLAST',
    #              is_error => 0,
    #              developer_message => Data::Dumper::Dumper({
    #            '$seq_count' => $seq_count,
    #            '$seq_filename' => $seqfile,
    #           }),
    # );
		
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
	 
   # maxhits =>
   # sub {
   #     my $h = $params->{maxhits} || 20;
   #     $h =~ s/\D//g; #only digits allowed
   #     return -b => $h;
   # },
   #
   # hits_list =>
   # sub {
   #     my $h = $params->{maxhits} || 20;
   #     $h =~ s/\D//g; #only digits allowed
   #     return -v => $h;
   # },
	 
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
	     return -p => "blastn";
	 },
	);

    print STDERR "BUILDING COMMAND...\n";
  
  
  
  
  
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
    
     my $job;
     eval { 
   	  $job = CXGN::Tools::Run->run_cluster(
   	    @command,
   	    { 
           temp_base => $blast_tmp_output,
           queue => $c->config->{'web_cluster_queue'},
           working_dir => $blast_tmp_output,
        
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
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  $c->stash->{template} = '/tools/in_silico_pcr/insilicopcr_output.mas';
}



1;
