package CXGN::BrAPI::v2::Pedigree;

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
use List::Util qw | uniq |;
use Try::Tiny;

extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $inputs = shift;

    my $status = $self->status;
    my $page_size = $self->page_size;
    my $page = $self->page;

    my $progeny_depth_counter = 0;
    my $pedigree_depth_counter = 0;
    my $stock_id_list;

    my $stock_id  = $params->{germplasmDbId}->[0];
    my $pedigree_depth = $params->{pedigreeDepth}->[0] || 1;
    my $progeny_depth = $params->{progenyDepth}->[0] || 1;
    my $full_tree = $params->{includeFullTree}->[0] || 'false';
    my $include_parents = $params->{includeParents}->[0] || 'true';
    my $include_siblings = $params->{includeSiblings}->[0] || 'false';
    my $include_progeny = $params->{includeProgeny}->[0] || 'true';

    if(lc $full_tree ne 'false'){
        $pedigree_depth = 5;
        $progeny_depth = 5;
    }
    
    my $result = _get_tree($self, $stock_id,$progeny_depth_counter,$pedigree_depth_counter,$progeny_depth,$pedigree_depth,$include_parents,$include_siblings,$include_progeny,$stock_id_list);

    my @data_files;
    my $data = {'data'=>$result};
    my $total_count = $result ? scalar @{$result} : 0;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size, $page);
    return CXGN::BrAPI::JSONResponse->return_success($data, $pagination, \@data_files, $status, 'Germplasm pedigree result constructed');
}

sub _get_tree {
    my $self = shift;
    my $stock_id = shift;
    my $progeny_depth_counter = shift;
    my $pedigree_depth_counter = shift;
    my $progeny_depth = shift;
    my $pedigree_depth = shift;
    my $include_parents = shift;
    my $include_siblings = shift;
    my $include_progeny = shift;
    my $stock_id_list = shift;
    my $results = shift;

    my %list = map { $_ => 1 } @$stock_id_list;
    next if(exists($list{$stock_id}));
    push @$stock_id_list, $stock_id;

    my $result = _get_pedigree_progeny($self, $stock_id,$include_parents,$include_siblings,$include_progeny);
    if ($result) { push @$results, @$result; }

    $progeny_depth_counter++;
    $pedigree_depth_counter++;

    foreach my $germplasm (@$result){
        my %list = map { $_ => 1 } @$stock_id_list;
        my $tmp_list;       
        if($progeny_depth_counter < $progeny_depth ){            
            foreach my $progeny (@{$germplasm->{progeny}}){
                next if(exists($list{$progeny->{germplasmDbId}}));
                push @$tmp_list, $progeny->{germplasmDbId};
            }
        }

        if($pedigree_depth_counter < $pedigree_depth){
            foreach my $parent (@{$germplasm->{parents}}){
                next if(exists($list{$parent->{germplasmDbId}}));
                push @$tmp_list, $parent->{germplasmDbId};                
            }
        }

        my @filtered = uniq(@$tmp_list);

        foreach my $item (@filtered){
            next if(exists($list{$item}));
            _get_tree($self,$item,$progeny_depth_counter,$pedigree_depth_counter,$progeny_depth,$pedigree_depth,$include_parents,$include_siblings,$include_progeny,$stock_id_list, $results);
        }
    }
    return $results;
}

sub _get_pedigree_progeny {
    my $self = shift;
    my $stock_id = shift;
    my $include_parents = shift;
    my $include_siblings = shift;
    my $include_progeny = shift;
    my $status = $self->status;

    my $result;

    my $pedigree=_germplasm_pedigree($self,$stock_id, $include_parents, $include_siblings);

    my $progeny_value=[];
    if(lc $include_progeny eq 'true'){
        my $progeny=_germplasm_progeny($self, $stock_id);
        $progeny_value=$progeny->{progeny};
    }

    if (keys(%$pedigree) > 0) {
        push @$result, {
            additionalInfo=>{},
            breedingMethodDbId=>undef,
            breedingMethodName=>undef,
            
            crossingProjectDbId=>$pedigree->{crossingProjectDbId},
            crossingYear=>$pedigree->{crossingYear},
            familyCode=>$pedigree->{familyCode},

            defaultDisplayName=>undef,
            externalReferences=>[],    
            germplasmDbId=>$pedigree->{germplasmDbId},
            germplasmName=>$pedigree->{germplasmName},
            germplasmPUI=>$pedigree->{germplasmPUI},
            parents=>$include_parents eq 'true' ? $pedigree->{parents} : [],
            pedigreeString=>$pedigree->{pedigree},
            progeny=>$progeny_value, 
            siblings=> $include_siblings eq 'true' ? $pedigree->{siblings} : [],
        };
    }
    return $result;
}

