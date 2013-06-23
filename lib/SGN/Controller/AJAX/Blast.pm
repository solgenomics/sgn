
package SGN::Controller::AJAX::Blast;

use Moose;

use Bio::SeqIO;
use Data::Dumper;
use Tie::UrlEncoder; our %urlencode;

use CXGN::Tools::Run;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/distinct evens/;


BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub init_run : Path('/tools/blast/init') Args(0) { 
    my $self = shift;
    my $c = shift;

    my ($seq_fh, $seqfile) = tempfile( "seqXXXXXX",
					    DIR=> $c->get_conf('cluster_shared_tempdir'),
	);

    my $jobid = basename($seqfile);
    $c->stash->{rest} = { jobid =>  basename($jobid), };
    

}

sub run : Path('/tools/blast/run') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $jobid = shift;

    my %params = $c->req->params();

    my $seqfile =  $c->get_conf('cluster_shared_tempdir')."/".$jobid;

    my $seq_count;
    
    my %arg_handlers =
	(
	 interface_type =>
	 sub {()}, #< does nothing to blast command
	 
	 sequence =>
	 sub {
	     my $sequence = $params{sequence};
	     if( $sequence ) {
		 $sequence =~ s/^\s+|\s+$|\n\s*\n//g; #< trim out leading and trailing whitespace and blank lines
		 if ($sequence !~ /^\s*>/) {
		     $sequence = ">WEB-USER-SEQUENCE (Unknown)\n$sequence";
		 }
		 $sequence .= "\n"; #< add a final newline
	     }
	         
	     #make a tempfile that has our sequence(s) in it
	     #my ($seq_fh, $seq_filename) = tempfile( "seqXXXXXX",
	#					     DIR=> $c->get_conf('cluster_shared_tempdir'),
	#	 );
	     open(my $FH, ">", $seqfile) || die "Can't open file for query ($seqfile)\n";
	     print $FH $sequence if $sequence;
	     close($FH);
#	     if(my $file_upload = $page->get_upload) {
#		 if ( my $fh = $file_upload->fh ) {
#		     print $seq_fh $_ while <$fh>;
#		 }
#	     }
	     

#	     seek $seq_fh,0,0; #< rewind the filehandle
	     #open($FH, "<", $file) || die "Can't open query file $file for reading\n";
	     # go over file, checking for empty seqs or other badness
	     # also, count the number of seqs in the file
	     my $i = Bio::SeqIO->new(
		 -format   => 'fasta',
		 -file       => $seqfile,
		 );

	     try {
		 while ( my $s = $i->next_seq ) {
		     $seq_count++ if $s->length;
		     validate_seq( $s, $params{program} );
		     $s->length or $c->throw(
			 message  => 'Sequence '.encode_entities('"'.$s->id.'"').' is empty, this is not allowed by BLAST.',
			 is_error => 0, 
			 );
		 }
	     } catch {
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
	     
	     return -i => $seqfile,
	 },
	 
	 matrix =>
	 sub {
	     my $m = $params{matrix};
	     $m =~ /^(BLOSUM|PAM)\d\d$/
		 or $c->throw( is_error => 0, message => "invalid matrix '$m'" );
	     return -M => $m;
	 },
	 
	 
	 expect =>
	 sub {
	     $params{expect} =~ s/[^\d\.e\-\+]//gi; #can only be these characters
	     return -e => $params{expect} || 1
	 },
	 
	 maxhits =>
	 sub {
	     my $h = $params{maxhits} || 100;
	     $h =~ s/\D//g; #only digits allowed
	     return -b => $h
	 },
	 
	 filterq =>
	 sub {
	     return -F => $params{filterq} ? 'T' : 'F'
	 },
	 
	 outformat =>
	 sub {
	     $params{outformat} =~ s/\D//g; #only digits allowed
	     return -m => $params{outformat}
	 },
	 
	 database =>
	 sub {
	     #my ($bdb) = CXGN::BlastDB->search( file_base => $params{database} )
	     #or die "could not find bdb with file_base '$params{database}'";
	     
	     #     warn "setting pref last_blast_db_fil
	     #database object for specific ID_No
	     my $bdb = CXGN::BlastDB->from_id($params{database});
	     my $basename = $bdb->full_file_basename;
	     #returns '/data/shared/blast/databases/genbank/nr'
	     #remember the ID of the blast db the user just blasted with
	     
	     return -d => $basename;
	 },
	 
	 program =>
	 sub {
	     $params{program} =~ s/[^a-z]//g; #only lower-case letters
	     return -p => $params{program}
	 },
	 
	 output_graphs =>
	 sub {()}, #< no effect on command line
	 
	 file => sub {},
	 #sub {warn "GOT FILE $params{file}\n"; ()},
	);
    
#get all the params from our request
#    @params{keys %arg_handlers} = $page->get_arguments(keys %arg_handlers);
    
#build our command with our arg handlers
    my @command =
	( 'blastall',
	  map $_->(), values %arg_handlers
	);
    
# save our prefs
 #   $prefs->save;
    
#check some specific error conditions
#   multiple sequences in given to simple BLAST
#    if($params{interface_type} eq 'simple' && $seq_count > 1) {
	
#	$c->throw( is_error => 0,
#		   message  => <<EOM,
#		   The Simple BLAST interface is limited to one query sequence.  Please
#use the Advanced BLAST for multiple query sequences.
#EOM
 #           );


    
    #now run the blast
    my $job = CXGN::Tools::Run->run_cluster(
	@command,
	{ 
	    temp_base => $c->get_conf('cluster_shared_tempdir'),
	    queue => $c->get_conf('web_cluster_queue'),
	    working_dir => $c->get_conf('cluster_shared_tempdir'),
	    # don't block and wait if the cluster looks full
	    max_cluster_jobs => 1_000_000_000,
	}
	);
    
#$job->do_not_cleanup(1);
    
    while ($job->alive()) { 
	sleep(1);
	
    }
    
    my $apache_temp = $c->config->{tempfiles_subdir} ."/blast/$jobid";

    system("ls /data/prod/tmp 2>&1 >/dev/null");
    copy($job->out_file, $apache_temp)
        or die "Can't copy result file '$apache_temp' to temp dir $!";
        $job->cleanup();

    # the existence of the following file signals we are done
    touch $apache_temp.".done";
}


