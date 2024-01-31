
package SGN::Controller::AJAX::Reports;

use Moose;
use CXGN::DbStats;

BEGIN { extends "Catalyst::Controller::REST" };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub database_counts :Path('/ajax/reports/database_counts') Args(0) {
    my $self = shift;
    my $c = shift;

    my $dbs = CXGN::DbStats->new( { dbh => $c->dbc->dbh() } );

    my $data = $dbs->database_counts();

    $c->stash->{template} = { data => $data };
}

sub recent_activity :Path('/ajax/report/recent_activity') Args(0) {
    my $self = shift;
    my $c = shift;

    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");

    my $dbs = CXGN::DbStats->new( { dbh => $c->dbc->dbh() } );
    
    my $field_trial_data = $dbs->recent_trials($start_date, $end_date);

    my $genotyping_plate_data = $dbs->recent_genotyping_plates($start_date, $end_date);
    
    my $accession_data = $dbs->recent_stocks($start_date, $end_date);

    my $cross_data = $dbs->recent_crosses($start_date, $end_date);

    my $phenotype_data = $dbs->recent_phenotype_data($start_date, $end_date);

    return {
	trial_data => $field_trial_data,
	accession_data => $accession_data,
	cross_data => $cross_data,
	phenotype_data => $phenotype_data,
    };
    
}
    


    

1;
