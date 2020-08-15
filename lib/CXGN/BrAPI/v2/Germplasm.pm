package CXGN::BrAPI::v2::Germplasm;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Stock::Search;
use CXGN::Stock;
use CXGN::Chado::Organism;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use CXGN::Cross;
use Try::Tiny;

extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @data_files;

    my $crop_names_arrayref = $params->{commonCropName} || ($params->{commonCropNames} || ());
    my $germplasm_names_arrayref = $params->{germplasmName} || ($params->{germplasmNames} || ());
    my $accession_numbers_arrayref = $params->{accessionNumber} || ($params->{accessionNumbers} || ());
    my $genera_arrayref = $params->{genus} || ($params->{genera} || ());
    my $germplasm_ids_arrayref  = $params->{germplasmDbId} || ($params->{germplasmDbIds} || ());
    my $germplasm_puis_arrayref = $params->{germplasmPUI} || ($params->{germplasmPUIs} || ());
    my $species_arrayref = $params->{species} || ($params->{species} || ());
    my $synonyms_arrayref = $params->{synonym} || ($params->{synonyms} || ());
    my $subtaxa = $params->{germplasmSubTaxa}->[0];
    my $match_method = $params->{matchMethod}->[0] || 'exact';  
    my $collection = $params->{collection} || ($params->{collections} || ());
    my $study_db_id = $params->{studyDbId} || ($params->{studyDbIds} || ());
    my $study_names = $params->{studyName} || ($params->{studyNames} || ());
    my $parent_db_id = $params->{parentDbId} || ($params->{parentDbIds} || ());
    my $progeny_db_id = $params->{progenyDbId} || ($params->{progenyDbIds} || ());
    my $external_reference_id = $params->{externalReferenceID} || ($params->{externalReferenceIDs} || ());
    my $external_reference_source = $params->{externalReferenceSource} || ($params->{externalReferenceSources} || ());

    if ( $collection || $external_reference_id || $external_reference_source || $progeny_db_id || $parent_db_id ){
        push @$status, { 'error' => 'The following search parameters are not implemented: collection, externalReferenceID, externalReferenceSource,parentDbId,progenyDbId' };
    }

    if ($match_method ne 'exact' && $match_method ne 'wildcard') {
        push @$status, { 'error' => "matchMethod '$match_method' not recognized. Allowed matchMethods: wildcard, exact. Wildcard allows % or * for multiple characters and ? for single characters." };
    }
    my $match_type;
    if ($match_method eq 'exact'){
        $match_type = 'exactly';
    }
    if ($match_method eq 'wildcard'){
        $match_type = 'contains';
    }

    my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();

    my $limit = $page_size*($page+1)-1;
    my $offset = $page_size*$page;

    my %stockprops_values;
    if ($accession_numbers_arrayref && scalar(@$accession_numbers_arrayref)>0){
        foreach (@$accession_numbers_arrayref) {
            $stockprops_values{'accession number'} = {
                matchtype => 'contains',
                value => $_
            };
        }
    }
    if ($germplasm_puis_arrayref && scalar(@$germplasm_puis_arrayref)>0){
        foreach (@$germplasm_puis_arrayref) {
            $stockprops_values{'PUI'} = {
                matchtype => 'contains',
                value => $_
            };
        }
    }
    if ($synonyms_arrayref && scalar(@$synonyms_arrayref)>0){
        foreach (@$synonyms_arrayref) {
            $stockprops_values{'stock_synonym'} = {
                matchtype => 'contains',
                value => $_
            };
        }
    }

    my $stock_search = CXGN::Stock::Search->new({
        bcs_schema=>$self->bcs_schema,
        people_schema=>$self->people_schema,
        phenome_schema=>$self->phenome_schema,
        match_type=>$match_type,
        uniquename_list=>$germplasm_names_arrayref,
        genus_list=>$genera_arrayref,
        species_list=>$species_arrayref,
        crop_name_list=>$crop_names_arrayref,
        stock_id_list=>$germplasm_ids_arrayref,
        stock_type_id=>$accession_type_cvterm_id,
        stockprops_values=>\%stockprops_values,
        stockprop_columns_view=>{'accession number'=>1, 'PUI'=>1, 'seed source'=>1, 'institute code'=>1, 'institute name'=>1, 'biological status of accession code'=>1, 'country of origin'=>1, 'type of germplasm storage code'=>1, 'acquisition date'=>1, 'ncbi_taxonomy_id'=>1},
        trial_id_list=>$study_db_id,
        trial_name_list=>$study_names,
        limit=>$limit,
        offset=>$offset,
        display_pedigree=>1
    });
    my ($result, $total_count) = $stock_search->search();

    my @data;
    foreach (@$result){
        # my @type_of_germplasm_storage_codes = $_->{'type of germplasm storage code'} ? split ',', $_->{'type of germplasm storage code'} : ();
        my @type_of_germplasm_storage_codes;
        if($_->{'type of germplasm storage code'}){
            my @items = split ',', $_->{'type of germplasm storage code'};
            foreach(@items){
                push @type_of_germplasm_storage_codes ,{
                    code=>$_,
                    description=>undef
                };
            }
        }
        my @donors = {
            donorAccessionNumber=>$_->{donors}->[0]->{donorAccessionNumber},
            donorInstituteCode=>$_->{donors}->[0]->{donorInstituteCode},
            germplasmPUI=>$_->{donors}->[0]->{germplasmPUI}
        };
        my @synonyms;
        if($_->{synonyms}){
            foreach(@{ $_->{synonyms} }){
                push @synonyms, {
                    synonym=>$_,
                    type=>undef
                };
            }
        }
        my @ncbi_taxon_ids = split ',', $_->{'ncbi_taxonomy_id'};
        my @taxons;
        foreach (@ncbi_taxon_ids){
            push @taxons, {
                sourceName => 'NCBI',
                taxonId => $_
            };
        }
        push @data, {
            accessionNumber=>$_->{'accession number'},
            acquisitionDate=>$_->{'acquisition date'},
            additionalInfo=>undef,
            biologicalStatusOfAccessionCode=>$_->{'biological status of accession code'} || 0,
            biologicalStatusOfAccessionDescription=>undef,
            breedingMethodDbId=>undef,
            collection=>undef,
            commonCropName=>$_->{common_name},
            countryOfOriginCode=>$_->{'country of origin'},
            defaultDisplayName=>$_->{stock_name},
            documentationURL=>$_->{'PUI'},
            donors=>\@donors,
            externalReferences=>[],
            genus=>$_->{genus},
            germplasmName=>$_->{uniquename},
            germplasmOrigin=>[],
            germplasmDbId=>qq|$_->{stock_id}|,
            germplasmPUI=>$_->{'PUI'},     
            germplasmPreprocessing=>undef,
            instituteCode=>$_->{'institute code'},
            instituteName=>$_->{'institute name'},
            pedigree=>$_->{pedigree},
            seedSource=>$_->{'seed source'},
            seedSourceDescription=>$_->{'seed source'}, 
            species=>$_->{species},
            speciesAuthority=>$_->{speciesAuthority},
            storageTypes=>\@type_of_germplasm_storage_codes,
            subtaxa=>$_->{subtaxa},
            subtaxaAuthority=>$_->{subtaxaAuthority},
            synonyms=> \@synonyms,
            taxonIds=>\@taxons,
        };
    }

    my %result = (data => \@data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm result constructed');
}

