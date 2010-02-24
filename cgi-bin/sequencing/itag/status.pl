use strict;
use warnings;
use English;

use XML::Generator;

use CXGN::Scrap::AjaxPage;

use CXGN::Tools::List qw/str_in/;

use CXGN::ITAG::Pipeline;

our $page;
eval {
  $ENV{CXGNITAGPIPELINEANALYSISTESTING}=1 unless CXGN::VHost->new->get_conf('production_server');

  $page = CXGN::Scrap::AjaxPage->new("text/plain");
  $page->send_http_header;


  my ($op) = $page->get_encoded_arguments('op');
  $op or die "must specify an operation when calling status web service\n";

  #hash of operations
  my %ops  = ( astat => \&analysis_status,
	       lbs   => sub { my ($p,$b) = get_pipe_and_batch(); $b->seqlist},
	       lb    => sub { get_pipe()->list_batches },
	       la    => sub { get_pipe()->list_analyses },
	       lp    => sub { map {sprintf("%03d",$_)} CXGN::ITAG::Pipeline->list_pipelines },
	     );

  $ops{$op} or die "unknown operation.  valid operations are: ".join(',',sort keys %ops)."\n";

  print map "$_\n",$ops{$op}->(); #call the operation and print its results
};
if($EVAL_ERROR) {
  print "ERROR: $EVAL_ERROR\nWeb service documentation can be found at: http://www.ab.wur.nl/TomatoWiki/PipelineStatusWebService\n";
}

exit;


############ OPERATION SUBS ##############################

sub analysis_status {
  my ($pipe,$batch) = get_pipe_and_batch();
  my ($atag) = $page->get_encoded_arguments('atag');
  my $a = $pipe->analysis($atag)
    or die "no analysis found with that tag name\n";

  return $a->status($batch);
}

######### UTIL SUBS ######################################

sub get_pipe_and_batch {
  my $pipe = get_pipe();
  my ($bnum) = $page->get_encoded_arguments('batch');
  $bnum += 0;
  my $batch = $pipe->batch($bnum)
    or die "batch number $bnum does not exist";
  return ($pipe,$batch);
}

sub get_pipe {
  my ($ver) = $page->get_encoded_arguments('pipe');
  my @args = defined $ver ? (version => $ver+0) : ();
  my $pipe = CXGN::ITAG::Pipeline->open(
      @args,
      basedir => $c->config->{'CXGN::ITAG'}->{'itag_pipeline_base'},
     )
    or die 'pipeline version $ver not found';
  return $pipe;
}

