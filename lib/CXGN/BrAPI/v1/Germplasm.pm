package CXGN::BrAPI::v1::Germplasm;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::BrAPI::Pagination;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'metadata_schema' => (
	isa => 'CXGN::Metadata::Schema',
	is => 'rw',
	required => 1,
);

has 'phenome_schema' => (
	isa => 'CXGN::Phenome::Schema',
	is => 'rw',
	required => 1,
);

has 'page_size' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'page' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'status' => (
	isa => 'ArrayRef[Maybe[HashRef]]',
	is => 'rw',
	required => 1,
);

sub germplasm_search {
	my $self = shift;
	my $search_params = shift;

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my @germplasm_names = @{$search_params->{germplasmName}};
    my @accession_numbers = @{$search_params->{accessionNumber}};
    my $genus = $search_params->{germplasmGenus}->[0];
    my $subtaxa = $search_params->{germplasmSubTaxa}->[0];
    my $species = $search_params->{germplasmSpecies}->[0];
    my @germplasm_ids = @{$search_params->{germplasmDbId}};
    my $permplasm_pui = $search_params->{germplasmPUI}->[0];
    my $match_method = $search_params->{matchMethod}->[0];
    my %result;

    if ($match_method && ($match_method ne 'exact' && $match_method ne 'wildcard')) {
        push @$status, { 'error' => "matchMethod '$match_method' not recognized. Allowed matchMethods: wildcard, exact. Wildcard allows % or * for multiple characters and ? for single characters." };
    }
    my $total_count = 0;

    my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
    my %search_params;
    my %order_params;

    $search_params{'me.type_id'} = $accession_type_cvterm_id;
    $order_params{'-asc'} = 'me.stock_id';

    if (@germplasm_names && scalar(@germplasm_names)>0){
        if (!$match_method || $match_method eq 'exact') {
            $search_params{'me.uniquename'} = \@germplasm_names;
        } elsif ($match_method eq 'wildcard') {
            my @wildcard_names;
            foreach (@germplasm_names) {
                $_ =~ tr/*?/%_/;
                push @wildcard_names, $_;
            }
            $search_params{'me.uniquename'} = { 'ilike' => \@wildcard_names };
        }
    }

    if (@germplasm_ids && scalar(@germplasm_ids)>0){
        if (!$match_method || $match_method eq 'exact') {
            $search_params{'me.stock_id'} = \@germplasm_ids;
        } elsif ($match_method eq 'wildcard') {
            my @wildcard_ids;
            foreach (@germplasm_ids) {
                $_ =~ tr/*?/%_/;
                push @wildcard_ids, $_;
            }
            $search_params{'me.stock_id::varchar(255)'} = { 'ilike' => \@wildcard_ids };
        }
    }

    #print STDERR Dumper \%search_params;
    #$self->bcs_schema->storage->debug(1);
    my $synonym_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'stock_synonym', 'stock_property')->cvterm_id();
    my %extra_params = ('+select'=>['me.uniquename'], '+as'=>['accession_number'], 'order_by'=> \%order_params);
    if (@accession_numbers && scalar(@accession_numbers)>0) {
        $search_params{'stockprops.type_id'} = $synonym_id;
        $search_params{'stockprops.value'} = \@accession_numbers;
        %extra_params = ('join'=>{'stockprops'}, '+select'=>['stockprops.value'], '+as'=>['accession_number'], 'order_by'=> \%order_params);
    }
    my $rs = $self->bcs_schema()->resultset("Stock::Stock")->search( \%search_params, \%extra_params );

    my @data;
    if ($rs) {
        $total_count = $rs->count();
        my $rs_slice = $rs->slice($page_size*$page, $page_size*($page+1)-1);
        while (my $stock = $rs_slice->next()) {
			my $stockprop_hash = $self->get_stockprop_hash($stock->stock_id);
			my @donor_array;
			my $donor_accessions = $stockprop_hash->{'donor'} ? $stockprop_hash->{'donor'} : [];
			my $donor_institutes = $stockprop_hash->{'donor institute'} ? $stockprop_hash->{'donor institute'} : [];
			my $donor_puis = $stockprop_hash->{'donor PUI'} ? $stockprop_hash->{'donor PUI'} : [];
			for (0 .. scalar(@$donor_accessions)){
				push @donor_array, { 'donorGermplasmName'=>$donor_accessions->[$_], 'donorAccessionNumber'=>$donor_accessions->[$_], 'donorInstituteCode'=>$donor_institutes->[$_], 'germplasmPUI'=>$donor_puis->[$_] };
			}
            push @data, {
                germplasmDbId=>$stock->stock_id,
                defaultDisplayName=>$stock->uniquename,
                germplasmName=>$stock->uniquename,
                accessionNumber=>$stockprop_hash->{'accession number'} ? join ',', @{$stockprop_hash->{'accession number'}} : '',
                germplasmPUI=>$stockprop_hash->{'PUI'} ? join ',', @{$stockprop_hash->{'PUI'}} : '',
                pedigree=>$self->germplasm_pedigree_string($stock->stock_id),
                germplasmSeedSource=>$stockprop_hash->{'seed source'} ? join ',', @{$stockprop_hash->{'seed source'}} : '',
                synonyms=> $stockprop_hash->{'stock_synonym'} ? join ',', @{$stockprop_hash->{'stock_synonym'}} : '',
                commonCropName=>$stock->search_related('organism')->first()->common_name(),
                instituteCode=>$stockprop_hash->{'institute code'} ? join ',', @{$stockprop_hash->{'institute code'}} : '',
                instituteName=>$stockprop_hash->{'institute name'} ? join ',', @{$stockprop_hash->{'institute name'}} : '',
                biologicalStatusOfAccessionCode=>$stockprop_hash->{'biological status of accession code'} ? join ',', @{$stockprop_hash->{'biological status of accession code'}} : '',
                countryOfOriginCode=>$stockprop_hash->{'country'} ? join ',', @{$stockprop_hash->{'country'}} : '',
                typeOfGermplasmStorageCode=>$stockprop_hash->{'type of germplasm storage code'} ? join ',', @{$stockprop_hash->{'type of germplasm storage code'}} : '',
                genus=>$stock->search_related('organism')->first()->genus(),
                species=>$stock->search_related('organism')->first()->species(),
                speciesAuthority=>'',
                subtaxa=>'',
                subtaxaAuthority=>'',
                donors=>\@donor_array,
                acquisitionDate=>'',
            };
        }
    }

    %result = (data => \@data);
	push @$status, { 'success' => 'Germplasm-search result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub get_stockprop_hash {
	my $self = shift;
	my $stock_id = shift;
	my $stockprop_rs = $self->bcs_schema->resultset('Stock::Stockprop')->search({stock_id => $stock_id}, {join=>['type'], +select=>['type.name', 'me.value'], +as=>['name', 'value']});
	my $stockprop_hash;
	while (my $r = $stockprop_rs->next()){
		push @{ $stockprop_hash->{$r->get_column('name')} }, $r->get_column('value');
	}
	#print STDERR Dumper $stockprop_hash;
	return $stockprop_hash;
}

sub germplasm_pedigree_string {
	my $self = shift;
	my $stock_id = shift;
    my $s = CXGN::Chado::Stock->new($self->bcs_schema, $stock_id);
    my $pedigree_root = $s->get_parents('1');
    my $pedigree_string = $pedigree_root->get_pedigree_string('1');
    return $pedigree_string;
}

1;