sub germplasm_detail {
    my $self = shift;
    my $stock_id = shift;

    my $status = $self->status;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my @data_files;

    my $verify_id = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$stock_id});
    if (!$verify_id) {
        return CXGN::BrAPI::JSONResponse->return_error($status, 'GermplasmDbId does not exist in the database');
    }

    my @result = _simple_search($self,[$stock_id]);
    my $total_count = scalar(@result);

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(@result, $pagination, \@data_files, $status, 'Germplasm detail result constructed');
}

sub germplasm_pedigree {
    my $self = shift;
    my $inputs = shift;
    my $stock_id = $inputs->{stock_id};
    my $notation = $inputs->{notation};
    my $status = $self->status;
    if ($notation) {
        push @$status, { 'info' => 'Notation not yet implemented. Returns a simple parent1/parent2 string.' };
        if ($notation ne 'purdy') {
            push @$status, { 'error' => "Unsupported notation code '$notation'. Allowed notation: 'purdy'" };
        }
    }

    my %result;
    my @data_files;
    my $total_count = 0;
    my $s = CXGN::Stock->new( schema => $self->bcs_schema(), stock_id => $stock_id);
    if ($s) {
        $total_count = 1;
        my $uniquename = $s->uniquename;
        my $parents = $s->get_parents();
        my $pedigree_string = $s->get_pedigree_string('Parents');
        my $female_name = $parents->{'mother'};
        my $male_name = $parents->{'father'};
        my $female_id = $parents->{'mother_id'};
        my $male_id = $parents->{'father_id'};

        my $cross_info = CXGN::Cross->get_cross_info_for_progeny($self->bcs_schema, $female_id, $male_id, $stock_id);
        my $cross_id = $cross_info ? $cross_info->[0] : '';
        my $cross_name = $cross_info ? $cross_info->[1] : '';
        my $cross_year = $cross_info ? $cross_info->[3] : '';
        my $cross_type = $cross_info ? $cross_info->[2] : '';

        my @siblings;
        if ($female_name || $male_name){
            my $progenies = CXGN::Cross->get_progeny_info($self->bcs_schema, $female_name, $male_name);
            #print STDERR Dumper $progenies;
            foreach (@$progenies){
                if ($_->[5] ne $uniquename){
                    my $germplasm_id = $_->[4];
                    push @siblings, {
                        germplasmDbId => qq|$germplasm_id|,
                        germplasmName => $_->[5]
                    };
                }
            }
        }
        my $parent = [
            {
                germplasmDbId=>qq|$female_id|,
                germplasmName=>$female_name,
                parentType=>'FEMALE',
            },
            {
                germplasmDbId=>qq|$male_id|,
                germplasmName=>$male_name,
                parentType=>'MALE',
            },
            ];

        %result = (
                # defaultDisplayName=>$uniquename,
            crossingProjectDbId=>undef,
                # crossingPlan=>$cross_type,
            crossingYear=>$cross_year,
            familyCode=>$cross_name,
            germplasmDbId=>qq|$stock_id|,
            germplasmName=>$uniquename,
            parents=>$parent,
            pedigree=>$pedigree_string,
            siblings=>\@siblings
        );
    }

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,1,0);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm pedigree result constructed');
}

