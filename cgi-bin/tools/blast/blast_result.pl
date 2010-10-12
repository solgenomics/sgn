use CatalystX::GlobalContext qw( $c );
use strict;
use warnings; #FATAL => 'all';
use CXGN::Page;
use POSIX;

use File::Basename;
use File::Spec;
use File::Temp qw/tempfile/;
use HTML::Entities;
use Storable qw / nstore /;
use Tie::UrlEncoder; our %urlencode;
use Try::Tiny;

use CXGN::DB::Connection;
use CXGN::Page::UserPrefs;
use CXGN::BlastDB;

use CXGN::Tools::Identifiers;
use CXGN::Tools::List qw/distinct evens/;

my $page  = CXGN::Page->new( "blast search execution", "Rob" );
my $prefs = CXGN::Page::UserPrefs->new( CXGN::DB::Connection->new );

my %params;
my $seq_count = 0;

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
     my ($seq_fh, $seq_filename) = tempfile( "seqXXXXXX",
					     DIR=> $c->get_conf('cluster_shared_tempdir'),
					   );
     $seq_fh->print($sequence) if $sequence;

     if(my $file_upload = $page->get_upload) {
       if ( my $fh = $file_upload->fh ) {
	 print $seq_fh $_ while <$fh>;
       }
     }

     seek $seq_fh,0,0; #< rewind the filehandle
     # go over file, checking for empty seqs or other badness
     # also, count the number of seqs in the file
     my $i = Bio::SeqIO->new(
         -format   => 'fasta',
         -fh       => $seq_fh,
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
                                       '$seq_filename' => $seq_filename,
                                   }),
                                  );

     return -i => $seq_filename
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
     $prefs->set_pref( last_blast_db_id => $bdb->blast_db_id );

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
@params{keys %arg_handlers} = $page->get_arguments(keys %arg_handlers);

#build our command with our arg handlers
my @command =
  ( 'blastall',
    map $_->(), values %arg_handlers
  );

#check some specific error conditions
#   multiple sequences in given to simple BLAST
if($params{interface_type} eq 'simple' && $seq_count > 1) {

  $c->throw( is_error => 0,
             message  => <<EOM,
The Simple BLAST interface is limited to one query sequence.  Please
ruse the Advanced BLAST for multiple query sequences.
EOM
            );

}


#now run the blast
my $job = CXGN::Tools::Run->run_cluster(
    @command,
    { temp_base => $c->get_conf('cluster_shared_tempdir'),
      queue => $c->get_conf('web_cluster_queue'),
      working_dir => $c->get_conf('cluster_shared_tempdir'),
      # don't block and wait if the cluster looks full
      max_cluster_jobs => 1_000_000_000,
    }
);

#$job->do_not_cleanup(1);

# store the job object in a file
my ($job_file,$job_file_uri) = $c->tempfile( TEMPLATE => ['blast','object_XXXXXX'] );
nstore( $job, $job_file )
    or die 'could not serialize job object';
my $job_file_base = basename($job_file);

# url encode the destination pass_back page.
delete $params{sequence};
my $pass_back = "/tools/blast/view_result.pl?".hash2param(%params, seq_count => $seq_count).'&report_file=';
my $redir_url = "/tools/wait.pl?tmp_app_dir=/blast&job_file=$job_file_base&redirect=$urlencode{$pass_back}";
$page->client_redirect( $redir_url );


####### subs #######

sub hash2param {
  my %args = @_;
  no warnings 'uninitialized';
  return join '&', map "$urlencode{$_}=$urlencode{$args{$_}}", distinct evens @_;
}

# validate the given sequence as input for the given blast program
sub validate_seq {
    my ($s,$program) = @_;

    my %alphabets = (
        ( map { $_ => 'protein' } 'tblastn', 'blastp'            ),
        ( map { $_ => 'DNA'     } 'blastn',  'blastx', 'tblastx' ),
       );

    my $alphabet = $alphabets{$program}
        or $c->throw( message => 'invalid program!',
                      is_error => 1,
                      developer_message => "program was '$program'",
                     );

    return 0 unless $s->validate_seq; #< bioperl must think it's OK

    my %not_iupac_pats = ( DNA     => qr/([^ACGTURYKMSWBDHVN]+)/i,
			   protein => qr/([^GAVLIPFYCMHKRWSTDENQBZ\.X\*]+)/i,
			   rna     => qr/([^ACGTURYKMSWBDHVN]+)/i,
			 );

    my $val_pat = $not_iupac_pats{$alphabet}
        or $c->throw( message => 'invalid alphabet!',
                      is_error => 1,
                      developer_message => "alphabet was '$alphabet'",
                     );
    $s->seq =~ $val_pat
        and $c->throw(
            message => encode_entities('Sequence "'.$s->id.qq|" contains invalid $alphabet characters "$1"| ),
            is_error => 0,
           );


    return 1;
}
