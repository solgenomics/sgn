

package SGN::Controller::AJAX::Analyze::Phenotypes;

use Moose;

use strict;
use warnings;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::Download;
use CXGN::BreederSearch;
use POSIX qw(strftime);

BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );

sub analyze_trial_phenotypes : Path('/analyze/phenotypes/trials') Args(0) {
  my $self = shift;
  my $c = shift;
  my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
  my $trial_design = $c->req->param("trial_design");
  my $analysis_type = $c->req->param("analysis_type");
  my $format = $c->req->param("format") || "list_id";
  my (@trial_ids, $trial_data);

  if ($format eq 'ids') {       #use trial ids supplied directly
    my $id_string = $c->req->param("ids");
    @trial_ids = split(',',$id_string);
  }
  elsif ($format eq 'list_id') {        #get trial names from list and tranform them to ids

    my $trial_list_id = $c->req->param("trial_list_list_select");

    if ($trial_list_id) {
      $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
    }

    my @trial_list = map { $_->[1] } @$trial_data;

    my $t = CXGN::List::Transform->new();

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_hash = $t->transform($schema, $trial_t, \@trial_list);
    @trial_ids = @{$trial_id_hash->{transform}};

    print STDERR "trial_ids = " . @trial_ids ."\n";
    print STDERR "trial_id_hash =" . Dumper($trial_id_hash);
  }
  else {
    die "Unable to determine paramter format \n";
  }

  #$self->trial_download_log($c, @trial_ids, "trial analyze phenotypes");

  #my @trial_ids = split ",", $trial_ids;
  my $trial_sql = join ",", map { "\'$_\'" } @trial_ids;

  my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });
  my @data = $bs->get_extended_phenotype_info_matrix(undef,$trial_sql, undef);

  my $csv = $self->retrieve_phenotypes_csv($c, '', '', '', '', \@data);

  print STDERR "path to temp file that R will analyze is: $csv \n";

  my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
  my $dir = $c->tempfiles_subdir('analyze'); # make sure analyze dir exists
  my $file_name = $time_stamp . $analysis_type. "XXXX";
  my $relative_path = $c->tempfile( TEMPLATE => "analyze/$file_name");
  my $output_path = $c->config->{basepath}.$relative_path;

  print STDERR "path to R output is: $output_path \n";

  # run different R scripts based on supplied analysis and design types
  #if ($analysis_type eq 'Anova') {
  #   if ($trial_design eq 'RCBD') {
       #run analysis here, with CXGN:Tools Run
  #   }
  #}

  #just temporarily till R output is working
  #$output_path = '/home/bje24/cxgn/sgn/static/documents/Rplot.pdf';
  $output_path = '/static/documents/img/Rplot.png';

  # when analysis is complete, display output graphic
  if ( -e $csv) {
    # fix this return section to prevent the following error:
    #[error] Caught exception in SGN::View::Mason->process "Can't find component for path /analyze/phenotypes/analyze_trial_phenotypes.mas at /home/bje24/cxgn/local-lib/lib/perl5//Catalyst/View/HTML/Mason.pm line 209.
    $c->stash->{rest} = { result => $output_path};
    return;
  }
  else {
    $c->stash->{rest} = { error => "Error in R script R/Anova.R"};
    return;
  }
}

  sub retrieve_phenotypes_csv {
      my $self = shift;
      my $c = shift;
      my $trial_id = shift;
      my $program_name = shift;
      my $location = shift;
      my $year = shift;
      my $dataref = shift;
      my @data = @$dataref;

      my $dir = $c->tempfiles_subdir('data_export'); # make sure data_export dir exists
      my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"data_export/trial_".$program_name."_phenotypes_".$location."_".$trial_id."_XXXXX");

      close($fh);
      my $file_path = $c->config->{basepath}."/".$tempfile.".csv";
      #move($tempfile, $file_path);

      open(my $F, ">", $file_path) || die "Can't open file $file_path\n";
      for (my $line =0; $line< @data; $line++) {
  	my @columns = split /\t/, $data[$line];

  	print $F join(",", @columns);
  	print $F "\n";
      }

      close($F);
      return $file_path;
  }

1;