sub germplasm_progeny {
    my $self = shift;
    my $inputs = shift;
    my $stock_id = $inputs->{stock_id};
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $mother_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $father_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();

    my $stock = $self->bcs_schema()->resultset("Stock::Stock")->find({
        'type_id'=> $accession_cvterm,
        'stock_id'=> $stock_id,
    });
    my $edges = $self->bcs_schema()->resultset("Stock::StockRelationship")->search(
        [
            {
                'me.subject_id' => $stock_id,
                'me.type_id' => $father_cvterm,
                'object.type_id'=> $accession_cvterm
            },
            {
                'me.subject_id' => $stock_id,
                'me.type_id' => $mother_cvterm,
                'object.type_id'=> $accession_cvterm
            }
        ],
        {
            join => 'object',
            '+select' => ['object.uniquename'],
            '+as' => ['progeny_uniquename']
        }
    );
    my $full_data = [];
    while (my $edge = $edges->next) {
        if ($edge->type_id==$mother_cvterm){
            push @{$full_data}, {
                germplasmDbId => "". $edge->object_id,
                germplasmName => $edge->get_column('progeny_uniquename'),
                parentType => "FEMALE"
            };
        } else {
            push @{$full_data}, {
                germplasmDbId => "". $edge->object_id,
                germplasmName => $edge->get_column('progeny_uniquename'),
                parentType => "MALE"
            };
        }
    }
    my $total_count = scalar @{$full_data};
    my $last_item = $page_size*($page+1)-1;
    if($last_item > $total_count-1){
        $last_item = $total_count-1;
    }
    my $result = {
        germplasmName=>$stock->uniquename,
        germplasmDbId=>$stock_id,
        progeny=>[@{$full_data}[$page_size*$page .. $last_item]],
    };
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success($result, $pagination, \@data_files, $status, 'Germplasm progeny result constructed');
}

