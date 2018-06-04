use strict;

package SGN::Controller::BreedersToolbox::GraphicalFiltering;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }

sub graphical_filtering :Path('/tools/graphicalfiltering') {
  my $self =shift;
  my $c = shift;
  if (! $c->user) {
  	$c->res->redirect(uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
  	return;
  }
  my $trial_list_id = $c->request->param('trial_list_id');
  my $plot_list_id = $c->request->param('plot_list_id');
  my $trial_ids = $c->request->parameters->{'trial_id'};
  my $ajaxRequestString = "";

  if (defined $trial_list_id){
    $ajaxRequestString = "/ajax/plot/common_traits_by/trial_list?trial_list_id=".$trial_list_id;
  }
  elsif (defined $plot_list_id){
    $ajaxRequestString = "/ajax/plot/common_traits_by/plot_list?plot_list_id=".$plot_list_id;
  }
  elsif (defined $trial_ids){
    $ajaxRequestString = "/ajax/plot/common_traits_by/trials?";
    foreach my $trial_id (@$trial_ids){
      $ajaxRequestString .= "trial_id=".$trial_id."&";
    }
  }
  print STDERR $ajaxRequestString;
  $c->stash->{ajaxRequestString} = $ajaxRequestString;
  $c->stash->{main_production_site_url} = $c->config->{main_production_site_url};

  $c->stash->{template} = '/tools/graphicalfiltering/index.mas';
}
1;