sub _germplasm_pedigree {
    my $self = shift;
    my $stock_id = shift;
    my $include_parents = shift;
    my $include_siblings = shift;
    my $status = $self->status;

    my $direct_descendant_ids;
    my %result;
    my $total_count = 0;
    my @data_files;

    push @$direct_descendant_ids, $stock_id; #excluded in parent retrieval to prevent loops
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
    my $vector_construct_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vector_construct', 'stock_type')->cvterm_id();

    my $stock = $self->bcs_schema->resultset("Stock::Stock")->find({stock_id => $stock_id});

    if ($stock) {
        $total_count = 1;
        my $stock_uniquename = $stock->uniquename();
        my $stock_type = $stock->type_id();
        if( $stock_type == $accession_cvterm || $stock_type == $vector_construct_cvterm){

        my $mother;
        my $father;

        ## Get parents relationships
        my $cvterm_female_parent = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'female_parent', 'stock_relationship')->cvterm_id();
        my $cvterm_male_parent = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'male_parent', 'stock_relationship')->cvterm_id();
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
        my @siblings = ();
        if($include_siblings eq 'true'){
            my $q = "SELECT DISTINCT female_parent.stock_id, female_parent.uniquename, male_parent.stock_id, male_parent.uniquename, progeny.stock_id, progeny.uniquename, stock_relationship1.value
                FROM stock_relationship as stock_relationship1
                INNER JOIN stock AS female_parent ON (stock_relationship1.subject_id = female_parent.stock_id) AND stock_relationship1.type_id = ?
                INNER JOIN stock AS progeny ON (stock_relationship1.object_id = progeny.stock_id) AND ( progeny.type_id = ? OR progeny.type_id= ? )
                LEFT JOIN stock_relationship AS stock_relationship2 ON (progeny.stock_id = stock_relationship2.object_id) AND stock_relationship2.type_id = ?
                LEFT JOIN stock AS male_parent ON (stock_relationship2.subject_id = male_parent.stock_id) ";

            my $h;

            if($female_parent_stock_id && $male_parent_stock_id){
                $q = $q . "WHERE female_parent.stock_id = ? AND male_parent.stock_id = ?";
                $h = $self->bcs_schema()->storage->dbh()->prepare($q);
                $h->execute($cvterm_female_parent, $accession_cvterm, $vector_construct_cvterm, $cvterm_male_parent, $female_parent_stock_id, $male_parent_stock_id);
            }
            elsif ($female_parent_stock_id) {
                $q = $q . "WHERE female_parent.stock_id = ? ORDER BY male_parent.stock_id";
                $h = $self->bcs_schema()->storage->dbh()->prepare($q);
                $h->execute($cvterm_female_parent, $accession_cvterm, $vector_construct_cvterm, $cvterm_male_parent, $female_parent_stock_id);
            }
            elsif ($male_parent_stock_id) {
                $q = $q . "WHERE male_parent.stock_id = ? ORDER BY female_parent.stock_id";
                $h = $self->bcs_schema()->storage->dbh()->prepare($q);
                $h->execute($cvterm_female_parent, $accession_cvterm, $vector_construct_cvterm, $cvterm_male_parent, $male_parent_stock_id);
            }
            else {
                $h = $self->bcs_schema()->storage->dbh()->prepare($q);
                $h->execute($cvterm_female_parent, $accession_cvterm, $vector_construct_cvterm, $cvterm_male_parent);
            }

            
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
        if($include_parents eq 'true'){
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
    }

    return \%result;
}

sub _germplasm_progeny {
    my $self = shift;
    my $stock_id = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $mother_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $father_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();my $vector_construct_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vector_construct', 'stock_type')->cvterm_id();

    my $result;

    my $stock = $self->bcs_schema()->resultset("Stock::Stock")->find({
        'type_id'=> [ $accession_cvterm, $vector_construct_cvterm ],
        'stock_id'=> $stock_id,
    });
    if ($stock){
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

        $result = {
            germplasmName=>$stock->uniquename,
            germplasmDbId=>$stock_id,
            progeny=>[@{$full_data}],
        };

    }
    return $result;
}


1;