sub germplasm_mcpd {
    my $self = shift;
    my $stock_id = shift;

    my $status = $self->status;
    my $page_size = $self->page_size;
    my $page = $self->page;

    my $schema = $self->bcs_schema();
        my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();

    my $stock_search = CXGN::Stock::Search->new({
        bcs_schema=>$self->bcs_schema,
        people_schema=>$self->people_schema,
        phenome_schema=>$self->phenome_schema,
        match_type=>'exactly',
        stock_id_list=>[$stock_id],
        stock_type_id=>$accession_type_cvterm_id,
        stockprop_columns_view=>{'accession number'=>1, 'PUI'=>1, 'seed source'=>1, 'institute code'=>1, 'institute name'=>1, 'biological status of accession code'=>1, 'country of origin'=>1, 'type of germplasm storage code'=>1, 'acquisition date'=>1, 'ncbi_taxonomy_id'=>1},
        display_pedigree=>1
    });
    
    my ($result, $total_count) = $stock_search->search();

    my %result;

    foreach (@$result){
        my $donors = $_->{donors};
        my @donors;
        foreach(@$donors){
            push @donors, {
                donorAccessionNumber=>$_->{donorAccessionNumber},
                donorInstitute=>{
                    instituteCode=>$_->{donorInstituteCode},
                    instituteName=>undef,
                },
                donorAccessionPui=>$_->{germplasmPUI}
            };
        }

        my @type_of_germplasm_storage_codes;
        if($_->{'type of germplasm storage code'}){
            my @items = split ',', $_->{'type of germplasm storage code'};
            foreach(@items){
                push @type_of_germplasm_storage_codes, $_;
            }
        }
        my @names;
        if($_->{uniquename}){
            push @names, $_->{uniquename};
        }
        if($_->{synonyms}){
            foreach(@{ $_->{synonyms} }){
                push @names, $_;
            }
        }
        if($_->{stock_name}){
            push @names, $_->{stock_name};
        }

        my @ids;
        if($_->{stock_id}){
            push @ids, $_->{stock_id};
        }
        if($_->{'PUI'}){
            push @ids, $_->{'PUI'};
        }
        if($_->{ncbi_taxonomy_id}){
            push @ids, $_->{ncbi_taxonomy_id};
        }

        %result = (
            accessionNames=>\@names,
            alternateIDs=>\@ids,
            breedingInstitutes=>{
                instituteCode=>$_->{'institute code'},
                instituteName=>$_->{'institute name'},
            },
            collectingInfo=>{},
            mlsStatus=> undef,
            remarks=>undef,
            safetyDuplicateInstitutes=>undef,
            germplasmDbId=>qq|$_->{stock_id}|,
            accessionNumber=>$_->{'accession number'},
            germplasmPUI=>$_->{'PUI'},
            ancestralData=>$_->{pedigree},
            commonCropName=>$_->{common_name},
            instituteCode=>$_->{'institute code'}, 
            biologicalStatusOfAccessionCode=>$_->{'biological status of accession code'} || 0,
            countryOfOrigin=>$_->{'country of origin'},
            storageTypeCodes=>\@type_of_germplasm_storage_codes, 
            genus=>$_->{genus},
            species=>$_->{species},
            speciesAuthority=>$_->{speciesAuthority},
            subtaxon=>$_->{subtaxa},
            subtaxonAuthority=>$_->{subtaxaAuthority},
            donorInfo=>\@donors, 
            acquisitionDate=>$_->{'acquisition date'}
        );
    }
    my $total_count = (%result) ? 1 : 0;
    my @data_files;

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm detail result constructed');

}

