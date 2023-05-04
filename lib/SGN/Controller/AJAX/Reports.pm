
package SGN::Controller::AJAX::Reports;

use Moose;

BEGIN { extends "Catalyst::Controller::REST" };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


use CXGN::DbStats;

sub database_counts :Path('/ajax/reports/database_counts') Args(0) {
    my $self = shift;
    my $c = shift;

    


}


1;
