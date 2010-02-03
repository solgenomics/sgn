#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::VHost;
use POSIX;

use File::Temp qw/tempfile/;
use File::Basename;

use Storable qw / store /;
use File::Spec;

use Tie::UrlEncoder;
our %urlencode;

use CXGN::DB::Connection;
use CXGN::Page::UserPrefs;
use CXGN::BlastDB;

use CXGN::Tools::Identifiers;
use CXGN::Tools::List qw/distinct evens/;

my $page = CXGN::Page->new( "blast search execution", "Rob");
my $prefs = CXGN::Page::UserPrefs->new( CXGN::DB::Connection->new );
my $vhost_conf = CXGN::VHost->new();

my %params;
my $seq_count = 0;

my %arg_handlers =
  (

   interface_type =>
   sub {()}, #< does nothing to blast command


   sequence =>
   sub {
     my $sequence = $params{sequence};
     $sequence =~ s/^\s+|\s+$|\n\s*\n//g; #< trim out leading and trailing whitespace and blank lines
     if($sequence) {
       if ($sequence !~ /^\s*>/) {
	 $sequence = ">WEB-USER-SEQUENCE (Unknown)\n$sequence";
       }
       $sequence .= "\n"; #< add a final newline
     }


     #make a tempfile that has our sequence(s) in it
     my ($seq_fh, $seq_filename) = tempfile( "seqXXXXXX",
					     DIR=> $vhost_conf->get_conf('cluster_shared_tempdir'),
					   );
     print $seq_fh $sequence;

     if(my $file_upload = $page->get_upload) {
       if ( my $fh = $file_upload->fh ) {
	 print $seq_fh $_ while <$fh>;
       }
     }

     seek $seq_fh,0,0; #< rewind the filehandle
     #count the number of seqs in the file
     while(<$seq_fh>) {
       $seq_count++ if index($_,'>') != -1;
     }

     return -i => $seq_filename
   },

   matrix =>
   sub {
     $params{matrix} =~ /^BLOSUM\d\d$/ || $params{matrix} =~ /^PAM\d\d$/
       or die "invalid matrix '$params{matrix}'";
     return -M => $params{matrix}
   },


   expect =>
   sub {
     $params{expect} =~ s/[^\d\.e\-\+]//gi; #can only be these characters
     return -e => $params{expect} || 1
   },

   maxhits =>
   sub {
     $params{maxhits} =~ s/\D//g; #only digits allowed
     return -b => $params{maxhits} || 100
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

   file =>
   sub {warn "GOT FILE $params{file}\n"; ()},
  );

#get all the params from our request
my (undef) = $page->get_arguments('file');
@params{keys %arg_handlers} = $page->get_arguments(keys %arg_handlers);

#build our command with our arg handlers
my @command =
  ( 'blastall',
    map $_->(), values %arg_handlers
  );
#warn "assembled command '".join(' ',@command)."'\n";

#check some specific error conditions
#   multiple sequences in given to simple BLAST
if($params{interface_type} eq 'simple' && $seq_count > 1) {
  user_error($page,'The Simple BLAST interface is limited to one query sequence.  Please use the Advanced BLAST for multiple query sequences');
}


#now run the blast

my $job = CXGN::Tools::Run->run_cluster(@command,
					{ temp_base => $vhost_conf->get_conf('cluster_shared_tempdir'),
					  queue => $vhost_conf->get_conf('web_cluster_queue'),
					  working_dir => $vhost_conf->get_conf('cluster_shared_tempdir'),
					  # don't block and wait if the cluster looks full
					  max_cluster_jobs => 1_000_000_000,
					}
				       );
#$job->do_not_cleanup(1);

my $job_file_tempdir = File::Spec->catdir($vhost_conf->get_conf('basepath'),
					  $vhost_conf->get_conf('tempfiles_subdir'),
					  "blast",
					 );
my (undef,$job_file) = tempfile( DIR => $job_file_tempdir, TEMPLATE=>"object_XXXXXX");
store($job, $job_file)
    or die 'could not serialize job object';

my $job_file_base = basename($job_file);

# url encode the destination pass_back page.
delete $params{sequence};
my $pass_back = "./blast/view_result.pl?".hash2param(%params, seq_count => $seq_count).'&report_file=';
#$pass_back =~ s/&/&amp;/g;
my $redir_url = "../wait.pl?tmp_app_dir=/blast&job_file=$job_file_base&redirect=$urlencode{$pass_back}";
warn "redirecting to '$redir_url'";
$page->client_redirect($redir_url);

sub user_error {
  my ($page, $reason) = @_;

  $page->header();

  print <<EOF;

  <h4>SGN BLAST Interface Error</h4>

  <p>$reason</p>
EOF

  $page->footer();
  exit(0);
}

sub hash2param {
  my %args = @_;
  return join '&', map "$urlencode{$_}=$urlencode{$args{$_}}", distinct evens @_;
}