sub store {
    my $self = shift;
    my $data = shift;
    my $user_id = shift;
    my $c = shift;

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
    }

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $schema = $self->bcs_schema;
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $user_name = $person->get_username;

    my $page_obj = CXGN::Page->new();
    my $main_production_site_url = $page_obj->get_hostname();

    my $accession_list;
    my $organism_list;

    foreach (@$data){
        my $accession = $_->{germplasmName} || undef;
        my $organism = $_->{species} || undef;
        push @$accession_list, $accession;
        push @$organism_list, $organism;
    }

    #validate accessions
    my $validator = CXGN::List::Validate->new();
    my @absent_accessions = @{$validator->validate($schema, 'accessions', $accession_list)->{'missing'}};
    my %accessions_missing_hash = map { $_ => 1 } @absent_accessions;
    my $existing_accessions = '';

    foreach (@$accession_list){
        if (!exists($accessions_missing_hash{$_})){
            $existing_accessions = $existing_accessions . $_ ."," ;
        }
    }

    if (length($existing_accessions) >0){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Existing germplasm in the database: %s', $existing_accessions));
    }

    #validate organism
    my $organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
    my $organism_result = $organism_search->get_matches($organism_list, '1');

    my @allowed_organisms;
    my $missing_organisms = '';
    my $found = $organism_result->{found};

    foreach (@$found){
        push @allowed_organisms, $_->{unique_name};
    }
    my %allowed_organisms = map {$_=>1} @allowed_organisms;

    foreach (@$organism_list){
        if (!exists($allowed_organisms{$_})){
            $missing_organisms = $missing_organisms . $_ . ",";
        }
    }
    if (length($missing_organisms) >0){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Organisms were not found on the database: %s', $missing_organisms));
    }

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my @added_stocks;
    my $coderef_bcs = sub {
        foreach my $params (@$data){
            my $species = $params->{species} || undef;
            my $name = $params->{defaultDisplayName} || undef;
            my $uniquename = $params->{germplasmName} || undef;
            my $accessionNumber = $params->{accessionNumber} || undef;
            my $germplasmPUI = $params->{germplasmPUI} || undef;
            my $germplasmSeedSource = $params->{seedSource} || undef;
            my $synonyms = $params->{synonyms}->[0]->{synonym} || undef;
            my $instituteCode = $params->{instituteCode} || undef;
            my $instituteName = $params->{instituteName} || undef;
            my $biologicalStatusOfAccessionCode = $params->{biologicalStatusOfAccessionCode} || undef;
            my $countryOfOriginCode = $params->{countryOfOriginCode} || undef;
            my $typeOfGermplasmStorageCode = $params->{storageTypes}->[0]->{code} || undef;
            my $donors = $params->{donors} || undef;
            my $acquisitionDate = $params->{acquisitionDate} || undef;
            #adding breedbase specific info using additionalInfo
            my $organization_name = $params->{additionalInfo}->{organizationName} || undef;
            my $population_name = $params->{additionalInfo}->{populationName} || undef;
            my $transgenic = $params->{additionalInfo}->{transgenic} || undef;
            my $notes = $params->{additionalInfo}->{notes} || undef;
            my $state = $params->{additionalInfo}->{state} || undef;
            my $variety = $params->{additionalInfo}->{variety} || undef;
            my $locationCode = $params->{additionalInfo}->{locationCode} || undef;
            my $description = $params->{additionalInfo}->{description} || undef;
            my $stock_id = $params->{additionalInfo}->{stock_id} || undef;
            #not supported
            # speciesAuthority
            # genus
            # commonCropName
            # biologicalStatusOfAccessionDescription
            # germplasmSeedSourceDescription
            # breedingMethodDbId
            # collection
            # documentationURL
            # externalReferences
            # germplasmOrigin
            # germplasmPreprocessing
            # taxonIds
            # subtaxa
            # subtaxaAuthority
            # pedigree

            if (exists($allowed_organisms{$species})){
                my $stock = CXGN::Stock::Accession->new({
                    schema=>$schema,
                    check_name_exists=>0,
                    main_production_site_url=>$main_production_site_url,
                    type=>'accession',
                    type_id=>$type_id,
                    species=>$species,
                    name=>$name,
                    uniquename=>$uniquename,
                    organization_name=>$organization_name,
                    population_name=>$population_name,
                    description=>$description,
                    accessionNumber=>$accessionNumber,
                    germplasmPUI=>$germplasmPUI,
                    germplasmSeedSource=>$germplasmSeedSource,
                    synonyms=>[$synonyms],
                    instituteCode=>$instituteCode,
                    instituteName=>$instituteName,
                    biologicalStatusOfAccessionCode=>$biologicalStatusOfAccessionCode,
                    countryOfOriginCode=>$countryOfOriginCode,
                    typeOfGermplasmStorageCode=>$typeOfGermplasmStorageCode,
                    donors=>$donors,
                    acquisitionDate=>$acquisitionDate,
                    transgenic=>$transgenic,
                    notes=>$notes,
                    state=>$state,
                    variety=>$variety,
                    locationCode=>$locationCode,
                    sp_person_id => $user_id,
                    user_name => $user_name,
                    modification_note => 'Bulk load of accession information'
                });
                my $added_stock_id = $stock->store();
                push @added_stocks, $added_stock_id;
            }
        }
    };

    #save data
    my $transaction_error;

    try {
       $schema->txn_do($coderef_bcs);
    } 
    catch {
        $transaction_error = $_;
    };

    if ($transaction_error){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('There was an error storing germplasm %s', $transaction_error));
    }

    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    #retrieve saved items
    my @data = _simple_search($self,undef,$accession_list);
    my $total_count = scalar(@data);

    my @data_files;
    my %result = (data => \@data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm saved');

}