sub check : Path('/tools/blast/check') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $jobid = shift;

    if (-e $c->config->{tempfiles_subdir}."/blast/$jobid".".done") { 
	return { complete => 1 };
    }
    else { 
	return { complete => 0 };
    }
}


sub get_result : Path('/tools/blast/result') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $jobid = shift;

    my $format = $c->req->param('format');

    my $result_file = $c->req->{tempfiles_subdir}."/blast/$jobid";

    if (!$format || $format eq 'raw') { 
	$c->stash->{rest} = { report => [ read_file($result_file) ] };
    }
    elsif ($format eq 'bioperl') { 
	$c->stash->{rest} = { report => [ read_file($result_file) ] }; # have to format this with bioperl
    }
    else { 
	$c->stash->{rest} = { error => "No report of format '$format' found", };
    }
}

sub blast_overview_graph : Path('/tools/blast/overview') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $jobid = shift;


}

sub blast_coverage_graph : Path('/tools/blast/coverage') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $jobid = shift;


}
    

# validate the given sequence as input for the given blast program
sub validate_seq : Path('/tools/blast/validate') Args(0) {
    my $self = shift;
    my $c = shift;
    my $s = shift;
    my $program = shift;

    my %alphabets = (
        ( map { $_ => 'protein' } 'tblastn', 'blastp'            ),
        ( map { $_ => 'DNA'     } 'blastn',  'blastx', 'tblastx' ),
       );

    #my $alphabet = $alphabets{$program}
    #or $c->throw( message => 'invalid program!',
    #                  is_error => 1,
    #                  developer_message => "program was '$program'",
    #                 );
    if (!exists($alphabets{$program})) { 
	$c->stash->{rest} = { 
	    validated => 0, 
	    error => "Invalid program '$program'. Please choose another program.", 
	};
	return;
    }
    my $alphabet = $alphabets{$program};

    if (!$s->validate_seq) {  #< bioperl must think it's OK
	$c->stash->{rest} = { 
	    validated => 0, 
	    error => 'Not a legal sequence', 
	};
	return;
    }

    my %not_iupac_pats = ( DNA     => qr/([^ACGTURYKMSWBDHVN]+)/i,
			   protein => qr/([^GAVLIPFYCMHKRWSTDENQBZ\.X\*]+)/i,
			   rna     => qr/([^ACGTURYKMSWBDHVN]+)/i,
			 );

    my $val_pat = $not_iupac_pats{$alphabet};
    if (!$val_pat) { 
	$c->stash->{rest} = { 
	    validated => 0, 
	    error => "Invalid alphabet ($alphabet)",
	};
	return;
    }
        # or $c->throw( message => 'invalid alphabet!',
        #               is_error => 1,
        #               developer_message => "alphabet was '$alphabet'",
        #              );
    if ($s->seq =~ $val_pat) { 
        #and $c->throw(
        #    message => encode_entities('Sequence "'.$s->id.qq|" contains invalid $alphabet characters "$1"| ),
        #    is_error => 0,
        #   );
	$c->stash->{rest} = { 
	    validated => 1,
	    error => encode_entities('Sequence "'.$s->id.qq|" contains invalid $alphabet characters "$1"| ),
	};
	return;
    }
    $c->stash->{rest} = { 
	validated => 1,
	error => '',
    };
}

1;
