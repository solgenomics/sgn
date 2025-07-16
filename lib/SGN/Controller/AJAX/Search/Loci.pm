
package SGN::Controller::AJAX::Search::Loci;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub locus_search :Path('/ajax/search/loci') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $params = $c->req->params() || {};

    #print STDERR "PARAMS: ".Dumper($params);
    
    my %query;

# params any_name_matchtype any_name organism linkage_group locus_editor phenotype ontology_term genbank_accession has_sequence has_marker has_annotation 
    

    my $matchtype = $params->{any_name_matchtype};
    my $any_name  = $params->{any_name};
    
    my ($or_conditions, $and_conditions);
    $and_conditions->{ 'me.obsolete' } = 'f'  ;
    
    if (exists($params->{any_name} ) && $params->{any_name} ) {
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
	    { 'locus'         => {'ilike', $start.$params->{any_name}.$end} },  
	    { 'locus_name'    => {'ilike', $start.$params->{any_name}.$end} },  
	    { 'locus_symbol'  => {'ilike', $start.$params->{any_name}.$end} }, 
	    { 'description'   => {'ilike', $start.$params->{any_name}.$end} },  
	    { 'gene_activity' => {'ilike', $start.$params->{any_name}.$end} } 
	    ] ; 
    } else { 
	$or_conditions = [ { 'locus_name' => { '!=', undef } } ];
    }
    
    ###############
    if (exists($params->{common_name} ) && $params->{common_name} ) {
	$and_conditions->{'common_name_id'} = $params->{common_name} ;
	
    }
    if (exists($params->{linkage_group} ) && $params->{linkage_group} ) {
	$and_conditions->{'linkage_group'} = $params->{linkage_group} ;
	
    }
    if (exists($params->{phenotype} ) && $params->{phenotype} ) {
	$and_conditions->{allele_phenotype} = { 'ilike' => '%'.$params->{phenotype}.'%' } ;
	
    }
    if (exists($params->{locus_editor} ) && $params->{locus_editor} ) {
	my $p_rs = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id)->resultset("SpPerson")->search(  
	    [ 
	      { first_name => { 'ilike' , '%'.$params->{locus_editor}.'%' } },
	      { last_name  => { 'ilike' , '%'.$params->{locus_editor}.'%' } }
	    ]  );

	$and_conditions->{'locus_owners.sp_person_id'} = {  -in  => $p_rs->get_column('sp_person_id')->as_query };
    }

    if (exists($params->{ontology_term} ) && $params->{ontology_term} ) {
	my ($db_name, $accession) = split ':' , $params->{ontology_term } ; #this only applies if search input is in XX:NNNNNNN format
	my $o_rs = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id)->resultset("Cv::Cvterm")->search(
	    [
	     {
		 'me.name' => { 'ilike' => '%'.$params->{ontology_term}.'%' },
		 'db.name'     => { -in => ['PO', 'GO', 'SP'] }
	     },
	     {
		 'dbxref.accession' =>  { 'ilike' => '%'.$accession.'%' },
		 'db.name'          =>  $db_name
	     }
	     ],
	    {
		join => { 'dbxref' => 'db' }
	    } 
	    );
	$and_conditions->{'locus_dbxrefs.dbxref_id'} = {  -in  => $o_rs->get_column('dbxref_id')->as_query };
    }
	    
    if (exists($params->{genbank_accession} ) && $params->{genbank_accession} ) {
	my $g_rs = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id)->resultset("General::Dbxref")->search(
	    {
		accession => {'ilike', '%'.$params->{genbank_accession}.'%'}
	    }
	    );
	$and_conditions->{'locus_dbxrefs.dbxref_id'} = { -in => $g_rs->get_column('dbxref_id')->as_query };
    }
    if (exists($params->{has_sequence} ) && $params->{has_sequence} eq "true" ) {
	my $d_rs = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id)->resultset("General::Dbxref")->search(
	    {
		'db.name' => "DB:GenBank_GI",
	    }, 
	    {
		join => 'db',
	    });
	$and_conditions->{'locus_dbxrefs.dbxref_id'} = { -in => $d_rs->get_column('dbxref_id')->as_query };
    }

    if (exists($params->{has_marker} ) && $params->{has_marker} eq "true"  ) {
	my $m_rs = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id)->resultset("LocusMarker")->search( {} );
	$and_conditions->{'locus_id'} = { -in => $m_rs->get_column('locus_id')->as_query }; 
    }

    if (exists($params->{has_annotation} ) && $params->{has_annotation} eq "true"  ) {
	my $a_rs = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id)->resultset("General::Dbxref")->search(
	    {
		'db.name' => { -in => ["GO", "PO", "SP"] },
	    }, 
	    {
		join => 'db',
	    });
	$and_conditions->{'locus_dbxrefs.dbxref_id'} = { -in => $a_rs->get_column('dbxref_id')->as_query };
    }
        
###############

    my $draw = $params->{draw};
    $draw =~ s/\D//g; # cast to int

    my $rows = $params->{length} || 10;
    my $start = $params->{start};

    my $page = int($start / $rows)+1;


    # get the count first
    my $rs = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id)->resultset("Locus")->search( 
	{
	    -and => [
		 $or_conditions,
		 $and_conditions,
		 'me.obsolete' => 'f'
		],
	},
	{
	    join =>  [ 'locus_owners' , 'locus_dbxrefs' , 'alleles' ] ,
	    prefetch => 'alleles',
	} 
	);

    my $records_total = $rs->count();
    
    #print STDERR "RECORDS TOTAL: $records_total\n";
    ## then get the data
    #
    my $rs2 = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id)->resultset("Locus")->search(   
	{
	    -and => [
		 $or_conditions,
		 $and_conditions,
		 'me.obsolete' => 'f'
		],
	} ,
	{ 
	    join      =>  [ 'locus_owners' , 'locus_dbxrefs' , 'alleles' ] ,
	    '+select' => [ 'locus_name', 'locus', 'locus_symbol', 'common_name_id' ],
	    '+as'     => [qw/ locus_name genome_locus locus_symbol common_name_id  / ],
	    distinct  => 1,
	    page      => $page, 
	    rows      => $rows, 
	    order_by  => 'locus_name' 
	} 
	);
	
    
    my @result;
    while (my $l = $rs2->next()) { 
	my $common_name_id = $l->common_name_id;
	my $locus_id = $l->get_column("locus_id") ;
	my $dbh = $c->dbc->dbh() ;
	my $locus = CXGN::Phenome::Locus->new($dbh, $locus_id);
	my $common_name = $locus->get_common_name;
	my $locus_name = $l->locus_name;
	$locus = $l->locus;
	my $locus_symbol = $l->locus_symbol;
	my $allele_string;
	my $alleles = $l->alleles;
	while ( my $a = $alleles->next() ) {
	    $allele_string .= $a->allele_symbol . ", ";
	}
	$allele_string = substr($allele_string, 0, -2) ;
	push @result, [ $common_name, "<a href=\"/locus/$locus_id/view\">$locus_name</a>", $locus_symbol, $allele_string ];
    }

    $c->stash->{rest} = { data => [ @result ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
    
    
}

1;
