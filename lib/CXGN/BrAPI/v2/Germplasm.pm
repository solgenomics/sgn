package CXGN::BrAPI::v2::Germplasm;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Stock::Search;
use CXGN::Stock;
use CXGN::BrAPI::v2::ExternalReferences;
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

    if ( $collection || $progeny_db_id || $parent_db_id ){
        push @$status, { 'error' => 'The following search parameters are not implemented: collection, parentDbId, progenyDbId' };
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

    my $references = CXGN::BrAPI::v2::ExternalReferences->new({
        bcs_schema => $self->bcs_schema,
        table_name => 'stock',
        table_id_key => 'stock_id',
        id => $germplasm_ids_arrayref
    });
    my $reference_result = $references->search();


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

    my $main_production_site_url = SGN::Context->new()->get_conf('main_production_site_url');

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

        #Get external references
        my @references;

        if (%$reference_result{$_->{stock_id}}){
            foreach (@{%$reference_result{$_->{stock_id}}}){
                my $reference_source = $_->[0] || undef;
                my $url = $_->[1];
                my $accession = $_->[2];
                my $reference_id;

                if($reference_source eq 'DOI') {
                    $reference_id = ($url) ? "$url$accession" : "doi:$accession";
                } else {
                    $reference_id = ($accession) ? "$url$accession" : $url;
                }

                push @references, {
                    referenceID => $reference_id,
                    referenceSource => $reference_source
                };

            }
        }

        my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'female_parent', 'stock_relationship')->cvterm_id();
        my $q = "SELECT value FROM stock_relationship WHERE object_id = ? AND type_id = ?;";
    	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    	$h->execute($_->{stock_id}, $female_parent_cvterm_id);
    	my ($cross_type) = $h->fetchrow_array();
        if ( ! defined $cross_type) {
            $cross_type = "unknown";
        }

        push @data, {
            accessionNumber=>$_->{'accession number'},
            acquisitionDate=>$_->{'acquisition date'},
            additionalInfo=>undef,
            biologicalStatusOfAccessionCode=>$_->{'biological status of accession code'} || 0,
            biologicalStatusOfAccessionDescription=>undef,
            breedingMethodDbId=>$cross_type,
            collection=>undef,
            commonCropName=>$_->{common_name},
            countryOfOriginCode=>$_->{'country of origin'},
            defaultDisplayName=>$_->{stock_name},
            documentationURL=>$_->{'PUI'} || $main_production_site_url . "/stock/$_->{stock_id}/view",
            donors=>\@donors,
            externalReferences=>\@references,
            genus=>$_->{genus},
            germplasmName=>$_->{uniquename},
            germplasmOrigin=>[],
            germplasmDbId=>qq|$_->{stock_id}|,
            germplasmPUI=>$_->{'PUI'} || $main_production_site_url . "/stock/$_->{stock_id}/view",
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
    my $status = $self->status;

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
                    germplasmName => $progeny_name
                };
            }
            $cross_plan = $cross_type;
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
        }

        #Add parents:
        my $parent = [];
        if ($female_parent_stock_id){
            push @$parent, {
                germplasmDbId=>$female_parent_stock_id ? qq|$female_parent_stock_id| : $female_parent_stock_id ,
                germplasmName=>$mother,
                parentType=>'FEMALE',
            };
        }
        if ($male_parent_stock_id){
            push @$parent, {
                germplasmDbId=>$male_parent_stock_id ? qq|$male_parent_stock_id| : $male_parent_stock_id,
                germplasmName=>$father,
                parentType=>'MALE',
            }

        }

        %result = (
            crossingProjectDbId=>$membership_info[0][0],
            crossingYear=>$membership_info[0][5],
            familyCode=>$membership_info[0][4],
            germplasmDbId=>qq|$stock_id|,
            germplasmName=>$stock_uniquename,
            parents=>$parent,
            pedigree=>"$mother/$father",
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

    my $main_production_site_url = $c->config->{main_production_site_url};

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
            my $externalReferences = $params->{externalReferences} || undef;
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

                my $references = CXGN::BrAPI::v2::ExternalReferences->new({
                    bcs_schema => $self->bcs_schema,
                    table_name => 'Stock::StockDbxref',
                    table_id_key => 'stock_id',
                    external_references => $externalReferences,
                    id => $added_stock_id
                });
                my $reference_result = $references->store();

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

    my $stock_exists = $schema->resultset('Stock::Stock')->find({stock_id=>$germplasm_id});
    if (!$stock_exists) {
        return CXGN::BrAPI::JSONResponse->return_error($status, 'GermplasmDbId does not exist in the database',400);
    }

    my $main_production_site_url = $c->config->{main_production_site_url};

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
            my $externalReferences = $params->{externalReferences} || undef;
            #not supported
            # speciesAuthority
            # genus
            # commonCropName
            # biologicalStatusOfAccessionDescription
            # germplasmSeedSourceDescription
            # breedingMethodDbId
            # collection
            # documentationURL
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
                
                my $previous_name = $stock_exists->uniquename();

                if($previous_name ne $uniquename){
                    $stock_exists->uniquename($uniquename);
                    $stock_exists->update();
                }

                push @added_stocks, $added_stock_id;

                my $references = CXGN::BrAPI::v2::ExternalReferences->new({
                    bcs_schema => $self->bcs_schema,
                    table_name => 'Stock::StockDbxref',
                    table_id_key => 'stock_id',
                    external_references => $externalReferences,
                    id => $germplasm_id
                });
                my $reference_result = $references->store();
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

    my $references = CXGN::BrAPI::v2::ExternalReferences->new({
        bcs_schema => $self->bcs_schema,
        table_name => 'stock',
        table_id_key => 'stock_id',
        id => $germplasm_ids_arrayref
    });
    my $reference_result = $references->search();

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

    my $main_production_site_url = SGN::Context->new()->get_conf('main_production_site_url');

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

        my @references;
        if (%$reference_result{$_->{stock_id}}){
            foreach (@{%$reference_result{$_->{stock_id}}}){
                my $reference_source = $_->[0] || undef;
                my $url = $_->[1];
                my $accession = $_->[2];
                my $reference_id;

                if($reference_source eq 'DOI') {
                    $reference_id = ($url) ? "$url$accession" : "doi:$accession";
                } else {
                    $reference_id = ($accession) ? "$url$accession" : $url;
                }

                push @references, {
                    referenceID => $reference_id,
                    referenceSource => $reference_source
                };
            }
        }

        my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'female_parent', 'stock_relationship')->cvterm_id();
        my $q = "SELECT value FROM stock_relationship WHERE object_id = ? AND type_id = ?;";
    	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
    	$h->execute($_->{stock_id}, $female_parent_cvterm_id);
    	my ($cross_type) = $h->fetchrow_array();
        if ( ! defined $cross_type) {
            $cross_type = "unknown";
        }

        push @data, {
            accessionNumber=>$_->{'accession number'},
            acquisitionDate=>$_->{'acquisition date'},
            additionalInfo=>undef,
            biologicalStatusOfAccessionCode=>$_->{'biological status of accession code'} || 0,
            biologicalStatusOfAccessionDescription=>undef,
            breedingMethodDbId=>$cross_type,
            collection=>undef,
            commonCropName=>$_->{common_name},
            countryOfOriginCode=>$_->{'country of origin'},
            defaultDisplayName=>$_->{stock_name},
            documentationURL=>$_->{'PUI'} || $main_production_site_url . "/stock/$_->{stock_id}/view",
            donors=>\@donors,
            externalReferences=>\@references,
            genus=>$_->{genus},
            germplasmName=>$_->{uniquename},
            germplasmOrigin=>[],
            germplasmDbId=>qq|$_->{stock_id}|,
            germplasmPUI=>$_->{'PUI'} || $main_production_site_url . "/stock/$_->{stock_id}/view",
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
