package CXGN::Stock::ParseUpload::Plugin::AccessionsGeneric;

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::BreedersToolbox::StocksFuzzySearch;
use CXGN::BreedersToolbox::OrganismFuzzySearch;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $editable_stockprops = $self->get_editable_stock_props();

    my @error_messages;
    my %errors;
    my %missing_accessions;

    # optional columns = these hard-coded columns plus any editable stock props
    my @optional_columns = ('description', 'synonyms', 'populationName', 'organizationName', 'locationCode', 'ploidyLevel', 'genomeStructure', 'variety', 'donor', 'donor institute', 'donor PUI', 'countryOfOriginCode', 'state', 'instituteCode', 'instituteName', 'biologicalStatusOfAccessionCode', 'notes', 'accessionNumber', 'germplasmPUI', 'germplasmSeedSource', 'typeOfGermplasmStorageCode', 'acquisitionDate', 'transgenic', 'introgression_parent', 'introgression_backcross_parent', 'introgression_chromosome', 'introgression_start_position_bp', 'introgression_end_position_bp');
    push @optional_columns, @$editable_stockprops;

    my $parser = CXGN::File::Parse->new(
      file => $filename,
      required_columns => [ 'accession_name', 'species_name' ],
      optional_columns => \@optional_columns,
      column_aliases => {
        'accession_name' => ['accession', 'accession_name', 'accession name', 'accessionName', 'germplasm', 'germplasm name', 'germplasmName'],
        'species_name' => ['species', 'species_name', 'species name', 'speciesName'],
        'synonyms' => ['synonym', 'synonyms', 'synonym(s)'],
        'populationName' => ['population name', 'population names', 'population name(s)', 'population_name', 'population_names', 'population_name(s)', 'populationName', 'populationNames', 'populationName(s)'],
        'organizationName' => ['organization_name', 'organization_names', 'organization_name(s)', 'organization name', 'organization names', 'organization name(s)', 'organizatioName', 'organizationNames', 'organizationName(s)', 'organization', 'organizations', 'organization(s)'],
        'locationCode' => ['location_code', 'location_codes', 'location_code(s)', 'location code', 'location codes', 'location code(s)', 'locationCode', 'locationCodes', 'locationCode(s)'],
        'ploidyLevel' => ['ploidy_level', 'ploidy_levels', 'ploidy_level(s)', 'ploidy level', 'ploidy levels', 'ploidy level(s)', 'ploidyLevel', 'ploidyLevels', 'ploidyLevel(s)'],
        'genomeStructure' => ['genome_structure', 'genome_structures', 'genome_structure(s)', 'genome structure', 'genome structures', 'genome structure(s)', 'genomeStructure', 'genomeStructures'],
        'variety' => ['varieties', 'varietys', 'variety(s)'],
        'donor' => ['donors', 'donor(s)'],
        'donor institute' => ['donor institutes', 'donor institute(s)', 'donor_institute', 'donor_institutes', 'donor_institute(s)', 'donorInstitute', 'donorInstitutes'],
        'donor PUI' => ['donor PUI', 'donor PUIs', 'donor PUI(s)', 'donor_PUI', 'donor_PUIs', 'donor_PUI(s)', 'donorPUI', 'donorPUIs', 'donorPUI(s)'],
        'countryOfOriginCode' => ['country of origin', 'country of origins', 'country of origin(s)', 'country_of_origin', 'country_of_origins', 'country_of_origin(s)', 'countryOfOrigin', 'countryOfOrigins', 'countryOfOriginCode'],
        'state' => ['states', 'state(s)'],
        'instituteCode' => ['institute code', 'institute codes', 'institute code(s)', 'institute_code', 'institute_codes', 'institute_code(s)', 'instituteCode', 'instituteCodes'],
        'instituteName' => ['institute name', 'institute names', 'institute name(s)', 'institute_name', 'institute_names', 'institute_name(s)', 'instituteName', 'instituteNames'],
        'biologicalStatusOfAccessionCode' => ['biological status of accession code', 'biological status of accession codes', 'biological status of accession code(s)', 'biological_status_of_accession_code', 'biological_status_of_accession_codes', 'biological_status_of_accession_code(s)', 'biologicalStatusOfAccessionCode', 'biologicalStatusOfAccessionCodes'],
        'notes' => ['note', 'notes', 'notes(s)'],
        'accessionNumber' => ['accession number', 'accession numbers', 'accession number(s)', 'accession_number', 'accession_numbers', 'accession_number(s)', 'accessionNumber', 'accessionNumbers'],
        'germplasmPUI' => ['PUI', 'PUI(s)', 'germplasmPUI'],
        'germplasmSeedSource' => ['seed source', 'seed_sources', 'seed_source(s)', 'germplasmSeedSource'],
        'typeOfGermplasmStorageCode' => ['type of germplasm storage code', 'type_of_germplasm_storage_code', 'type_of_germplasm_storage_code(s)', 'typeOfGermplasmStorageCode'],
        'acquisitionDate' => ['acquisition date', 'acquisition_date', 'acquisition_date(s)', 'acquisitionDate'],
        'transgenic' => ['transgenics', 'transgenic(s)'],
        'introgression_parent' => ['introgression_parent', 'introgression_parents', 'introgression_parent(s)'],
        'introgression_backcross_parent' => ['introgression_backcross_parent', 'introgression_backcross_parents', 'introgression_backcross_parent(s)'],
        'introgression_chromosome' => ['introgression_chromosome', 'introgression_chromosomes', 'introgression_chromosome(s)'],
        'introgression_start_position_bp' => ['introgression_start_position_bp', 'introgression_start_position_bps', 'introgression_start_position_bp(s)'],
        'introgression_end_position_bp' => ['introgression_end_position_bp', 'introgression_end_position_bps', 'introgression_end_position_bp(s)']
      },
      column_arrays => [ 'synonyms' ]
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my $additional_columns = $parsed->{additional_columns};

    # return if parsing error
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
      $errors{'error_messages'} = $parsed_errors;
      $self->_set_parse_errors(\%errors);
      return;
    }

    # return if unknown columns (neither required nor optional)
    if ( $additional_columns && scalar(@$additional_columns) > 0 ) {
      $errors{'error_messages'} = [
        "The following columns are not recognized: " . join(', ', @$additional_columns) . ". Please check the spreadsheet format for the allowed columns."
      ];
      $self->_set_parse_errors(\%errors);
      return;
    }

    # check for duplicate accession entries
    my %accession_name_counts;
    foreach my $row (@$parsed_data) {
      $accession_name_counts{$row->{'accession_name'}}++;
    }
    foreach my $k (keys %accession_name_counts) {
      if ($accession_name_counts{$k} > 1) {
        push @error_messages, "Accession $k occures $accession_name_counts{$k} times in the file. Accession names must be unique. Please remove duplicated accession names.";
      }
    }

    # check validity of species names
    my $seen_species_names = $parsed_values->{'species_name'};
    my $species_validator = CXGN::List::Validate->new();
    my @species_missing = @{$species_validator->validate($schema,'species',$seen_species_names)->{'missing'}};
    if (scalar(@species_missing) > 0) {
        push @error_messages, "The following species are not in the database as species in the organism table: ".join(',',@species_missing);
        $errors{'missing_species'} = \@species_missing;
    }

    # Check for existing non-accession stocks
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $accession_list = $parsed_values->{'accession_name'};
    my $stocks_in_db_rs = $schema->resultset("Stock::Stock")->search({ uniquename => { -ilike => $accession_list }, type_id => { '<>' => $accession_type_id } });
    my @stocks_existing;
    while ( my $r=$stocks_in_db_rs->next ) {
      push @stocks_existing, $r->uniquename;
    }
    if ( scalar(@stocks_existing) > 0 ) {
      push @error_messages, "The following accession names are already used in the database (as different stock types): " . join(',', @stocks_existing);
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # cache parsed data for _parse_with_plugin function
    $self->_set_parsed_data($parsed);

    return 1; #returns true if validation is passed

}


