package SGN::Controller::Report;

=head1 NAME

SGN::Controller::Report - Report Factory page (/tools/report)

=head1 DESCRIPTION

/tools/report            choose reports, fill the inputs they take, run them and see the results
/tools/report?run_id=..  open the results of a run (link of the notification email)

=cut

use Moose;
use URI::FromHash qw | uri |;

BEGIN { extends 'Catalyst::Controller' };

sub report_factory_index :Path('/tools/report') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }

    my $run_id = $c->req->param('run_id') // '';
    $c->stash->{run_id} = $run_id =~ /^rf_\d{8}_\d{6}_[a-z0-9]{6}$/ ? $run_id : '';
    $c->stash->{is_curator} = (grep { $_ eq 'curator' } $c->user()->roles()) ? 1 : 0;
    $c->stash->{template} = '/tools/report.mas';
}

1;
