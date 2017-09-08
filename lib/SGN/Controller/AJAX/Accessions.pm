
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
use CXGN::Stock::StockLookup;
use CXGN::BreedersToolbox::Accessions;
use CXGN::BreedersToolbox::AccessionsFuzzySearch;
use CXGN::BreedersToolbox::OrganismFuzzySearch;
use CXGN::Stock::Accession;
use CXGN::Chado::Stock;
use CXGN::List;
use Data::Dumper;
use Try::Tiny;
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
  my $organism_list_json = $c->req->param('organism_list');
  my @accession_list = @{_parse_list_from_json($accession_list_json)};
  my @organism_list = $organism_list_json ? @{_parse_list_from_json($organism_list_json)} : [];

  my $do_fuzzy_search = $c->req->param('do_fuzzy_search');

  if ($do_fuzzy_search) {
      $self->do_fuzzy_search($c, \@accession_list, \@organism_list);
  }
  else {
      $self->do_exact_search($c, \@accession_list, \@organism_list);
  }

}

sub do_fuzzy_search {
    my $self = shift;
    my $c = shift;
    my $accession_list = shift;
    my $organism_list = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $fuzzy_accession_search = CXGN::BreedersToolbox::AccessionsFuzzySearch->new({schema => $schema});
    my $fuzzy_organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
    my $max_distance = 0.2;
    my @accession_list = @$accession_list;
    my @organism_list = @$organism_list;
    my $found_accessions;
    my $fuzzy_accessions;
    my $absent_accessions;
    my $found_organisms;
    my $fuzzy_organisms;
    my $absent_organisms;

    if (!$c->user()) {
	$c->stash->{rest} = {error => "You need to be logged in to add accessions." };
	return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	$c->stash->{rest} = {error =>  "You have insufficient privileges to add accessions." };
	return;
    }
    #remove all trailing and ending spaces from accessions and organisms
    s/^\s+|\s+$//g for @accession_list;
    s/^\s+|\s+$//g for @organism_list;

    my $fuzzy_search_result = $fuzzy_accession_search->get_matches(\@accession_list, $max_distance);
    #print STDERR "\n\nAccessionFuzzyResult:\n".Data::Dumper::Dumper($fuzzy_search_result)."\n\n";

    $found_accessions = $fuzzy_search_result->{'found'};
    $fuzzy_accessions = $fuzzy_search_result->{'fuzzy'};
    $absent_accessions = $fuzzy_search_result->{'absent'};

    if (scalar @organism_list > 0){
        my $fuzzy_organism_result = $fuzzy_organism_search->get_matches(\@organism_list, $max_distance);
        $found_organisms = $fuzzy_organism_result->{'found'};
        $fuzzy_organisms = $fuzzy_organism_result->{'fuzzy'};
        $absent_organisms = $fuzzy_organism_result->{'absent'};
        #print STDERR "\n\nOrganismFuzzyResult:\n".Data::Dumper::Dumper($fuzzy_organism_result)."\n\n";
    }

    if (scalar(@$fuzzy_accessions)>0){
        my %synonym_hash;
        my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id;
        my $synonym_rs = $schema->resultset('Stock::Stock')->search({'stockprops.type_id'=>$synonym_type_id}, {join=>'stockprops', '+select'=>['stockprops.value'], '+as'=>['value']});
        while (my $r = $synonym_rs->next()){
            $synonym_hash{$r->get_column('value')} = $r->uniquename;
        }

        foreach (@$fuzzy_accessions){
            my $matches = $_->{matches};
            foreach my $m (@$matches){
                my $name = $m->{name};
                if (exists($synonym_hash{$name})){
                    $m->{is_synonym} = 1;
                    $m->{synonym_of} = $synonym_hash{$name};
                }
            }
        }
    }

    #print STDERR Dumper $fuzzy_accessions;

    $c->stash->{rest} = {
        success => "1",
        absent => $absent_accessions,
        fuzzy => $fuzzy_accessions,
        found => $found_accessions,
        absent_organisms => $absent_organisms,
        fuzzy_organisms => $fuzzy_organisms,
        found_organisms => $found_organisms
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
    my $names_to_add = decode_json($c->req->param('names_to_add'));
    #print STDERR Dumper $fuzzy_option_hash;
    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $accession_list_id } );

    my %names_to_add = map {$_ => 1} @$names_to_add;
    foreach my $form_name (keys %$fuzzy_option_hash){
        my $item_name = $fuzzy_option_hash->{$form_name}->{'fuzzy_name'};
        my $select_name = $fuzzy_option_hash->{$form_name}->{'fuzzy_select'};
        my $fuzzy_option = $fuzzy_option_hash->{$form_name}->{'fuzzy_option'};
        if ($fuzzy_option eq 'replace'){
            $list->replace_by_name($item_name, $select_name);
            delete $names_to_add{$item_name};
        } elsif ($fuzzy_option eq 'keep'){
            $names_to_add{$item_name} = 1;
        } elsif ($fuzzy_option eq 'remove'){
            $list->remove_by_name($item_name);
            delete $names_to_add{$item_name};
        } elsif ($fuzzy_option eq 'synonymize'){
            my $stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>$select_name})->stock_id();
            my $stock = CXGN::Chado::Stock->new($schema, $stock_id);
            $stock->add_synonym($item_name);
            #$list->replace_by_name($item_name, $select_name);
            delete $names_to_add{$item_name};
        }
    }

    my @names_to_add = sort keys %names_to_add;
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
    my $full_info = $c->req->param('full_info') ? decode_json $c->req->param('full_info') : '';
    my $allowed_organisms = $c->req->param('allowed_organisms') ? decode_json $c->req->param('allowed_organisms') : [];
    my %allowed_organisms = map {$_=>1} @$allowed_organisms;
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to submit accessions." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to submit accessions." };
        return;
    }

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $main_production_site_url = $c->config->{main_production_site_url};
    my @added_fullinfo_stocks;
    my @added_stocks;
    my $coderef_bcs = sub {
        foreach (@$full_info){
            if (exists($allowed_organisms{$_->{species}})){
                my $stock = CXGN::Stock::Accession->new({
                    schema=>$schema,
                    check_name_exists=>0,
                    main_production_site_url=>$main_production_site_url,
                    type=>'accession',
                    type_id=>$type_id,
                    species=>$_->{species},
                    #genus=>$_->{genus},
                    name=>$_->{defaultDisplayName},
                    uniquename=>$_->{germplasmName},
                    organization_name=>$_->{organizationName},
                    population_name=>$_->{populationName},
                    description=>$_->{description},
                    accessionNumber=>$_->{accessionNumber},
                    germplasmPUI=>$_->{germplasmPUI},
                    pedigree=>$_->{pedigree},
                    germplasmSeedSource=>$_->{germplasmSeedSource},
                    synonyms=>$_->{synonyms},
                    #commonCropName=>$_->{commonCropName},
                    instituteCode=>$_->{instituteCode},
                    instituteName=>$_->{instituteName},
                    biologicalStatusOfAccessionCode=>$_->{biologicalStatusOfAccessionCode},
                    countryOfOriginCode=>$_->{countryOfOriginCode},
                    typeOfGermplasmStorageCode=>$_->{typeOfGermplasmStorageCode},
                    #speciesAuthority=>$_->{speciesAuthority},
                    #subtaxa=>$_->{subtaxa},
                    #subtaxaAuthority=>$_->{subtaxaAuthority},
                    donors=>$_->{donors},
                    acquisitionDate=>$_->{acquisitionDate}
                });
                my $added_stock_id = $stock->store();
                push @added_stocks, $added_stock_id;
                push @added_fullinfo_stocks, [$added_stock_id, $_->{germplasmName}];
            }
        }
    };

    my $coderef_phenome = sub {
        foreach my $stock_id (@added_stocks) {
            $phenome_schema->resultset("StockOwner")->find_or_create({
                stock_id     => $stock_id,
                sp_person_id =>  $user_id,
            });
        }
    };

    my $transaction_error;
    my $transaction_error_phenome;
    try {
        $schema->txn_do($coderef_bcs);
    } catch {
        $transaction_error =  $_;
    };
    try {
        $phenome_schema->txn_do($coderef_phenome);
    } catch {
        $transaction_error_phenome =  $_;
    };
    if ($transaction_error || $transaction_error_phenome) {
        $c->stash->{rest} = {error =>  "Transaction error storing stocks: $transaction_error $transaction_error_phenome" };
        print STDERR "Transaction error storing stocks: $transaction_error $transaction_error_phenome\n";
        return;
    }
    #print STDERR Dumper \@added_fullinfo_stocks;
    $c->stash->{rest} = {
        success => "1",
        added => \@added_fullinfo_stocks
    };
    return;
}
sub possible_seedlots : Path('/ajax/accessions/possible_seedlots') : ActionClass('REST') { }
sub possible_seedlots_GET : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  
  my $names = $c->req->params()->{'name'};
  
  my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
  my $accession_manager = CXGN::BreedersToolbox::Accessions->new(schema=>$schema);
  
  my @uniquenames = keys %{$stock_lookup->get_stock_synonyms('any_name','accession',$names)};
  
  my $seedlots = $accession_manager->get_possible_seedlots(\@uniquenames);
    
  print STDERR $names;
  $c->stash->{rest} = {
      success => "1",
      seedlots=> $seedlots
  };
  return;
}