sub _parse_with_plugin {
  my $self = shift;
  my $schema = $self->get_chado_schema();
  my $do_fuzzy_search = $self->get_do_fuzzy_search();
  my $append_synonyms = $self->get_append_synonyms();
  my $editable_stockprops = $self->get_editable_stock_props();
  my %editable_stockprops_map = map {$_ => 1} @$editable_stockprops;

  # Get cached parsed data from _validate_with_plugin function
  my $parsed = $self->_parsed_data();
  my $parsed_data = $parsed->{data};
  my $parsed_values = $parsed->{values};
  my $parsed_columns = $parsed->{columns};
  my $additional_columns = $parsed->{additional_columns};
  my %additional_columns_map = map {$_ => 1} @$additional_columns;

  my $accession_list = $parsed_values->{'accession_name'};
  my $synonyms_list = $parsed_values->{'synonyms'} || [];
  my $organism_list = $parsed_values->{'species_name'};
  my %accession_lookup;
  my $accessions_in_db_rs = $schema->resultset("Stock::Stock")->search({uniquename=>{-ilike=>$accession_list}});
  while(my $r=$accessions_in_db_rs->next){
    $accession_lookup{$r->uniquename} = $r->stock_id;
  }

  my %parsed_entries;
  for my $row ( @$parsed_data ) {
    my $row_num = $row->{_row};
    my $accession = $row->{'accession_name'};
    my $synonyms = $row->{'synonyms'} || [];
    my $description = $row->{'description'} || '';
    my $stock_id;
    if(exists($accession_lookup{$accession})){
      $stock_id = $accession_lookup{$accession};
    }

    my %row_info = (
      germplasmName => $accession,
      defaultDisplayName => $accession,
      species => $row->{'species_name'},
      populationName => $row->{'populationName'},
      organizationName => $row->{'organizationName'},
      synonyms => $synonyms,
      description => $description,
    );

    #For "updating" existing accessions by adding properties.
    if ($stock_id){
      $row_info{stock_id} = $stock_id;

      # lookup existing accessions, if append_synonyms is selected
      if ( $append_synonyms ) {
        my @existing_synonyms;
        my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
        my $rs = $schema->resultset("Stock::Stockprop")->search({ type_id => $synonym_type_id, stock_id => $stock_id });
        while( my $r = $rs->next() ) {
          push(@existing_synonyms, $r->value);
        }
        push(@existing_synonyms, @$synonyms);
        s{^\s+|\s+$}{}g foreach @existing_synonyms;
        $row_info{synonyms} = \@existing_synonyms;
      }
    }

    # Process the stockprops...
    foreach my $col ( @$parsed_columns ) {
      my $stockprops_value = $row->{$col};

      # ... skipping the basic items already included in the row_info
      next if ( $col eq 'accession_name' || $col eq 'species_name' || $col eq 'populationName' || $col eq 'organizationName' || $col eq 'synonyms');

      # ... skip empty / blank values
      next if !$stockprops_value;
      next if ref($stockprops_value) eq 'ARRAY' && scalar(@$stockprops_value) == 0;

      # Process the stockprop...
      if ( $col eq 'donor' || $col eq 'donor institute' || $col eq 'donor PUI' ) {
        my %donor_key_map = (
          'donor'=>'donorGermplasmName',
          'donor institute'=>'donorInstituteCode',
          'donor PUI'=>'germplasmPUI'
        );
        if (exists($row_info{'donors'})) {
          my $donors_hash = $row_info{donors}->[0];
          $donors_hash->{$donor_key_map{$col}} = $stockprops_value;
          $row_info{'donors'} = [$donors_hash];
        }
        else {
          $row_info{'donors'} = [{ $donor_key_map{$col} => $stockprops_value }];
        }
      }
      elsif ( exists($editable_stockprops_map{$col}) ) {
        $row_info{other_editable_stock_props}->{$col} = $stockprops_value;
      }
      else {
        $row_info{$col} = $stockprops_value;
      }
    }

    $parsed_entries{$row_num} = \%row_info;
  }

  my $fuzzy_accession_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
  my $fuzzy_organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
  my $max_distance = 0.2;
  my $found_accessions = [];
  my $fuzzy_accessions = [];
  my $absent_accessions = [];
  my $found_synonyms = [];
  my $fuzzy_synonyms = [];
  my $absent_synonyms = [];
  my $found_organisms;
  my $fuzzy_organisms;
  my $absent_organisms;
  my %return_data;

  if ($do_fuzzy_search) {
      my $fuzzy_search_result = $fuzzy_accession_search->get_matches($accession_list, $max_distance, 'accession');

      $found_accessions = $fuzzy_search_result->{'found'};
      $fuzzy_accessions = $fuzzy_search_result->{'fuzzy'};
      $absent_accessions = $fuzzy_search_result->{'absent'};

      if (scalar @$synonyms_list > 0){
          my $fuzzy_synonyms_result = $fuzzy_accession_search->get_matches($synonyms_list, $max_distance, 'accession');
          $found_synonyms = $fuzzy_synonyms_result->{'found'};
          $fuzzy_synonyms = $fuzzy_synonyms_result->{'fuzzy'};
          $absent_synonyms = $fuzzy_synonyms_result->{'absent'};
      }

      if (scalar @$organism_list > 0){
          my $fuzzy_organism_result = $fuzzy_organism_search->get_matches($organism_list, $max_distance);
          $found_organisms = $fuzzy_organism_result->{'found'};
          $fuzzy_organisms = $fuzzy_organism_result->{'fuzzy'};
          $absent_organisms = $fuzzy_organism_result->{'absent'};
      }

      if ($fuzzy_search_result->{'error'}){
          $return_data{error_string} = $fuzzy_search_result->{'error'};
      }
  } else {
      my $validator = CXGN::List::Validate->new();
      my $absent_accessions = $validator->validate($schema, 'accessions', $accession_list)->{'missing'};
      my %accessions_missing_hash = map { $_ => 1 } @$absent_accessions;

      foreach (@$accession_list){
          if (!exists($accessions_missing_hash{$_})){
              push @$found_accessions, { unique_name => $_,  matched_string => $_};
              push @$fuzzy_accessions, { unique_name => $_,  matched_string => $_};
          }
      }
  }

  %return_data = (
      parsed_data => \%parsed_entries,
      found_accessions => $found_accessions,
      fuzzy_accessions => $fuzzy_accessions,
      absent_accessions => $absent_accessions,
      found_synonyms => $found_synonyms,
      fuzzy_synonyms => $fuzzy_synonyms,
      absent_synonyms => $absent_synonyms,
      found_organisms => $found_organisms,
      fuzzy_organisms => $fuzzy_organisms,
      absent_organisms => $absent_organisms
  );
  print STDERR "\n\nAccessionsGeneric parsed results :\n".Data::Dumper::Dumper(%return_data)."\n\n";

  $self->_set_parsed_data(\%return_data);
  return 1;
}


1;
