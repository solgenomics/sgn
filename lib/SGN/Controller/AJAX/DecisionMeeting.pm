# lib/SGN/Controller/AJAX/DecisionMeeting.pm
package SGN::Controller::AJAX::DecisionMeeting;
use Moose;
use CXGN::Dataset;
use CXGN::List;
use JSON;
use Try::Tiny;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    namespace => 'ajax/decisionmeeting',
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);




# --- sanity check endpoint: GET /ajax/decision_meeting/ping
sub ping : Path('ping') : Args(0) : ActionClass('REST') {}
sub ping_GET {
  my ($self, $c) = @_;
  $c->log->debug('ping_GET() hit');
  print STDERR "### DecisionMeeting ping_GET triggered ###\n";
  $self->status_ok($c, entity => { ok => 1, user => ($c->user ? 1 : 0) });
}

# --- GET /ajax/decision_meeting/lists?type=accessions
# GET /ajax/decision_meeting/lists?type=accessions
sub lists : Path('lists') : Args(0) : ActionClass('REST') {}

sub lists_GET {
    my ($self, $c) = @_;

    $c->log->debug('lists_GET() hit');
    print STDERR "### lists_GET triggered ###\n";

    return $self->status_forbidden($c, message => 'Login required')
      unless $c->user;

    my $owner_id  = $c->user->get_object->get_sp_person_id;
    my $type_name = 'accessions';

    my $chado = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cvterm_id = $chado->resultset('Cv::Cvterm')
                          ->search({ name => $type_name })
                          ->get_column('cvterm_id')->first;

    unless ($cvterm_id) {
        $c->log->warn("lists_GET: cvterm not found for type '$type_name'");
        return $self->status_ok($c, entity => { lists => [], type_name => $type_name, type_id => undef });
    }

    my $people = $c->dbic_schema('CXGN::People::Schema');

    # If your List table has an 'obsolete' flag, keep it in the filter:
    my $rs = $people->resultset('List')->search(
        { owner => $owner_id, type_id => $cvterm_id },
        { order_by => 'name' }
    );

    my @lists = map {
        +{
          list_id  => int($_->list_id),
          name     => $_->name,
          type_id  => $cvterm_id,
          type_name=> $type_name,
        }
    } $rs->all;

    $self->status_ok($c, entity => { lists => \@lists, type_name => $type_name, type_id => $cvterm_id });
}


# --- GET /ajax/decision_meeting/datasets
sub datasets : Path('datasets') : Args(0) : ActionClass('REST') {}
sub datasets_GET {
  my ($self, $c) = @_;
  $c->log->debug('datasets_GET() hit');
  print STDERR "### datasets_GET triggered ###\n";

  return $self->status_forbidden($c, message => 'Login required') unless $c->user;

  my $phenome = $c->dbic_schema('CXGN::Phenome::Schema');
  my $rs = $phenome->resultset('Dataset')->search( { order_by => 'name' } );

  my @datasets = map +{
    dataset_id => int($_->sp_dataset_id),
    name       => ($_->name // ('Dataset '.$_->sp_dataset_id))
  }, $rs->all;

  $self->status_ok($c, entity => { datasets => \@datasets });
}

# --- GET /ajax/decision_meeting/accessions?dataset_id=NN | list_id=NN
sub accessions : Path('accessions') : Args(0) : ActionClass('REST') {}
sub accessions_GET {
  my ($self, $c) = @_;
  $c->log->debug('accessions_GET() hit');
  print STDERR "### accessions_GET triggered ###\n";

  return $self->status_forbidden($c, message => 'Login required') unless $c->user;

  my $dataset_id    = $c->req->param('dataset_id');
  my $list_id       = $c->req->param('list_id');

  my $people_schema = $c->dbic_schema("CXGN::People::Schema");
  my $schema        = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
  my $dbh           = $c->dbc->dbh;

  my @names;

  if ($dataset_id) {
    my $ds = CXGN::Dataset->new(
      people_schema => $people_schema,
      schema        => $schema,
      sp_dataset_id => $dataset_id
    );
    eval { $ds->retrieve_accessions() };
    if ($ds->can('accessions') && ref($ds->accessions) eq 'ARRAY') {
      @names = @{$ds->accessions};
    } elsif (my $ret = eval { $ds->retrieve_accessions() }) {
      @names = @{ $ret->{data} || [] } if ref($ret) eq 'HASH';
    } elsif ($ds->can('accession_list') && ref($ds->accession_list) eq 'ARRAY') {
      @names = @{$ds->accession_list};
    }
  }
  elsif ($list_id) {
    my $list = CXGN::List->new({ dbh => $dbh, list_id => $list_id });
    my $els  = $list->elements;
    @names   = @$els if $els && ref($els) eq 'ARRAY';
  }

  my @accs = map { +{ accession_id => undef, name => "$_" } } grep { defined && $_ ne '' } @names;
  $self->status_ok($c, entity => { accessions => \@accs });
}

# POST /ajax/decisionmeeting/create
# POST /ajax/decisionmeeting/create
sub create : Path('create') Args(0) {
  my ($self, $c) = @_;

  # TEMP: don’t block while testing
  # return $self->status_forbidden($c, message => 'Login required') unless $c->user;

  my $p = $c->req->params;  # form-urlencoded (your JS)
  my $payload = {
    meeting_name     => $p->{meeting_name}     // '',
    breeding_program => $p->{breeding_program} // '',
    location         => $p->{location}         // '',
    year             => $p->{year}             // '',
    date             => $p->{date}             // '',
    data             => $p->{data}             // '',
    attendees        => $p->{attendees}        // '',
  };

  $c->log->debug('[DM] create hit. Params=' . join(', ', map {"$_=$p->{$_}"} sort keys %$p));

  # Always send a response
  $c->res->content_type('application/json');
  $c->res->body(encode_json({ ok => \1, echo => $payload, msg => 'pong' }));
}

1;
