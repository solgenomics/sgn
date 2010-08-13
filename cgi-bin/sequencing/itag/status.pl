use CatalystX::GlobalContext qw( $c );
use strict;
use warnings;
use English;

use XML::Generator;

use CXGN::Scrap::AjaxPage;

use CXGN::Tools::List qw/str_in/;

use CXGN::ITAG::Pipeline;

our $itag_feature = $c->enabled_feature('itag')
    or do { print "\n\nITAG feature not enabled.\n"; exit };

eval {
  $ENV{CXGNITAGPIPELINEANALYSISTESTING} = 1 unless $c->get_conf('production_server');

  my $page = CXGN::Scrap::AjaxPage->new("text/plain");
  $page->send_http_header;

  my ( $op ) = $page->get_encoded_arguments('op');
  $op or die "must specify an operation when calling status web service\n";

  #hash of operations
  my %ops  = ( astat => sub { analysis_status($page) },
	       lbs   => sub { my ($p,$b) = get_pipe_and_batch($page); $b->seqlist},
	       lb    => sub { get_pipe($page)->list_batches },
	       la    => sub { get_pipe($page)->list_analyses },
	       lp    => sub { map {sprintf("%03d",$_)} $itag_feature->list_pipelines },
	     );

  $ops{$op} or die "unknown operation.  valid operations are: ".join(',',sort keys %ops)."\n";

  print map "$_\n",$ops{$op}->(); #call the operation and print its results
};
if($EVAL_ERROR) {
  print "\n\nERROR: $EVAL_ERROR\nWeb service documentation can be found at: http://www.ab.wur.nl/TomatoWiki/PipelineStatusWebService\n";
}

exit;


############ OPERATION SUBS ##############################

sub analysis_status {
    my $page = shift;
    my ($pipe,$batch) = get_pipe_and_batch($page);
    my ($atag) = $page->get_encoded_arguments('atag');
    my $a = $pipe->analysis($atag)
        or die "no analysis found with that tag name\n";
    return $a->status($batch);
}

######### UTIL SUBS ######################################

sub get_pipe_and_batch {
    my ( $page ) = @_;
    my $pipe = get_pipe($page);
    my ($bnum) = $page->get_encoded_arguments('batch');
    $bnum += 0;
    my $batch = $pipe->batch($bnum)
        or die "batch number $bnum does not exist";
    return ($pipe,$batch);
}

sub get_pipe {
    my ( $page ) = @_;
    my ( $ver ) = $page->get_encoded_arguments('pipe');
    my @args = defined $ver ? (version => $ver+0) : ();
    my $pipe = $itag_feature->pipeline( @args )
        or die 'pipeline version $ver not found';
    return $pipe;
}