sub update {
    my $self = shift;
    my $germplasm_id = shift;
    my $data = shift;
    my $user_id = shift;
    my $c = shift;

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
    }

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $schema = $self->bcs_schema;
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $person = CXGN::People::Person->new($dbh, $user_id);
    my $user_name = $person->get_username;

    my $verify_id = $schema->resultset('Stock::Stock')->find({stock_id=>$germplasm_id});
    if (!$verify_id) {
        return CXGN::BrAPI::JSONResponse->return_error($status, 'GermplasmDbId does not exist in the database');
    }

    my $page_obj = CXGN::Page->new();
    my $main_production_site_url = $page_obj->get_hostname();

    #validate organism
    my $organism_list;

    foreach (@$data){
        my $organism = $_->{species} || undef;
        push @$organism_list, $organism;
    }

    my $organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
    my $organism_result = $organism_search->get_matches($organism_list, '1');

    my @allowed_organisms;
    my $missing_organisms = '';
    my $found = $organism_result->{found};

    foreach (@$found){
        push @allowed_organisms, $_->{unique_name};
    }
    my %allowed_organisms = map {$_=>1} @allowed_organisms;

    foreach (@$organism_list){
        if (!exists($allowed_organisms{$_})){
            $missing_organisms = $missing_organisms . $_ . ",";
        }
    }
    if (length($missing_organisms) >0){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Organisms were not found on the database: %s', $missing_organisms));
    }

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    #sub rutine to save data
    my @added_stocks;
    my $coderef_bcs = sub {
        foreach my $params (@$data){
            my $species = $params->{species} || undef;
            my $name = $params->{defaultDisplayName} || undef;
            my $uniquename = $params->{germplasmName} || undef;
            my $accessionNumber = $params->{accessionNumber} || undef;
            my $germplasmPUI = $params->{germplasmPUI} || undef;
            my $germplasmSeedSource = $params->{seedSource} || undef;
            my $synonyms = $params->{synonyms}->[0]->{synonym} || undef;
            my $instituteCode = $params->{instituteCode} || undef;
            my $instituteName = $params->{instituteName} || undef;
            my $biologicalStatusOfAccessionCode = $params->{biologicalStatusOfAccessionCode} || undef;
            my $countryOfOriginCode = $params->{countryOfOriginCode} || undef;
            my $typeOfGermplasmStorageCode = $params->{storageTypes}->[0]->{code} || undef;
            my $donors = $params->{donors} || undef;
            my $acquisitionDate = $params->{acquisitionDate} || undef;
            #adding breedbase specific info using additionalInfo
            my $organization_name = $params->{additionalInfo}->{organizationName} || undef;
            my $population_name = $params->{additionalInfo}->{populationName} || undef;
            my $transgenic = $params->{additionalInfo}->{transgenic} || undef;
            my $notes = $params->{additionalInfo}->{notes} || undef;
            my $state = $params->{additionalInfo}->{state} || undef;
            my $variety = $params->{additionalInfo}->{variety} || undef;
            my $locationCode = $params->{additionalInfo}->{locationCode} || undef;
            my $description = $params->{additionalInfo}->{description} || undef;
            #not supported
            # speciesAuthority
            # genus
            # commonCropName
            # biologicalStatusOfAccessionDescription
            # germplasmSeedSourceDescription
            # breedingMethodDbId
            # collection
            # documentationURL
            # externalReferences
            # germplasmOrigin
            # germplasmPreprocessing
            # taxonIds
            # subtaxa
            # subtaxaAuthority
            # pedigree

            if (exists($allowed_organisms{$species})){
                my $stock = CXGN::Stock::Accession->new({
                    schema=>$schema,
                    check_name_exists=>0,
                    main_production_site_url=>$main_production_site_url,
                    type=>'accession',
                    type_id=>$type_id,
                    species=>$species,
                    stock_id=>$germplasm_id, #For adding properties to an accessions
                    name=>$name,
                    uniquename=>$uniquename,
                    organization_name=>$organization_name,
                    population_name=>$population_name,
                    description=>$description,
                    accessionNumber=>$accessionNumber,
                    germplasmPUI=>$germplasmPUI,
                    germplasmSeedSource=>$germplasmSeedSource,
                    synonyms=>[$synonyms],
                    instituteCode=>$instituteCode,
                    instituteName=>$instituteName,
                    biologicalStatusOfAccessionCode=>$biologicalStatusOfAccessionCode,
                    countryOfOriginCode=>$countryOfOriginCode,
                    typeOfGermplasmStorageCode=>$typeOfGermplasmStorageCode,
                    donors=>$donors,
                    acquisitionDate=>$acquisitionDate,
                    transgenic=>$transgenic,
                    notes=>$notes,
                    state=>$state,
                    variety=>$variety,
                    locationCode=>$locationCode,
                    sp_person_id => $user_id,
                    user_name => $user_name,
                    modification_note => 'Bulk load of accession information'
                });
                my $added_stock_id = $stock->store();
                push @added_stocks, $added_stock_id;
            }
        }
    };

    #update data
    my $transaction_error;

    try {
       $schema->txn_do($coderef_bcs);
    }
    catch {
        $transaction_error = $_;
    };

    if ($transaction_error){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('There was an error storing germplasm %s', $transaction_error));
    }

    #update matviews
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

     #retrieve updated item
    my @result = _simple_search($self,[$germplasm_id]);
    my @data_files;
    my $total_count = scalar(@result);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(@result, $pagination, \@data_files, $status, 'Germplasm updated');
}

