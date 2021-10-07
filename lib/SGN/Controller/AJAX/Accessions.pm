

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
use List::MoreUtils qw /any /;
use CXGN::Stock::StockLookup;
use CXGN::BreedersToolbox::Accessions;
use CXGN::BreedersToolbox::StocksFuzzySearch;
use CXGN::BreedersToolbox::OrganismFuzzySearch;
use CXGN::Stock::Accession;
use CXGN::Chado::Stock;
use CXGN::List;
use Data::Dumper;
use Try::Tiny;
use CXGN::Stock::ParseUpload;
use CXGN::BreederSearch;
use Encode;
#use Encode::Detect;
use JSON::XS qw | decode_json |;
use utf8;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );

sub verify_accession_list : Path('/ajax/accession_list/verify') : ActionClass('REST') { }

sub verify_accession_list_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $self->verify_accession_list_POST($c);
}

sub verify_accession_list_POST : Args(0) {
    my ($self, $c) = @_;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $accession_list_json = $c->req->param('accession_list');
    my $organism_list_json = $c->req->param('organism_list');
    my @accession_list = @{_parse_list_from_json($c, $accession_list_json)};
    my @organism_list = $organism_list_json ? @{_parse_list_from_json($c, $organism_list_json)} : [];

    my $do_fuzzy_search = $c->req->param('do_fuzzy_search');
    if ($user_role ne 'curator' && !$do_fuzzy_search) {
        $c->stash->{rest} = {error=>'Only a curator can add accessions without using the fuzzy search!'};
        $c->detach();
    }

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
    print STDERR "DoFuzzySearch 1".localtime()."\n";

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $fuzzy_accession_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
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

    my $fuzzy_search_result = $fuzzy_accession_search->get_matches(\@accession_list, $max_distance, 'accession');
    print STDERR "DoFuzzySearch 2".localtime()."\n";

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

    print STDERR "DoFuzzySearch 3".localtime()."\n";
    #print STDERR Dumper $fuzzy_accessions;

    my %return = (
        success => "1",
        absent => $absent_accessions,
        fuzzy => $fuzzy_accessions,
        found => $found_accessions,
        absent_organisms => $absent_organisms,
        fuzzy_organisms => $fuzzy_organisms,
        found_organisms => $found_organisms
    );

    if ($fuzzy_search_result->{'error'}){
        $return{error} = $fuzzy_search_result->{'error'};
    }

    $c->stash->{rest} = \%return;
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
        fuzzy => \@fuzzy_accessions,
        absent_organisms => [],
        fuzzy_organisms => [],
        found_organisms => []
    };

    #print STDERR Dumper($rest);
    $c->stash->{rest} = $rest;
}

sub verify_accessions_file : Path('/ajax/accessions/verify_accessions_file') : ActionClass('REST') { }
sub verify_accessions_file_POST : Args(0) {
    my ($self, $c) = @_;
    
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $upload = $c->req->upload('new_accessions_upload_file');
    my $do_fuzzy_search = $user_role eq 'curator' && !$c->req->param('fuzzy_check_upload_accessions') ? 0 : 1;

    if ($user_role ne 'curator' && !$do_fuzzy_search) {
        $c->stash->{rest} = {error=>'Only a curator can add accessions without using the fuzzy search!'};
        $c->detach();
    }

    # These roles are required by CXGN::UploadFile
    if ($user_role ne 'curator' && $user_role ne 'submitter' && $user_role ne 'sequencer' ) {
        $c->stash->{rest} = {error=>'Only a curator, submitter or sequencer can upload a file'};
        $c->detach();
    }

    my $subdirectory = "accessions_spreadsheet_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;

    my @editable_stock_props = split ',', $c->config->{editable_stock_props};
    my $parser = CXGN::Stock::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path, editable_stock_props=>\@editable_stock_props, do_fuzzy_search=>$do_fuzzy_search);
    $parser->load_plugin('AccessionsXLS');
    my $parsed_data = $parser->parse();

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
            $c->detach();
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_species => $parse_errors->{'missing_species'}};
        $c->detach();
    }

    my $full_data = $parsed_data->{parsed_data};
    my @accession_names;
    my %full_accessions;
    while (my ($k,$val) = each %$full_data){
        push @accession_names, $val->{germplasmName};
        $full_accessions{$val->{germplasmName}} = $val;
    }

    my $new_list_id = CXGN::List::create_list($c->dbc->dbh, "AccessionsIn".$upload_original_name.$timestamp, 'Autocreated when upload accessions from file '.$upload_original_name.$timestamp, $user_id);
    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id => $new_list_id } );

    $list->add_bulk(\@accession_names);
    $list->type('accessions');

    my %return = (
        success => "1",
        list_id => $new_list_id,
        full_data => \%full_accessions,
        absent => $parsed_data->{absent_accessions},
        fuzzy => $parsed_data->{fuzzy_accessions},
        found => $parsed_data->{found_accessions},
        absent_organisms => $parsed_data->{absent_organisms},
        fuzzy_organisms => $parsed_data->{fuzzy_organisms},
        found_organisms => $parsed_data->{found_organisms}
    );
    print STDERR "verify_accessions_file returns: " . Dumper %return;
    if ($parsed_data->{error_string}){
        $return{error_string} = $parsed_data->{error_string};
    }

        
    $c->stash->{rest} = \%return;
}