sub fuzzy_response_download : Path('/ajax/accession_list/fuzzy_download') : ActionClass('REST') { }

sub fuzzy_response_download_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $fuzzy_json = $c->req->param('fuzzy_response');
    my $fuzzy_response = decode_json $fuzzy_json;
    #print STDERR Dumper $fuzzy_response;

    my $synonym_hash_lookup = CXGN::Stock::StockLookup->new({schema => $schema})->get_synonym_hash_lookup();
    my @data_out;
    push @data_out, ['In Your List', 'Database Accession Match', 'Database Synonym Match', 'Database Saved Synonyms', 'Distance'];
    foreach (@$fuzzy_response){
        my $matches = $_->{matches};
        my $name = $_->{name};
        foreach my $m (@$matches){
            my $match_name = $m->{name};
            my $synonym_of = '';
            my $distance = $m->{distance};
            if ($m->{is_synonym}){
                $match_name = $m->{synonym_of};
                $synonym_of = $m->{name};
            }
            my $synonyms = $synonym_hash_lookup->{$match_name};
            my $synonyms_string = $synonyms ? join ',', @$synonyms : '';
            push @data_out, [$name, $match_name, $synonym_of, $synonyms_string, $distance];
        }
    }
    my $string ='';
    foreach (@data_out){
        $string .= join("," , map {qq("$_")} @$_);
        $string .= "\n";
    }
    $c->res->content_type("text/plain");
    $c->res->body($string);
}

sub populations : Path('/ajax/manage_accessions/populations') : ActionClass('REST') { }

sub populations_GET : Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $ac = CXGN::BreedersToolbox::Accessions->new( { schema=>$schema });
    my $populations = $ac->get_all_populations();

    $c->stash->{rest} = { populations => $populations };
}

sub population_members : Path('/ajax/manage_accessions/population_members') : ActionClass('REST') { }

sub population_members_GET : Args(1) {
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $ac = CXGN::BreedersToolbox::Accessions->new( { schema=>$schema });
    my $members = $ac->get_population_members($stock_id);

    $c->stash->{rest} = { data => $members };
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
