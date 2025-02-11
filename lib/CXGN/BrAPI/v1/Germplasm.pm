package CXGN::BrAPI::v1::Germplasm;

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

extends 'CXGN::BrAPI::v1::Common';

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
    my $genera_arrayref = $params->{germplasmGenus} || ($params->{germplasmGenera} || ());
    my $germplasm_ids_arrayref  = $params->{germplasmDbId} || ($params->{germplasmDbIds} || ());
    my $germplasm_puis_arrayref = $params->{germplasmPUI} || ($params->{germplasmPUIs} || ());
    my $species_arrayref = $params->{germplasmSpecies} || ($params->{germplasmSpecies} || ());
    my $synonyms_arrayref = $params->{synonym} || ($params->{synonyms} || ());
    my $subtaxa = $params->{germplasmSubTaxa}->[0];
    my $match_method = $params->{matchMethod}->[0] || 'exact';
    my $acquisitionDate = ref $params->{acquisitionDate} eq 'ARRAY' ? $params->{acquisitionDate}->[0] : $params->{acquisitionDate};
    my $minAcquisitionDate = ref $params->{minAcquisitionDate} eq 'ARRAY' ? $params->{minAcquisitionDate}->[0] : $params->{minAcquisitionDate};
    my $maxAcquisitionDate = ref $params->{maxAcquisitionDate} eq 'ARRAY' ? $params->{maxAcquisitionDate}->[0] : $params->{maxAcquisitionDate};

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
        limit=>$limit,
        offset=>$offset,
        display_pedigree=>1,
        acquisition_date=>$acquisitionDate,
        min_acquisition_date=>$minAcquisitionDate,
        max_acquisition_date=>$maxAcquisitionDate
    });
    my ($result, $total_count) = $stock_search->search();

    my @data;
    foreach (@$result){
        my @type_of_germplasm_storage_codes = $_->{'type of germplasm storage code'} ? split ',', $_->{'type of germplasm storage code'} : ();
        my @ncbi_taxon_ids = split ',', $_->{'ncbi_taxonomy_id'};
        my @taxons;
        foreach (@ncbi_taxon_ids){
            push @taxons, {
                sourceName => 'NCBI',
                taxonId => $_
            };
        }
        push @data, {
            germplasmDbId=>$_->{stock_id},
            defaultDisplayName=>$_->{uniquename},
            germplasmName=>$_->{uniquename},
            accessionNumber=>$_->{'accession number'},
            germplasmPUI=>$_->{'PUI'},
            pedigree=>$_->{pedigree},
            germplasmSeedSource=>$_->{'seed source'},
            synonyms=> $_->{synonyms},
            commonCropName=>$_->{common_name},
            instituteCode=>$_->{'institute code'},
            instituteName=>$_->{'institute name'},
            biologicalStatusOfAccessionCode=> $_->{'biological status of accession code'} ? ($_->{'biological status of accession code'} + 0) : 0,
            countryOfOriginCode=>$_->{'country of origin'},
            typeOfGermplasmStorageCode=>\@type_of_germplasm_storage_codes,
            genus=>$_->{genus},
            species=>$_->{species},
            taxonIds=>\@taxons,
            speciesAuthority=>$_->{speciesAuthority},
            subtaxa=>$_->{subtaxa},
            subtaxaAuthority=>$_->{subtaxaAuthority},
            donors=>$_->{donors},
            acquisitionDate=>$_->{'acquisition date'} eq '' ? $_->{'create_date'} : $_->{'acquisition date'},
            breedingMethodDbId=>undef,
            documentationURL=>undef,
            germplasmGenus=>$_->{genus},
            germplasmSpecies=>$_->{species},
            seedSource=>$_->{'seed source'}
        };
    }

    my %result = (data => \@data);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm-search result constructed');
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
    my @type_of_germplasm_storage_codes = $result->[0]->{'type of germplasm storage code'} ? split ',', $result->[0]->{'type of germplasm storage code'} : ();
    my @ncbi_taxon_ids = split ',', $result->[0]->{'ncbi_taxonomy_id'};
    my @taxons;
    foreach (@ncbi_taxon_ids){
        push @taxons, {
            sourceName => 'NCBI',
            taxonId => $_
        };
    }
    my %result = (
        germplasmDbId=>$result->[0]->{stock_id},
        defaultDisplayName=>$result->[0]->{uniquename},
        germplasmName=>$result->[0]->{uniquename},
        accessionNumber=>$result->[0]->{'accession number'},
        germplasmPUI=>$result->[0]->{'PUI'},
        pedigree=>$result->[0]->{pedigree},
        germplasmSeedSource=>$result->[0]->{'seed source'},
        synonyms=> $result->[0]->{synonyms},
        commonCropName=>$result->[0]->{common_name},
        instituteCode=>$result->[0]->{'institute code'},
        instituteName=>$result->[0]->{'institute name'},
        biologicalStatusOfAccessionCode=>$result->[0]->{'biological status of accession code'} ? ($result->[0]->{'biological status of accession code'} + 0) : 0,
        countryOfOriginCode=>$result->[0]->{'country of origin'},
        typeOfGermplasmStorageCode=>\@type_of_germplasm_storage_codes,
        genus=>$result->[0]->{genus},
        species=>$result->[0]->{species},
        taxonIds=>\@taxons,
        speciesAuthority=>$result->[0]->{speciesAuthority},
        subtaxa=>$result->[0]->{subtaxa},
        subtaxaAuthority=>$result->[0]->{subtaxaAuthority},
        donors=>$result->[0]->{donors},
        acquisitionDate=>$result->[0]->{'acquisition date'} eq '' ? $result->[0]->{'create_date'} : $result->[0]->{'acquisition date'}
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

    my $direct_descendant_ids;
    my %result;
    my $total_count = 0;
    my @data_files;

    push @$direct_descendant_ids, $stock_id; #excluded in parent retrieval to prevent loops

    my $stock = $self->bcs_schema->resultset("Stock::Stock")->find({stock_id => $stock_id});

    if ($stock) {
        $total_count = 1;
        my $stock_uniquename = $stock->uniquename();
        my $stock_type = $stock->type_id();

        my $mother;
        my $father;

        ## Get parents relationships
        my $cvterm_female_parent = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'female_parent', 'stock_relationship')->cvterm_id();
        my $cvterm_male_parent = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'male_parent', 'stock_relationship')->cvterm_id();
        my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();

        #get the stock relationships for the stock
        my $female_parent_stock_id;
        my $male_parent_stock_id;

        my $stock_relationships = $stock->search_related("stock_relationship_objects",undef,{ prefetch => ['type','subject'] });

        my $female_parent_relationship = $stock_relationships->find({type_id => $cvterm_female_parent, subject_id => {'not_in' => $direct_descendant_ids}});
        if ($female_parent_relationship) {
            $female_parent_stock_id = $female_parent_relationship->subject_id();
            $mother = $self->bcs_schema->resultset("Stock::Stock")->find({stock_id => $female_parent_stock_id})->uniquename();
        }
        my $male_parent_relationship = $stock_relationships->find({type_id => $cvterm_male_parent, subject_id => {'not_in' => $direct_descendant_ids}});
        if ($male_parent_relationship) {
            $male_parent_stock_id = $male_parent_relationship->subject_id();
            $father = $self->bcs_schema->resultset("Stock::Stock")->find({stock_id => $male_parent_stock_id})->uniquename();
        }

        ##Get sibblings
        my $q = "SELECT DISTINCT female_parent.stock_id, female_parent.uniquename, male_parent.stock_id, male_parent.uniquename, progeny.stock_id, progeny.uniquename, stock_relationship1.value
            FROM stock_relationship as stock_relationship1
            INNER JOIN stock AS female_parent ON (stock_relationship1.subject_id = female_parent.stock_id) AND stock_relationship1.type_id = ?
            INNER JOIN stock AS progeny ON (stock_relationship1.object_id = progeny.stock_id) AND progeny.type_id = ?
            LEFT JOIN stock_relationship AS stock_relationship2 ON (progeny.stock_id = stock_relationship2.object_id) AND stock_relationship2.type_id = ?
            LEFT JOIN stock AS male_parent ON (stock_relationship2.subject_id = male_parent.stock_id) "; 

        my $h;

        if($female_parent_stock_id && $male_parent_stock_id){
            $q = $q . "WHERE female_parent.stock_id = ? AND male_parent.stock_id = ?";
            $h = $self->bcs_schema()->storage->dbh()->prepare($q);
            $h->execute($cvterm_female_parent, $accession_cvterm, $cvterm_male_parent, $female_parent_stock_id, $male_parent_stock_id);
        }
        elsif ($female_parent_stock_id) {
            $q = $q . "WHERE female_parent.stock_id = ? ORDER BY male_parent.stock_id";
            $h = $self->bcs_schema()->storage->dbh()->prepare($q);
            $h->execute($cvterm_female_parent, $accession_cvterm, $cvterm_male_parent, $female_parent_stock_id);
        }
        elsif ($male_parent_stock_id) {
            $q = $q . "WHERE male_parent.stock_id = ? ORDER BY female_parent.stock_id";
            $h = $self->bcs_schema()->storage->dbh()->prepare($q);
            $h->execute($cvterm_female_parent, $accession_cvterm, $cvterm_male_parent, $male_parent_stock_id);
        }
        else {
            $h = $self->bcs_schema()->storage->dbh()->prepare($q);
            $h->execute($cvterm_female_parent, $accession_cvterm, $cvterm_male_parent);
        }

        my @siblings = ();
        my $cross_plan;

        while (my($female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $progeny_id, $progeny_name, $cross_type) = $h->fetchrow_array()){
             if ($progeny_id ne $stock_id){
                push @siblings, {
                    germplasmDbId => qq|$progeny_id|,
                    defaultDisplayName => $progeny_name
                };
            }
            $cross_plan = $cross_type;
            $mother = $female_parent_name ? $female_parent_name : "NA";
            $father = $male_parent_name ? $male_parent_name : "NA";
        }

        #Cross information
        my @membership_info = ();
        my $cross_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'cross', 'stock_type')->cvterm_id();

        if ($stock_type eq $cross_cvterm){

            my $cross_member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "cross_member_of", "stock_relationship")->cvterm_id();
            my $cross_experiment_type_id =  SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'cross_experiment', 'experiment_type')->cvterm_id();
            my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, "family_name", "stock_type")->cvterm_id();
            my $project_year_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'project year', 'project_property')->cvterm_id();

            my $q = "SELECT project.project_id, project.name, project.description, stock.stock_id, stock.uniquename, year.value 
                FROM nd_experiment_stock
                JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id) AND nd_experiment.type_id = ?
                JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id)
                JOIN project ON (nd_experiment_project.project_id = project.project_id)
                LEFT JOIN projectprop AS year ON (project.project_id=year.project_id) 
                LEFT JOIN stock_relationship ON (nd_experiment_stock.stock_id = stock_relationship.subject_id) AND stock_relationship.type_id = ?
                LEFT JOIN stock ON (stock_relationship.object_id = stock.stock_id) AND stock.type_id = ?
                WHERE nd_experiment_stock.stock_id = ? AND year.type_id = ?";

            my $h = $self->bcs_schema->storage->dbh()->prepare($q);
            $h->execute($cross_experiment_type_id, $cross_member_of_type_id, $family_name_type_id, $stock_id, $project_year_cvterm_id);

            
            while (my ($crossing_experiment_id, $crossing_experiment_name, $description, $family_id, $family_name, $year) = $h->fetchrow_array()){
                push @membership_info, [$crossing_experiment_id, $crossing_experiment_name, $description, $family_id, $family_name, $year]
            }
             # print STDERR Dumper(\@membership_info);
        }

        %result = (
                germplasmDbId=>qq|$stock_id|,
                defaultDisplayName=>$stock_uniquename,
                pedigree=>"$mother/$father",
                crossingPlan=>$cross_plan,
                crossingYear=>$membership_info[0][5],
                familyCode=>$membership_info[0][4],
                parent1Id=>$female_parent_stock_id,
                parent2Id=>$male_parent_stock_id,
                parent1DbId=>$female_parent_stock_id,
                parent1Name=>$mother,
                parent1Type=>'FEMALE',
                parent2DbId=>$male_parent_stock_id,
                parent2Name=>$father,
                parent2Type=>'MALE',
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
                germplasmDbId => $edge->object_id,
                progenyGermplasmDbId => $edge->object_id,
                defaultDisplayName => $edge->get_column('progeny_uniquename'),
                parentType => "FEMALE"
            };
        } else {
            push @{$full_data}, {
                germplasmDbId => $edge->object_id,
                progenyGermplasmDbId => $edge->object_id,
                defaultDisplayName => $edge->get_column('progeny_uniquename'),
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
        defaultDisplayName=>$stock->uniquename,
        germplasmDbId=>$stock_id,
        progeny=>[@{$full_data}[$page_size*$page .. $last_item]],
        data=>[@{$full_data}[$page_size*$page .. $last_item]]
    };
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success($result, $pagination, \@data_files, $status, 'Germplasm progeny result constructed');
}

sub germplasm_markerprofiles {
    my $self = shift;
    my $stock_id = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @marker_profiles;

    my $vcf_snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();

    my $rs = $self->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search(
        {'genotypeprops.type_id' => $vcf_snp_genotyping_cvterm_id, 'stock.stock_id'=>$stock_id},
        {join=> [{'nd_experiment_genotypes' => {'genotype' => 'genotypeprops'} }, {'nd_experiment_protocols' => 'nd_protocol' }, {'nd_experiment_stocks' => 'stock'} ],
        select=> ['genotypeprops.genotypeprop_id'],
        as=> ['genotypeprop_id'],
        order_by=>{ -asc=>'genotypeprops.genotypeprop_id' }
        }
    );

    my $rs_slice = $rs->slice($page_size*$page, $page_size*($page+1)-1);
    while (my $gt = $rs_slice->next()) {
        push @marker_profiles, $gt->get_column('genotypeprop_id');
    }
    my $total_count = scalar(@marker_profiles);
    my %result = (
        germplasmDbId=>qq|$stock_id|,
        markerprofileDbIds=>\@marker_profiles
    );
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm markerprofiles result constructed');
}

1;