sub verify_fuzzy_options : Path('/ajax/accession_list/fuzzy_options') : ActionClass('REST') { }

sub verify_fuzzy_options_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $accession_list_id = $c->req->param('accession_list_id');
    my $fuzzy_option_hash = decode_json( encode("utf8", $c->req->param('fuzzy_option_data')));
    my $names_to_add = _parse_list_from_json($c, $c->req->param('names_to_add'));
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

    my $full_info = $c->req->param('full_info') ? _parse_list_from_json($c, $c->req->param('full_info')) : '';
    my $allowed_organisms = $c->req->param('allowed_organisms') ? _parse_list_from_json($c, $c->req->param('allowed_organisms')) : [];
    my %allowed_organisms = map {$_=>1} @$allowed_organisms;
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to submit accessions." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();

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
                    stock_id=>$_->{stock_id}, #For adding properties to an accessions
                    is_saving=>1,
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
                    acquisitionDate=>$_->{acquisitionDate},
                    transgenic=>$_->{transgenic},
                    notes=>$_->{notes},
                    state=>$_->{state},
                    variety=>$_->{variety},
                    genomeStructure=>$_->{genomeStructure},
                    ploidyLevel=>$_->{ploidyLevel},
                    locationCode=>$_->{locationCode},
                    introgression_parent=>$_->{introgression_parent},
                    introgression_backcross_parent=>$_->{introgression_backcross_parent},
                    introgression_map_version=>$_->{introgression_map_version},
                    introgression_chromosome=>$_->{introgression_chromosome},
                    introgression_start_position_bp=>$_->{introgression_start_position_bp},
                    introgression_end_position_bp=>$_->{introgression_end_position_bp},
                    other_editable_stock_props=>$_->{other_editable_stock_props},
                    sp_person_id => $user_id,
                    user_name => $user_name,
                    modification_note => 'Bulk load of accession information'
                });
                my $added_stock_id = $stock->store();
                push @added_stocks, $added_stock_id;
                push @added_fullinfo_stocks, [$added_stock_id, $_->{germplasmName}];
            }
        }
    };

    my $transaction_error;
    try {
        $schema->txn_do($coderef_bcs);
    } catch {
        $transaction_error =  $_;
    };
    if ($transaction_error) {
        $c->stash->{rest} = {error =>  "Transaction error storing stocks: $transaction_error" };
        print STDERR "Transaction error storing stocks: $transaction_error\n";
        return;
    }

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    #print STDERR Dumper \@added_fullinfo_stocks;
    $c->stash->{rest} = {
        success => "1",
        added => \@added_fullinfo_stocks
    };
    return;
}

sub possible_seedlots : Path('/ajax/accessions/possible_seedlots') : ActionClass('REST') { }
sub possible_seedlots_POST : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $people_schema = $c->dbic_schema('CXGN::People::Schema');
  my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');

  my $names = $c->req->body_data->{'names'};
  my $type = $c->req->body_data->{'type'};

  my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
  my $accession_manager = CXGN::BreedersToolbox::Accessions->new(schema=>$schema, people_schema=>$people_schema, phenome_schema=>$phenome_schema);

  my $synonyms;
  my @uniquenames;
  if ($type eq 'accessions'){
      $synonyms = $stock_lookup->get_stock_synonyms('any_name','accession',$names);
      @uniquenames = keys %{$synonyms};
  } else {
      @uniquenames = @$names;
  }

  my $seedlots = $accession_manager->get_possible_seedlots(\@uniquenames, $type);

  $c->stash->{rest} = {
      success => "1",
      seedlots=> $seedlots,
      synonyms=>$synonyms
  };
  return;
}

sub fuzzy_response_download : Path('/ajax/accession_list/fuzzy_download') : ActionClass('REST') { }

sub fuzzy_response_download_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $fuzzy_json = $c->req->param('fuzzy_response');
    my $fuzzy_response = decode_json(encode("utf8", $fuzzy_json));
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
    my $c = shift;
    my $list_json = shift;
    my $json = JSON::XS->new();

  if ($list_json) {
      #my $decoded_list = $json->allow_nonref->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
      debug($c, "LIST_JSON is utf8? ".utf8::is_utf8($list_json)." valid utf8? ".utf8::valid($list_json)."\n");
      my $decoded_list = $json->decode($list_json);# _json(encode("UTF-8", $list_json));
     #my $decoded_list = decode_json($list_json);
      
      my @array_of_list_items = ();
      if (ref($decoded_list) eq "ARRAY" ) {
	  @array_of_list_items = @{$decoded_list};
      }
      else {
	  debug($c, "Dont know what to do with $decoded_list");
      }

    return \@array_of_list_items;
  }
    else {

    return;
  }
}

sub debug {
    my $c = shift;
    my $message = shift;

    my $encoding = find_encoding($message);
#    open(my $F, ">> :encoding(UTF-8)", "/tmp/error_log.txt") || die "Can't open error_log.txt";

#    print $F "### Request from ".$c->req->referer()."\n";
#    print $F "### ENCODING: $encoding\n$message\n==========\n";
#    close($F);
}

1;
