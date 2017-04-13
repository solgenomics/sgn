
=head1 NAME

SGN::Controller::AJAX::Accessions - a REST controller class to provide the
backend for managing accessions

=head1 DESCRIPTION

Managing accessions

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

=cut

package SGN::Controller::AJAX::Accessions;

use Moose;
use JSON -support_by_pp;
use List::MoreUtils qw /any /;
use CXGN::BreedersToolbox::Accessions;
use CXGN::BreedersToolbox::AccessionsFuzzySearch;
use CXGN::Stock::AddStocks;
use CXGN::Chado::Stock;
use CXGN::List;
use Data::Dumper;
#use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub verify_accession_list : Path('/ajax/accession_list/verify') : ActionClass('REST') { }

sub verify_accession_list_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $self->verify_accession_list_POST($c);
}

sub verify_accession_list_POST : Args(0) {
  my ($self, $c) = @_;

  my $accession_list_json = $c->req->param('accession_list');
  my @accession_list = @{_parse_list_from_json($accession_list_json)};

  my $do_fuzzy_search = $c->req->param('do_fuzzy_search');

  if ($do_fuzzy_search) {
      $self->do_fuzzy_search($c, \@accession_list);
  }
  else {
      $self->do_exact_search($c, \@accession_list);
  }

}

sub do_fuzzy_search {
    my $self = shift;
    my $c = shift;
    my $accession_list = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $fuzzy_accession_search = CXGN::BreedersToolbox::AccessionsFuzzySearch->new({schema => $schema});
    my $fuzzy_search_result;
    my $max_distance = 0.2;
    my @accession_list = @$accession_list;
    my @found_accessions;
    my @fuzzy_accessions;
    my @absent_accessions;

    if (!$c->user()) {
	$c->stash->{rest} = {error => "You need to be logged in to add accessions." };
	return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	$c->stash->{rest} = {error =>  "You have insufficient privileges to add accessions." };
	return;
    }
    #remove all trailing and ending spaces from accessions 
    s/^\s+|\s+$//g for @accession_list;
   
    $fuzzy_search_result = $fuzzy_accession_search->get_matches(\@accession_list, $max_distance);
    #print STDERR "\n\nResult:\n".Data::Dumper::Dumper($fuzzy_search_result)."\n\n";

    @found_accessions = $fuzzy_search_result->{'found'};
    @fuzzy_accessions = $fuzzy_search_result->{'fuzzy'};
    @absent_accessions = $fuzzy_search_result->{'absent'};

    $c->stash->{rest} = {
	success => "1",
	absent => @absent_accessions,
	fuzzy => @fuzzy_accessions,
	found => @found_accessions
    };
    return;
}

sub do_exact_search {
    my $self = shift;
    my $c = shift;
    my $accession_list = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my @found_accessions;
    my @fuzzy_accessions;

    my $validator = CXGN::List::Validate->new();
    my @absent_accessions = @{$validator->validate($schema, 'accessions', $accession_list)->{'missing'}};
    my %accessions_missing_hash = map { $_ => 1 } @absent_accessions;

    foreach (@$accession_list){
        if (!exists($accessions_missing_hash{$_})){
            push @found_accessions, { unique_name => $_,  matched_string => $_};
            push @fuzzy_accessions, { unique_name => $_,  matched_string => $_};
        }
    }

    my $rest = {
	success => "1",
	absent => \@absent_accessions,
	found => \@found_accessions,
	fuzzy => \@fuzzy_accessions
    };
    #print STDERR Dumper($rest);
    $c->stash->{rest} = $rest;
}

sub verify_fuzzy_options : Path('/ajax/accession_list/fuzzy_options') : ActionClass('REST') { }

sub verify_fuzzy_options_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $accession_list_id = $c->req->param('accession_list_id');
    my $fuzzy_option_hash = decode_json($c->req->param('fuzzy_option_data'));
    #print STDERR Dumper $fuzzy_option_hash;
    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $accession_list_id } );

    my @names_to_add;
    foreach my $form_name (keys %$fuzzy_option_hash){
        my $item_name = $fuzzy_option_hash->{$form_name}->{'fuzzy_name'};
        my $select_name = $fuzzy_option_hash->{$form_name}->{'fuzzy_select'};
        my $fuzzy_option = $fuzzy_option_hash->{$form_name}->{'fuzzy_option'};
        if ($fuzzy_option eq 'replace'){
            $list->replace_by_name($item_name, $select_name);
        } elsif ($fuzzy_option eq 'keep'){
            push @names_to_add, $item_name;
        } elsif ($fuzzy_option eq 'remove'){
            $list->remove_by_name($item_name);
        } elsif ($fuzzy_option eq 'synonymize'){
            my $stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>$select_name})->stock_id();
            my $stock = CXGN::Chado::Stock->new($schema, $stock_id);
            $stock->add_synonym($item_name);
            #$list->replace_by_name($item_name, $select_name);
        }
    }

    my $rest = {
        success => "1",
        names_to_add => \@names_to_add
    };
    #print STDERR Dumper($rest);
    $c->stash->{rest} = $rest;
}


sub add_accession_list : Path('/ajax/accession_list/add') : ActionClass('REST') { }

sub add_accession_list_POST : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $accession_list_json = $c->req->param('accession_list');
  my $species_name = $c->req->param('species_name');
  my $population_name = $c->req->param('population_name');
  my $organization_name = $c->req->param('organization_name');
  my @accession_list;
  my $stock_add;
  my $validated;
  my $added;
  my $dbh = $c->dbc->dbh;
  my $user_id;
  my $owner_name;
  my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

  if (!$c->user()) {
    $c->stash->{rest} = {error => "You need to be logged in to create a field book" };
    return;
  }

  $user_id = $c->user()->get_object()->get_sp_person_id();
  $owner_name = $c->user()->get_object()->get_username();

  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to create a field book." };
    return;
  }

  @accession_list = @{_parse_list_from_json($accession_list_json)};
  if ($population_name eq '') {
      $stock_add = CXGN::Stock::AddStocks->new({ schema => $schema, stocks => \@accession_list, species => $species_name, owner_name => $owner_name,phenome_schema => $phenome_schema, dbh => $dbh, organization_name => $organization_name} );
  } else {
      $stock_add = CXGN::Stock::AddStocks->new({ schema => $schema, stocks => \@accession_list, species => $species_name, owner_name => $owner_name,phenome_schema => $phenome_schema, dbh => $dbh, population_name => $population_name, organization_name => $organization_name} );
  }
  $validated = $stock_add->validate_stocks();
  if (!$validated) {
    $c->stash->{rest} = {error =>  "Stocks already exist in the database" };
  }
  $added = $stock_add->add_accessions();
  if (!$added) {
    $c->stash->{rest} = {error =>  "Could not add stocks to the database" };
  }
  $c->stash->{rest} = {success => "1"};
  return;
}

sub populations : Path('/ajax/manage_accessions/populations') : ActionClass('REST') { }

sub populations_GET : Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $ac = CXGN::BreedersToolbox::Accessions->new( { schema=>$schema });
    my $populations = $ac->get_all_populations($c);

    $c->stash->{rest} = { populations => $populations };
}

sub _parse_list_from_json {
  my $list_json = shift;
  my $json = new JSON;
  if ($list_json) {
    my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
    #my $decoded_list = decode_json($list_json);
    my @array_of_list_items = @{$decoded_list};
    return \@array_of_list_items;
  }
  else {
    return;
  }
}


1;
