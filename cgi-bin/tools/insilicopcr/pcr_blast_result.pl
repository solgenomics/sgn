#!/usr/bin/perl -w

=head1 NAME

pcr_blast_result.pl - will generate the blast result report and send it to view_result.pl					

=head1 DESCRIPTION
This code is taken from blast_result.pl with modifications that allow processing the forward
and revese primers and validate them. will send all the processed data and the blast report 
to view_result.pl after going through the wait.pl to wait for the blast results to appear.

=head1 AUTHOR

Waleed Haso wh292@cornell.edu 
Only added modifications to support the PCR part 
Original code was aspired from BLAST. 

=cut


#pcr_blast_results.pl is the same blast_results.pl with some modifications to 
#handle inserting primer sequences. 

use strict;
use warnings;
use CXGN::Page;
use POSIX;
use File::Temp qw/tempfile/;
use File::Basename;
use Storable qw/ store /;
use File::Spec;

use Tie::UrlEncoder;
our %urlencode;
use CXGN::DB::Connection;
use CXGN::BlastDB;
use CXGN::Tools::Identifiers;
use CXGN::Tools::List qw/distinct evens/;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/page_title_html modesel info_table_html hierarchical_selectboxes_html simple_selectbox_html/;
use Bio::Seq;
use CatalystX::GlobalContext '$c';

################################################################################################################
my $page = CXGN::Page->new( "Get PCR Products", "Waleed");

my %params;
my $seq_count = 0;

my @errors; #to store erros as they happen
################################################################################################################
#processing the primers 
my $min_primer_length = 15;

my $fprimer = $page->get_arguments("fprimer");
my $rprimer = $page->get_arguments("rprimer");
my $productLength = $page->get_arguments("productLength");
my $allowedMismatches = $page->get_arguments('allowedMismatches');
my $frevcom = $page->get_arguments('frevcom'); #forward primer reverse complement
my $rrevcom = $page->get_arguments('rrevcom'); #reverse primer reverse complement

#reverse complement if checked
if ($frevcom){
	$fprimer = reverse_complement($fprimer);
}
if ($rrevcom){
	$rprimer = reverse_complement($rprimer);
}


sub reverse_complement{
	my $seq = shift;
	my $seq_obj = Bio::Seq->new( -seq => $seq );
	
	return $seq_obj->revcom->seq ;
}

#getting the length of the primers
my $flength = length($fprimer);
my $rlength = length ($rprimer);

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

if (scalar (@errors) > 0){
	user_error($page , join("<BR>" , @errors));
}
##giving them a fasta format
$fprimer = ">FORWARD-PRIMER\n$fprimer";
$rprimer = ">REVERSE-PRIMER\n$rprimer";

#my $blast_seq_in = "$fprimer\n$rprimer\n";
my $blast_seq_in = "$fprimer\n$rprimer\n";




################################################################################################################
my %arg_handlers =
  (
   
   sequence=>
   sub {
     my $sequence = $blast_seq_in;
     #$sequence =s/^\s+|\s+$|\n\s*\n//g;
     
     #make a tempfile that has our sequence(s) in it
     my ($seq_fh, $seq_filename) = tempfile( "seqXXXXXX",
					     DIR=> $c->config->{'cluster_shared_tempdir'},
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
################################################################################################################
   matrix =>
   sub {
     $params{matrix} =~ /^BLOSUM\d\d$/ || $params{matrix} =~ /^PAM\d\d$/
       or die "invalid matrix '$params{matrix}'";
     return -M => $params{matrix}
   },

################################################################################################################
   expect =>
   sub {
     $params{expect} =~ s/[^\d\.e\-\+]//gi; #can only be these characters
     return -e => $params{expect} || 1
   },

################################################################################################################
   filterq =>
   sub {
     return -F => $params{filterq} ? 'T' : 'F'
   },
################################################################################################################
   outformat =>
   sub {
     $params{outformat} =~ s/\D//g; #only digits allowed
     return -m => $params{outformat}
   },
################################################################################################################
   database =>
   sub {
     #my ($bdb) = CXGN::BlastDB->search( file_base => $params{database} )
 
       #or die "could not find bdb with file_base '$params{database}'";

     #     warn "setting pref last_blast_db_fil
    #database object for specific ID_No
     my $bdb = CXGN::BlastDB->from_id($params{database});
     my $basename = $bdb->full_file_basename;
            #returns '/data/shared/blast/databases/genbank/nr'
 #remember the file_base the user just blasted with

     return -d => $basename;
   },
################################################################################################################
   program =>
   sub {
     $params{program} =~ s/[^a-z]//g; #only lower-case letters
     return -p => $params{program}
   },

  );

################################################################################################################
#get all the params from our request
my (undef) = $page->get_arguments('file');
@params{keys %arg_handlers} = $page->get_arguments(keys %arg_handlers);


################################################################################################################
#build our command with our arg handlers
my @command =
  ( 'blastall',
    map $_->(), values %arg_handlers
  );
  

################################################################################################################
#now run the blast
my $job = CXGN::Tools::Run->run_cluster(@command,
					{ temp_base => $c->config->{'cluster_shared_tempdir'},
					  queue => $c->config->{'web_cluster_queue'},
					  working_dir => $c->config->{'cluster_shared_tempdir'},
					  # don't block and wait if the cluster looks full
					  max_cluster_jobs => 1_000_000_000,
					}
				   );
#$job->do_not_cleanup(1);

my $job_file_tempdir = $c->path_to( $c->tempfiles_subdir('blast') );
my (undef,$job_file) = tempfile( DIR => $job_file_tempdir, TEMPLATE=>"object_XXXXXX");

store($job, $job_file)
    or die 'could not serialize job object';

my $job_file_base = basename($job_file);

# url encode the destination pass_back page.
#delete $params{sequence};

my $pass_back = "./insilicopcr/view_result.pl?".
	hash2param(%params, seq_count => $seq_count, 
	           productLength => $productLength, 
	           allowedMismatches => $allowedMismatches,
	           flength => $flength,
	           rlength => $rlength).
	'&report_file=';
#$pass_back =~ s/&/&amp;/g;

my $redir_url = "../wait.pl?tmp_app_dir=/blast&job_file=$job_file_base&redirect=$urlencode{$pass_back}";

warn "redirecting to '$redir_url'";

$page->client_redirect($redir_url);

#################################################################################################################
sub user_error {
  my ($page, $reason) = @_;

  $page->header();

  print <<EOF;

  <h4>In Silico PCR Interface Error</h4>

  <p>$reason</p>
EOF

  $page->footer();
  exit(0);
}
################################################################################################################
sub hash2param {
  my %args = @_;
  return join '&', map "$urlencode{$_}=$urlencode{$args{$_}}", distinct evens @_;
}
