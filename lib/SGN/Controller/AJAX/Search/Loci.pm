
package SGN::Controller::AJAX::Search::Loci;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub locus_search :Path('/ajax/search/loci') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $params = $c->req->params() || {};

    print STDERR "PARAMS: ".Dumper($params);
    
    my %query;

# params any_name_matchtype any_name organism linkage_group locus_editor phenotype ontology_term genbank_accession has_sequence has_marker has_annotation 
    

    if (exists($params->{"any_name"} ) && $params->{"any_name"} ) {
	$query{"any_name"} = ( [ { locus => {'ilike', '%'.$params->{"any_name"}.'%'} },  { locus_name => {'ilike', '%'.$params->{"any_name"}.'%'} },  { locus_symbol => {'ilike', '%'.$params->{"any_name"}.'%'} },  { description => {'ilike', '%'.$params->{"any_name"}.'%'} },  { gene_activity => {'ilike', '%'.$params->{"any_name"}.'%'} } ] );

    }
    
    my $matchtype = $params->{any_name_matchtype};
    my $any_name  = $params->{any_name};

    my ($or_conditions, $and_conditions);
    if (exists($params->{"any_name"} ) && $params->{"any_name"} ) {
	my $start = '%';
	my $end = '%';
	if ( $matchtype eq 'exactly' ) {
	    $start = '';
	    $end = '';
	} elsif ( $matchtype eq 'starts_with' ) {
	    $start = '';
	} elsif ( $matchtype eq 'ends_with' ) {
	    $end = '';
	}

	$or_conditions = [ 
	    { locus         => {'ilike', $start.$params->{any_name}.$end} },  
	    { locus_name    => {'ilike', $start.$params->{any_name}.$end} },  
	    { locus_symbol  => {'ilike', $start.$params->{any_name}.$end} }, 
	    { description   => {'ilike', $start.$params->{any_name}.$end} },  
	    { gene_activity => {'ilike', $start.$params->{any_name}.$end} } 
	    ] ; 
    }
    ###############
    if (exists($params->{organism} ) && $params->{organism} ) {
	$and_conditions = {
	    common_name_id      => $params->{organism},
	    linkage_group => $params->{linkage_group},
	    #locus_editor  => {'ilike', '%'.$params->{locus_editor}.'%' }, # join sgn.sgn_people
	    #phenotype     => {'ilike', '%'.$params->{phenotype}.'%' },    # join phenome.allele
	    #ontology_term => {'ilike', '%'.$params->{ontology_term}.'%'}, # join locus_dbxref->public.dbxref->public.cvterm  ( [ { dbxref.accession => {'ilike', '%'.$ontology_term.'%'} , {cvterm.name => 'ilike' , '%'.$ontology_term.'%'} ] ),
	    #dbxref.accession => {'ilike', '%'.$params->{genbank_accession}.'%'}, # join locus_dbxref->dbxref 
	    #has_sequence  # join locus_dbxref->dbxref->db  genbank, sgn unigene , or solyc id 
	    #has_marker    # join locus_marker
	    #has_annotation # join locus_dbxref->dbxref->db where db = GO || PO || SP
	};
    }
###############
    foreach my $k ( qw |  locus_name locus_symbol locus description gene_activity  | ) { 
	if (exists($params->{$k}) && $params->{$k}) { 
	    print STDERR "TRANSFERRING $k $params->{$k}\n";
	    $query{$k} = ( $k => { 'ilike', '%'.$params->{$k}.'%' });
	    
	}
    }

    my $draw = $params->{draw};
    $draw =~ s/\D//g; # cast to int

    my $rows = $params->{length} || 10;
    my $start = $params->{start};

    my $page = int($start / $rows)+1;

    print STDERR "Runnin query...".Dumper(\%query)."\n";

    # get the count first
    #
    my $rs = $c->dbic_schema("CXGN::Phenome::Schema")->resultset("Locus")->search( 
	{
	    -and => [
		 $and_conditions,
		 $or_conditions,
		],
	} );
	
    
    my $records_total = $rs->count();

    print STDERR "RECORDS TOTAL: $records_total\n";
    ## then get the data
    #
    my $rs2 = $c->dbic_schema("CXGN::Phenome::Schema")->resultset("Locus")->search(   $or_conditions  , { page => $page, rows => $rows, order_by => 'locus_name' } );
	

    my @result;
    while (my $l = $rs2->next()) { 
	my $locus_id = $l->locus_id ;
	my $locus_name = $l->locus_name;
	my $locus = $l->locus;
	my $locus_symbol = $l->locus_symbol;
	push @result, [ "<a href=\"/locus/$locus_id/view\">$locus_name</a>", $locus, $locus_name, $locus_symbol ];
    }

    print STDERR "RESULTS: ".Dumper(\@result);
    #$c->stash->{rest} = { data => \@result };


    $c->stash->{rest} = { data => [ @result ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
    
    
}

1;
