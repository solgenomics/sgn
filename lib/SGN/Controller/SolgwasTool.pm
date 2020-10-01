package SGN::Controller::SolgwasTool;

use Moose;

use POSIX;
use Data::Dumper;
use Storable qw | nstore retrieve |;
use List::Util qw/sum/;
use Bio::SeqIO;
use CXGN::Tools::Text qw/ sanitize_string /;
#use SGN::Schema;
use URI::FromHash 'uri';
use CXGN::Blast;
use CXGN::Blast::SeqQuery;


BEGIN { extends 'Catalyst::Controller'; }

sub AUTO {
    my $self = shift;
    my $c = shift;
    SGN::Schema::BlastDb->dbpath($c->config->{blast_db_path});
}

sub index :Path('/tools/solgwas/') :Args(0) {
  my $self = shift;
  my $c = shift;
  if (! $c->user) {
    $c->res->redirect(uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    return;
  }
  $c->stash->{template} = '/tools/solgwas/index.mas';
}




1;
