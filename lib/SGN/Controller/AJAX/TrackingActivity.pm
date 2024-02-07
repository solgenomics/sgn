
package SGN::Controller::AJAX::TrackingActivity;

use Moose;
use CXGN::Stock::Order;
use CXGN::Stock::OrderBatch;
use Data::Dumper;
use JSON;
use DateTime;
use CXGN::People::Person;
use CXGN::Contact;
use CXGN::Trial::Download;
use CXGN::Stock::TrackingActivity::TrackingIdentifier;
use CXGN::Stock::TrackingActivity::ActivityInfo;

use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;

use LWP::UserAgent;
use LWP::Simple;
use HTML::Entities;
use URI::Encode qw(uri_encode uri_decode);
use Tie::UrlEncoder; our(%urlencode);


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub activity_info_save : Path('/ajax/tracking_activity/save') : ActionClass('REST'){ }

sub activity_info_save_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to add properties." };
        return;
    }
    if (!($c->user()->has_role('submitter') or $c->user()->has_role('curator'))) {
        $c->stash->{rest} = { error => "You do not have sufficient privileges to record activity info." };
        return;
    }

    my $tracking_identifier = $c->req->param("tracking_identifiers");
    my $activity_type = $c->req->param("activity_type");
    my $value = $c->req->param("value");
   #    print STDERR "ACTIVITY TYPE =".Dumper($activity_type)."\n";
   #    print STDERR "VALUE =".Dumper($value)."\n";

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $check_tracking_identifier = $schema->resultset("Stock::Stock")->find({uniquename => $tracking_identifier});

    my $add_activity_info = CXGN::Stock::TrackingActivity::ActivityInfo->new({
        chado_schema => $schema,
        tracking_identifier => $tracking_identifier,
        activity_type => $activity_type,
        value => $value,
    });
    $add_activity_info->add_info();

    if (!$add_activity_info->add_info()){
        $c->stash->{rest} = {error_string => "Error saving info",};
        return;
    }

    $c->stash->{rest} = { success => 1};

}


 1;
