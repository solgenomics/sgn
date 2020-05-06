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
            donorAccessionNumber=>$_->{'accession number'},
            donorInstituteCode=>$_->{donors},
            germplasmPUI=>undef
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
            defaultDisplayName=>$_->{uniquename},
            documentationURL=>undef,
            donors=>\@donors,
            externalReferences=>undef,
            genus=>$_->{genus},
            germplasmName=>$_->{uniquename},
            germplasmOrigin=>undef,
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
    my @data_files;

    my $verify_id = $self->bcs_schema->resultset('Stock::Stock')->find({stock_id=>$stock_id});
    if (!$verify_id) {
        return CXGN::BrAPI::JSONResponse->return_error($status, 'GermplasmDbId does not exist in the database');
    }

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
    my $stock_search = CXGN::Stock::Search->new({
        bcs_schema=>$self->bcs_schema,
        people_schema=>$self->people_schema,
        phenome_schema=>$self->phenome_schema,
        match_type=>'exactly',
        stock_id_list=>[$stock_id],
        stock_type_id=>$accession_cvterm_id,
        display_pedigree=>1,
        stockprop_columns_view=>{'accession number'=>1, 'PUI'=>1, 'seed source'=>1, 'institute code'=>1, 'institute name'=>1, 'biological status of accession code'=>1, 'country of origin'=>1, 'type of germplasm storage code'=>1, 'acquisition date'=>1, 'ncbi_taxonomy_id'=>1},
    });
    my ($result, $total_count) = $stock_search->search();

    if ($total_count != 1){
        return CXGN::BrAPI::JSONResponse->return_error($status, 'GermplasmDbId did not return 1 result');
    }
    # my @type_of_germplasm_storage_codes = $result->[0]->{'type of germplasm storage code'} ? split ',', $result->[0]->{'type of germplasm storage code'} : ();
    my @type_of_germplasm_storage_codes;
    my @items = split ',', $result->[0]->{'type of germplasm storage code'};
    foreach(@items){
        push @type_of_germplasm_storage_codes ,{
            code=>$_,
            description=>undef
        };
    }
    my @donors = {
            donorAccessionNumber=>$result->[0]->{'accession number'},
            donorInstituteCode=>$result->[0]->{donors},
            germplasmPUI=>undef
        };
    my @synonyms;
    foreach(@{ $result->[0]->{synonyms} }){
        push @synonyms, {
            synonym=>$_,
            type=>undef
        };
    }
    my @ncbi_taxon_ids = split ',', $result->[0]->{'ncbi_taxonomy_id'};
    my @taxons;
    foreach (@ncbi_taxon_ids){
        push @taxons, {
            sourceName => 'NCBI',
            taxonId => $_
        };
    }
    my %result = (
        additionalInfo=>{},
        accessionNumber=>$result->[0]->{'accession number'},
        acquisitionDate=>$result->[0]->{'acquisition date'},
        biologicalStatusOfAccessionCode=>$result->[0]->{'biological status of accession code'} + 0,
        biologicalStatusOfAccessionDescription=>undef,
        breedingMethodDbId=>undef,
        collection=>undef,
        commonCropName=>$result->[0]->{common_name},
        countryOfOriginCode=>$result->[0]->{'country of origin'},
        defaultDisplayName=>$result->[0]->{uniquename},
        documentationURL=>undef,
        donors=>\@donors,
        externalReferences=>undef,
        genus=>$result->[0]->{genus},
        germplasmDbId=>qq|$result->[0]->{stock_id}|,     
        germplasmName=>$result->[0]->{uniquename},
        germplasmOrigin=>undef,
        germplasmPUI=>$result->[0]->{'PUI'},
        germplasmPreprocessing=>undef,
        instituteCode=>$result->[0]->{'institute code'},
        instituteName=>$result->[0]->{'institute name'},
        pedigree=>$result->[0]->{pedigree},
        seedSource=>$result->[0]->{'seed source'},
        seedSourceDescription=>$result->[0]->{'seed source'},
        species=>$result->[0]->{species},
        speciesAuthority=>$result->[0]->{speciesAuthority},
        storageTypes=>\@type_of_germplasm_storage_codes,
        subtaxa=>$result->[0]->{subtaxa},
        subtaxaAuthority=>$result->[0]->{subtaxaAuthority},
        synonyms=>\@synonyms,
        taxonIds=>\@taxons,  
    );
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,1,0);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm detail result constructed');
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
    if ($s) { print Dumper $s;
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
    #print STDERR Dumper $stock_id;
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

1;
