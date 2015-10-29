
package SGN::Controller::AJAX::Search::Features;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub feature_search :Path('/ajax/search/features') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $params = $c->req->params() || {};

    #print STDERR "PARAMS: ".Dumper($params);
    
    my %query;

# params 
# organism
# type
# type_id
# name
# srcfeature_id
# srcfeature_start
# srcfeature_end
# proptype_id
# prop_value
# description
    
# feature_id
# seqlen
# locations
  
    my $schema = $c->dbic_schema('Bio::Chado::Schema','sgn_chado');

    my $rs = $schema->resultset('Sequence::Feature')->search(
	{'featureloc_features.locgroup' => 0},
	{prefetch => ['featureloc_features']}
	);

    if( my $name = $params->{'name'} ) {
        $rs = $rs->search({ 'me.name' => { ilike => '%'.$name.'%' }});
    }




    if( my $type = $params->{'type'} ) {
        my $type_rs = $schema->resultset('Cv::Cvterm')
                             ->search({ 'lower(name)' => lc $type });
        $rs = $rs->search({ 'me.type_id' => { -in => $type_rs->get_column('cvterm_id')->as_query }});
    }

    if( my $type_id = $params->{'type_id'} ) {
        $rs = $rs->search({ 'me.type_id' => $type_id });
    }

    if( my $organism = $params->{'organism'} ) {
        my $organism_rs = $schema->resultset('Organism::Organism')
                                 ->search({ species => { -ilike => '%'.$organism.'%' }});
        $rs = $rs->search({ 'me.organism_id' => { -in => $organism_rs->get_column('organism_id')->as_query } });
    }

    my $featureloc_prefetch = { prefetch => { 'featureloc_features' => 'srcfeature' }};
    if( my $srcfeature_id = $params->{'srcfeature_id'} ) {
        $rs = $rs->search({ 'featureloc_features.srcfeature_id' => $srcfeature_id }, $featureloc_prefetch );
    }

    if( my $start = $params->{'srcfeature_start'} ) {
        $rs = $rs->search({ 'featureloc_features.fmax' => { '>=' => $start } }, $featureloc_prefetch );
    }

    if( my $end = $params->{'srcfeature_end'} ) {
        $rs = $rs->search({ 'featureloc_features.fmin' => { '<=' => $end+1 } }, $featureloc_prefetch );
    }

    if( my $proptype_id = $params->{'proptype_id'} ) {
        $rs = $rs->search({ 'featureprops.type_id' => $proptype_id },{ prefetch => 'featureprops' });
    }

    if( my $prop_value = $params->{'prop_value'} ) {
        $rs = $rs->search({ 'featureprops.value' => { -ilike => '%'.$prop_value.'%' }},{ prefetch => 'featureprops' });
    }

    if( my $desc = $params->{'description'} ) {
        $rs = $rs->search({
            'featureprops.value'   => { -ilike => '%'.$desc.'%' },
            'featureprops.type_id' => { -in => [description_featureprop_types( $rs )->get_column('cvterm_id')->all] },
            },{
                prefetch => 'featureprops'
            });
    }




        
###############

    my $draw = $params->{draw};
    $draw =~ s/\D//g; # cast to int

    my $rows = $params->{length} || 10;
    my $start = $params->{start};

    my $page = int($start / $rows)+1;


    # get the count first

    my $records_total = $rs->count();
    
    #print STDERR "RECORDS TOTAL: $records_total\n";
    ## then get the data
    #
    #organism type name description location(s) 
    my @result;
    while (my $f = $rs->next()) { 
	my $organism = $f->organism;
	my $type = $f->type;
	my $name = $f->name;
	my $feature_id = $f->feature_id;
	my $description = $f->description;
	my $location = $f->location;


	push @result, [ $organism, $type, "<a href=\"/feature/$feature_id/details\">$name</a>", $description, $location ];
    }

    $c->stash->{rest} = { data => [ @result ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
    
    
}

1;