sub _simple_search {
    my $self = shift;
    my $germplasm_ids_arrayref = shift;
    my $germplasm_names_arrayref = shift;

    my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();

    my $stock_search = CXGN::Stock::Search->new({
        bcs_schema=>$self->bcs_schema,
        people_schema=>$self->people_schema,
        phenome_schema=>$self->phenome_schema,
        match_type=>'exactly',
        uniquename_list=>$germplasm_names_arrayref,
        stock_id_list=>$germplasm_ids_arrayref,
        stock_type_id=>$accession_type_cvterm_id,
        stockprop_columns_view=>{'accession number'=>1, 'PUI'=>1, 'seed source'=>1, 'institute code'=>1, 'institute name'=>1, 'biological status of accession code'=>1, 'country of origin'=>1, 'type of germplasm storage code'=>1, 'acquisition date'=>1, 'ncbi_taxonomy_id'=>1},
        display_pedigree=>1
    });
    my ($result, $total_count) = $stock_search->search();

    my @data;
    foreach (@$result){
        # my @type_of_germplasm_storage_codes = $_->{'type of germplasm storage code'} ? split ',', $_->{'type of germplasm storage code'} : ();
        my @type_of_germplasm_storage_codes;
        if($_->{'type of germplasm storage code'}){
            my @items = split ',', $_->{'type of germplasm storage code'};
            foreach(@items){
                push @type_of_germplasm_storage_codes ,{
                    code=>$_,
                    description=>undef
                };
            }
        }
        my @donors = {
            donorAccessionNumber=>$_->{donors}->[0]->{donorAccessionNumber},
            donorInstituteCode=>$_->{donors}->[0]->{donorInstituteCode},
            germplasmPUI=>$_->{donors}->[0]->{germplasmPUI}
        };
        my @synonyms;
        if($_->{synonyms}){
            foreach(@{ $_->{synonyms} }){
                push @synonyms, {
                    synonym=>$_,
                    type=>undef
                };
            }
        }
        my @ncbi_taxon_ids = split ',', $_->{'ncbi_taxonomy_id'};
        my @taxons;
        foreach (@ncbi_taxon_ids){
            push @taxons, {
                sourceName => 'NCBI',
                taxonId => $_
            };
        }
        push @data, {
            accessionNumber=>$_->{'accession number'},
            acquisitionDate=>$_->{'acquisition date'},
            additionalInfo=>undef,
            biologicalStatusOfAccessionCode=>$_->{'biological status of accession code'} || 0,
            biologicalStatusOfAccessionDescription=>undef,
            breedingMethodDbId=>undef,
            collection=>undef,
            commonCropName=>$_->{common_name},
            countryOfOriginCode=>$_->{'country of origin'},
            defaultDisplayName=>$_->{stock_name},
            documentationURL=>$_->{'PUI'},
            donors=>\@donors,
            externalReferences=>[],
            genus=>$_->{genus},
            germplasmName=>$_->{uniquename},
            germplasmOrigin=>[],
            germplasmDbId=>qq|$_->{stock_id}|,
            germplasmPUI=>$_->{'PUI'},     
            germplasmPreprocessing=>undef,
            instituteCode=>$_->{'institute code'},
            instituteName=>$_->{'institute name'},
            pedigree=>$_->{pedigree},
            seedSource=>$_->{'seed source'},
            seedSourceDescription=>$_->{'seed source'}, 
            species=>$_->{species},
            speciesAuthority=>$_->{speciesAuthority},
            storageTypes=>\@type_of_germplasm_storage_codes,
            subtaxa=>$_->{subtaxa},
            subtaxaAuthority=>$_->{subtaxaAuthority},
            synonyms=> \@synonyms,
            taxonIds=>\@taxons,
        };
    }
    return @data;
}

1;
