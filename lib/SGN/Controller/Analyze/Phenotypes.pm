

package SGN::Controller::Analyze::Phenotypes;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use strict;
use warnings;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::Download;
use CXGN::BreederSearch;
use POSIX qw(strftime);

sub load_analyze_phenotypes : Path('/analyze/phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/analyze/phenotypes.mas';
}

sub analyze_trial_phenotypes : Path('/analyze/phenotypes/trials') Args(1) {
  my $self = shift;
  my $c = shift;
  my $trial_ids = shift;
  my $design = $c->req->param("design");
  my $analysis_type = $c->req->param("analysis_type");

  $self->trial_download_log($c, $trial_ids, "trial analyze phenotypes");

  my @trial_ids = split ",", $trial_ids;
  my $trial_sql = join ",", map { "\'$_\'" } @trial_ids;

  my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });
  my @data = $bs->get_extended_phenotype_info_matrix(undef,$trial_sql, undef);
  my $schema = $c->dbic_schema("Bio::Chado::Schema");

  my $csv = $self->retrieve_phenotypes_csv($c, '', '', '', '', \@data);

  print STDERR "path to temp file that R will analyze is: $csv \n";

  my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
  my $dir = $c->tempfiles_subdir('analyze'); # make sure analyze dir exists
  my $file_name = $time_stamp . $analysis_type. "XXXX";
  my $relative_path = $c->tempfile( TEMPLATE => "analyze/$file_name");
  my $output_path = $c->config->{basepath}."/".$relative_path;

  print STDERR "path to R output is: $output_path \n";

  # run different R scripts based on supplied analysis and design type
  #if ($analysis_type eq 'ANOVA') {
  #   if ($design eq 'RCBD') {
       #run analysis here, with CXGN:Tools Run
  #   }
  #}

  #just temporarily till R output is working
  $output_path = '/home/bje24/cxgn/sgn/static/documents/Rplot.pdf';

  # when analysis is complete, display output graphic
  if ( -e $output_path) {
    return "<img src=\"$output_path\" /><br>";
  }
  else {
    return "Error in R script R/Anova.R<br>\n";
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

      my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"data_export/trial_".$program_name."_phenotypes_".$location."_".$trial_id."_XXXXX");

      close($fh);
      my $file_path = $c->config->{basepath}."/".$tempfile.".csv";
      move($tempfile, $file_path);

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
