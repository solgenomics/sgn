
=head1 NAME

SGN::Controller::AJAX::Stock - a REST controller class to provide the
backend for objects linked with stocks

=head1 DESCRIPTION

Add new stock properties, stock dbxrefs and so on.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>
Naama Menda <nm249@cornell.edu>

=cut

package SGN::Controller::AJAX::Stock;

use Moose;

use List::MoreUtils qw /any /;
use Data::Dumper;
use Try::Tiny;
use CXGN::Phenome::Schema;
use CXGN::Phenome::Allele;
use CXGN::Stock;
use CXGN::Page::FormattingHelpers qw/ columnar_table_html info_table_html html_alternate_show /;
use CXGN::Phenome::DumpGenotypes;
use CXGN::BreederSearch;
use Scalar::Util 'reftype';
use CXGN::BreedersToolbox::StocksFuzzySearch;
use CXGN::Stock::RelatedStocks;
use CXGN::BreederSearch;
use CXGN::Genotype::Search;
use JSON;

use Bio::Chado::Schema;

use Scalar::Util qw(looks_like_number);
use DateTime;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


=head2 add_stockprop


L<Catalyst::Action::REST> action.

Stores a new stockprop in the database

=cut

sub add_stockprop : Path('/stock/prop/add') : ActionClass('REST') { }

sub add_stockprop_POST {
    my ( $self, $c ) = @_;
    my $response;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    if (!$c->user()) {
	$c->stash->{rest} = { error => "Log in required for adding stock properties." }; return;
    }

    if (  any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
        my $req = $c->req;
        my $stock_id = $c->req->param('stock_id');
        my $prop  = $c->req->param('prop');
        $prop =~ s/^\s+|\s+$//g; #trim whitespace from both ends
        my $prop_type = $c->req->param('prop_type');

	my $stock = $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id } );

    if ($stock && $prop && $prop_type) {

        my $message = '';
        if ($prop_type eq 'stock_synonym') {
            my $fuzzy_accession_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
            my $max_distance = 0.2;
            my $fuzzy_search_result = $fuzzy_accession_search->get_matches([$prop], $max_distance, 'accession');
            #print STDERR Dumper $fuzzy_search_result;
            my $found_accessions = $fuzzy_search_result->{'found'};
            my $fuzzy_accessions = $fuzzy_search_result->{'fuzzy'};
            if ($fuzzy_search_result->{'error'}){
                $c->stash->{rest} = { error => "ERROR: ".$fuzzy_search_result->{'error'} };
                $c->detach();
            }
            if (scalar(@$found_accessions) > 0){
                $c->stash->{rest} = { error => "Synonym not added: The synonym you are adding is already stored as its own unique stock or as a synonym." };
                $c->detach();
            }
            if (scalar(@$fuzzy_accessions) > 0){
                my @fuzzy_match_names;
                foreach my $a (@$fuzzy_accessions){
                    foreach my $m (@{$a->{'matches'}}) {
                        push @fuzzy_match_names, $m->{'name'};
                    }
                }
                $message = "CAUTION: The synonym you are adding is similar to these accessions and synonyms in the database: ".join(', ', @fuzzy_match_names).".";
            }
        }

        try {
            $stock->create_stockprops( { $prop_type => $prop }, { autocreate => 1 } );

            my $stock = CXGN::Stock->new({
                schema=>$schema,
                stock_id=>$stock_id,
                is_saving=>1,
                sp_person_id => $c->user()->get_object()->get_sp_person_id(),
                user_name => $c->user()->get_object()->get_username(),
                modification_note => "Added property: $prop_type = $prop"
            });
            my $added_stock_id = $stock->store();

            my $dbh = $c->dbc->dbh();
            my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
            my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

            $c->stash->{rest} = { message => "$message Stock_id $stock_id and type_id $prop_type have been associated with value $prop. ".$refresh->{'message'} };
        } catch {
            $c->stash->{rest} = { error => "Failed: $_" }
        };
    } else {
	    $c->stash->{rest} = { error => "Cannot associate prop $prop_type: $prop with stock $stock_id " };
	}
    } else {
	$c->stash->{rest} = { error => 'user does not have a curator/sequencer/submitter account' };
    }
    #$c->stash->{rest} = { message => 'success' };
}

sub add_stockprop_GET {
    my $self = shift;
    my $c = shift;
    return $self->add_stockprop_POST($c);
}


=head2 get_stockprops

 Usage:
 Desc:         Gets the stockprops of type type_id associated with a stock_id
 Ret:
 Args:
 Side Effects:
 Example:

=cut



sub get_stockprops : Path('/stock/prop/get') : ActionClass('REST') { }

sub get_stockprops_GET {
    my ($self, $c) = @_;

    my $stock_id = $c->req->param("stock_id");
    my $type_id = $c->req->param("type_id");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $prop_rs = $schema->resultset("Stock::Stockprop")->search(
	{
	    stock_id => $stock_id,
	    #type_id => $type_id,
	}, { join => 'type', order_by => 'stockprop_id' } );

    my @propinfo = ();
    while (my $prop = $prop_rs->next()) {
	push @propinfo, { stockprop_id => $prop->stockprop_id, stock_id => $prop->stock_id, type_id => $prop->type_id(), type_name => $prop->type->name(), value => $prop->value() };
    }

    $c->stash->{rest} = \@propinfo;


}


sub delete_stockprop : Path('/stock/prop/delete') : ActionClass('REST') { }

sub delete_stockprop_GET {
    my $self = shift;
    my $c = shift;
    my $stockprop_id = $c->req->param("stockprop_id");
    if (! any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
	$c->stash->{rest} = { error => 'Log in required for deletion of stock properties.' };
	return;
    }
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $spr = $schema->resultset("Stock::Stockprop")->find( { stockprop_id => $stockprop_id });
    if (! $spr) {
	$c->stash->{rest} = { error => 'The specified prop does not exist' };
	return;
    }
    eval {
	$spr->delete();
    };
    if ($@) {
	$c->stash->{rest} = { error => "An error occurred during deletion: $@" };
	    return;
    }
    $c->stash->{rest} = { message => "The element was removed from the database." };

}



sub associate_locus:Path('/ajax/stock/associate_locus') :ActionClass('REST') {}

sub associate_locus_POST :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{rest} = { error => "Nothing here, it's a POST.." } ;
}

sub associate_locus_GET :Args(0) {
    my ( $self, $c ) = @_;
    my $stock_id = $c->req->param('object_id');
    ##my $allele_id = $c->req->param('allele_id');
    #Phytoene synthase 1 (psy1) Allele: 1
    #phytoene synthase 1 (psy1)
    my $locus_input = $c->req->param('loci') ;
    if (!$locus_input) {
        $self->status_bad_request($c, message => 'need loci param' );
        return;
    }
    my ($locus_data, $allele_symbol) = split (/ Allele: / ,$locus_input);
    my $is_default = $allele_symbol ? 'f' : 't' ;
    $locus_data =~ m/(.*)\s\((.*)\)/ ;
    my $locus_name = $1;
    my $locus_symbol = $2;
    #print STDERR "Name: $locus_name Symbol: $locus_symbol Allele: $allele_symbol Default: $is_default\n";

    my $schema =  $c->dbic_schema('Bio::Chado::Schema' , 'sgn_chado');
    my ($allele) = $c->dbic_schema('CXGN::Phenome::Schema')
        ->resultset('Locus')
        ->search({
            locus_name   => $locus_name,
            locus_symbol => $locus_symbol,
                 } )
        ->search_related('alleles' , {
            allele_symbol => $allele_symbol,
            is_default => $is_default} );
    if (!$allele) {
        $c->stash->{rest} = { error => "no allele found for locus '$locus_data' (allele: '$allele_symbol')" };
        return;
    }
    my $stock = $schema->resultset("Stock::Stock")->find({stock_id => $stock_id } ) ;
    my  $allele_id = $allele->allele_id;
    if (!$c->user) {
        $c->stash->{rest} = { error => 'Must be logged in for associating loci! ' };
        return;
    }
    if ( any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
        # if this fails, it will throw an acception and will (probably
        # rightly) be counted as a server error
        if ($stock && $allele_id) {
            try {
                my $cxgn_stock = CXGN::Stock->new(schema => $schema, stock_id => $stock_id);
                $cxgn_stock->associate_allele($allele_id, $c->user->get_object->get_sp_person_id);

                $c->stash->{rest} = ['success'];
                # need to update the loci div!!
                return;
            } catch {
                $c->stash->{rest} = { error => "Failed: $_" };
                return;
            };
        } else {
            $c->stash->{rest} = { error => 'need both valid stock_id and allele_id for adding the stockprop! ' };
        }
    } else {
        $c->stash->{rest} = { error => 'No privileges for adding new loci. You must have an sgn submitter account. Please contact sgn-feedback@solgenomics.net for upgrading your user account. ' };
    }
}

sub display_alleles : Chained('/stock/get_stock') :PathPart('alleles') : ActionClass('REST') { }

sub display_alleles_GET  {
    my ($self, $c) = @_;

    $c->forward('/stock/get_stock_allele_ids');

    my $stock = $c->stash->{stock};
    my $allele_ids = $c->stash->{allele_ids};
    my $dbh = $c->dbc->dbh;
    my @allele_data;
    my $hashref;
    foreach my $allele_id (@$allele_ids) {
        my $allele = CXGN::Phenome::Allele->new($dbh, $allele_id);
        my $phenotype        = $allele->get_allele_phenotype();
        my $allele_link  = qq|<a href="/phenome/allele.pl?allele_id=$allele_id">$phenotype </a>|;
        my $locus_id = $allele->get_locus_id;
        my $locus_name = $allele->get_locus_name;
        my $locus_link = qq|<a href="/phenome/locus_display.pl?locus_id=$locus_id">$locus_name </a>|;
        push @allele_data,
        [
         (
          $locus_link,
          $allele->get_allele_name,
          $allele_link
         )
        ];
    }
    $hashref->{html} = @allele_data ?
        columnar_table_html(
            headings     =>  [ "Locus name", "Allele symbol", "Phenotype" ],
            data         => \@allele_data,
        )  : undef ;
    $c->stash->{rest} = $hashref;
}

##############


sub display_ontologies : Chained('/stock/get_stock') :PathPart('ontologies') : ActionClass('REST') { }

sub display_ontologies_GET  {
    my ($self, $c) = @_;
    $c->forward('/stock/get_stock_cvterms');
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
    my $stock = $c->stash->{stock};
    my $stock_id = $stock->get_stock_id;
    my $trait_db_name => $c->get_conf('trait_ontology_db_name');
    my $trait_cvterms = $c->stash->{stock_cvterms}->{$trait_db_name};
    my $po_cvterms = $c->stash->{stock_cvterms}->{PO} ;
    # should GO be here too?
    my $go_cvterms = $c->stash->{stock_cvterms}->{GO};
    my @stock_cvterms;
    push @stock_cvterms, @$trait_cvterms if $trait_cvterms;
    push @stock_cvterms, @$po_cvterms if $po_cvterms;
    ################################
    ###the following code should be re-formatted in JSON object,
    #and the html generated in the javascript code
    ### making this more reusable !
    ###############################
    my $hashref;
    # need to check if the user is logged in, and has editing privileges
    my $privileged;
    if ($c->user) {
        if ( $c->user->check_roles('curator') || $c->user->check_roles('submitter')  || $c->user->check_roles('sequencer') ) { $privileged = 1; }
    }
    # the ontology term is a stock_cvterm
    # the evidence details are in stock_cvtermprop (relationship, evidence_code,
    # evidence_description, evidence_with, reference, obsolete
    # and the metadata for sp_person_id, create_date, etc.)
    my @obs_annot;
    #keys= cvterms, values= hash of arrays
    #(keys= ontology details, values= list of evidences)
    my %ont_hash = () ;
    #some cvterms to be used for the evidence codes
    my $cvterm_rs =  $schema->resultset("Cv::Cvterm");
    my ($rel_cvterm) = $cvterm_rs->search( { name => 'relationship'} );
    my ($evidence_cvterm) = $cvterm_rs->search( { name => 'evidence_code' } );
    # go over the lists of Bio::Chado::Schema::Cv::Cvterm objects
    # and build the annotation details
    foreach (@stock_cvterms) {
        my $cv_name      = $_->cvterm->cv->name;
        my $cvterm_id    = $_->cvterm->cvterm_id;
        my $cvterm_name  = $_->cvterm->name;
        my $db_name      = $_->cvterm->dbxref->db->name;
        my $accession    = $_->cvterm->dbxref->accession;
        my $db_accession = $accession;
        $db_accession = $cvterm_id if $db_name eq $trait_db_name;
        my $url = $_->cvterm->dbxref->db->urlprefix . $_->cvterm->dbxref->db->url;
        my $cvterm_link =
            qq |<a href="/cvterm/$cvterm_id/view" target="blank">$cvterm_name</a>|;
        # the stock_cvtermprop objects have all the evidence and metadata for the annotation
        my $props = $_->stock_cvtermprops;
        my ($relationship_id) = $props->search( { type_id =>$rel_cvterm->cvterm_id} )->single ? $props->search( { type_id =>$rel_cvterm->cvterm_id} )->single->value : undef; # should be 1 relationship per annotation
        my ($evidence_code_id) = $props->search( { type_id => $evidence_cvterm->cvterm_id })->single ?  $props->search( { type_id => $evidence_cvterm->cvterm_id })->single->value : undef;
        # should be 1 evidence_code
        ############
        my $evidence_desc_name;
        my $rel_name = $relationship_id ? $cvterm_rs->find({ cvterm_id=>$relationship_id})->name : undef;
        my $ev_name  = $evidence_code_id ? $cvterm_rs->find({ cvterm_id=>$evidence_code_id})->name : undef;
        #if the cvterm has an obsolete property (must have a true value
        # since annotations can be obsolete and un-obsolete, it is possible
        # to have an obsolete property with value = 0, meaning the annotation
        # is not obsolete.
        # build the unobsolete link
        my $stock_cvterm_id = $_->stock_cvterm_id;
        my ($obsolete_prop) = $props->search(
            {
                value => '1',
                'type.name' => 'obsolete',
            },
            { join =>  'type' } , );
        if ($obsolete_prop) {
            my $unobsolete =  qq | <input type = "button" onclick= "javascript:Tools.toggleObsoleteAnnotation('0', \'$stock_cvterm_id\',  \'/ajax/stock/toggle_obsolete_annotation\', \'/stock/$stock_id/ontologies\')" value = "unobsolete" /> | if $privileged ;

            # generate the list of obsolete annotations
            push @obs_annot,
            $rel_name . " "
                . $cvterm_link . " ("
                . $ev_name . ")"
                . $unobsolete;
        }else {
            my $ontology_details = $rel_name
                . qq| $cvterm_link ($db_name:<a href="$url$db_accession" target="blank"> $accession</a>)<br />|;
            # build the obsolete link if the user has  editing privileges
            my $obsolete_link =  qq | <input type = "button" onclick="javascript:Tools.toggleObsoleteAnnotation('1', \'$stock_cvterm_id\',  \'/ajax/stock/toggle_obsolete_annotation\', \'/stock/$stock_id/ontologies\')" value ="delete" /> | if $privileged ;

            my ($ev_with) = $props->search( {'type.name' => 'evidence_with'} , { join => 'type'  } )->single;
            my $ev_with_dbxref = $ev_with ? $schema->resultset("General::Dbxref")->find( { dbxref_id=> $ev_with->value } ) : undef;
            my $ev_with_url = $ev_with_dbxref ?  $ev_with_dbxref->urlprefix . $ev_with_dbxref->url . $ev_with_dbxref->accession : undef;
            my $ev_with_acc = $ev_with_dbxref ? $ev_with_dbxref->accession : undef ;
            # the reference is a stock_cvterm.pub_id
            my ($reference) = $_->pub;
            my $reference_dbxref = $reference ? $reference->pub_dbxrefs->first->dbxref : undef;
            my $reference_url = $reference_dbxref ? $reference_dbxref->db->urlprefix . $reference_dbxref->db->url . $reference_dbxref->accession : undef;
            my $reference_acc = $reference_dbxref ? $reference_dbxref->accession : undef;
            my $display_ref = $reference_acc =~ /^\d/ ? 1 : 0;
            # the submitter is a sp_person_id prop
            my ($submitter) = $props->search( {'type.name' => 'sp_person_id'} , { join => 'type' } );
            my $sp_person_id = $submitter ? $submitter->value : undef;
            my $person= CXGN::People::Person->new($c->dbc->dbh, $sp_person_id);
            my $submitter_info = qq| <a href="solpeople/personal_info.pl?sp_person_id=$sp_person_id">| . $person->get_first_name . " " . $person->get_last_name . "</a>" ;
            my ($date) = $props->search( {'type.name' => 'create_date'} , { join =>  'type'  } )->first || undef ; # $props->search( {'type.name' => 'modified_date'} , { join =>  'type' } ) ;
            my $evidence_date = $date ? substr $date->value , 0, 10 : undef;

            # add an empty row if there is more than 1 evidence code
            my $ev_string;
            $ev_string .= "<hr />" if $ont_hash{$cv_name}{$ontology_details};
            no warnings 'uninitialized';
            $ev_string .=  $ev_name . "<br />";
            $ev_string .= $evidence_desc_name . "<br />" if $evidence_desc_name;
            $ev_string .= "<a href=\"$ev_with_url\">$ev_with_acc</a><br />" if $ev_with_acc;
            $ev_string .="<a href=\"$reference_url\">$reference_acc</a><br />" if $display_ref;
            $ev_string .= "$submitter_info $evidence_date $obsolete_link";
            $ont_hash{$cv_name}{$ontology_details} .= $ev_string;
        }
    }
    my $ontology_evidence;

    #now we should have an %ont_hash with all the details we need for printing ...
    #hash keys are the cv names ..
    for my $cv_name ( sort keys %ont_hash ) {
        my @evidence;
        #and for each ontology annotation create an array ref of evidences
        for my $ont_detail ( sort keys %{ $ont_hash{$cv_name} } ) {
            push @evidence,
            [ $ont_detail, $ont_hash{$cv_name}{$ont_detail} ];
        }
        my $ev = join "\n", map {
            qq|<div class="term">$_->[0]</div>\n|
                .qq|<div class="evidence">$_->[1]</div>\n|;
        } @evidence;
        $ontology_evidence .= info_table_html(
            $cv_name     => $ev,
            __border     => 0,
            __tableattrs => 'width="100%"',
            );
    }
    #display ontology annotation form
    my $print_obsoleted;
    if ( @obs_annot &&  $privileged ) {
        my $obsoleted;
        foreach my $term (@obs_annot) {
            $obsoleted .= qq |$term  <br />\n |;
        }
        $print_obsoleted = html_alternate_show(
            'obsoleted_terms', 'Show obsolete',
            '',                qq|<div class="minorbox">$obsoleted</div> |,
            );
    }
    $hashref->{html} = $ontology_evidence . $print_obsoleted;
    $c->stash->{rest} = $hashref;
}

############
sub associate_ontology:Path('/ajax/stock/associate_ontology') :ActionClass('REST') {}

sub associate_ontology_GET :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{rest} = { error => "Nothing here, it's a GET.." } ;
}


sub associate_ontology_POST :Args(0) {
    my ( $self, $c ) = @_;

    my $params = map { $_ => $c->req->param($_) } qw/
       object_id ontology_input relationship evidence_code evidence_description
       evidence_with reference
    /;

    my $stock_id       = $c->req->param('object_id');
    my $ontology_input = $c->req->param('term_name');
    my $relationship   = $c->req->param('relationship'); # a cvterm_id
    my $evidence_code  = $c->req->param('evidence_code'); # a cvterm_id
    my $evidence_description = $c->req->param('evidence_description') || undef; # a cvterm_id
    my $evidence_with  = $c->req->param('evidence_with') || undef; # a dbxref_id (type='evidence_with' value = 'dbxref_id'
    my $logged_user = $c->user;
    my $logged_person_id = $logged_user->get_object->get_sp_person_id if $logged_user;

    my $reference = $c->req->param('reference'); # a pub_id

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cvterm_rs = $schema->resultset('Cv::Cvterm');
    my ($pub_id) = $reference ? $reference :
        $schema->resultset('Pub::Pub')->search( { title=> 'curator' } )->first->pub_id; # a pub for 'curator' should already be in the sgn database. can add here $curator_cvterm->create_with ... and then create the curator pub with type_id of $curator_cvterm

    #solanaceae_phenotype--SP:000001--fruit size
    my ($cv_name, $db_accession, $cvterm_name)  = split /--/ , $ontology_input;
    my ($db_name, $accession) = split ':' , $db_accession;

    my ($cvterm) = $schema
        ->resultset('General::Db')
        ->search({ 'me.name' => $db_name, } )->search_related('dbxrefs' , { accession => $accession } )
        ->search_related('cvterm')->first; # should be only 1 cvterm per dbxref
    if (!$cvterm) {
        $c->stash->{rest} = { error => "no ontology term found for term $db_name : $accession" };
        return;
    }
    my ($stock) = $c->stash->{stock} || $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id } );

    my  $cvterm_id = $cvterm->cvterm_id;
    if (!$c->user) {
        $c->stash->{rest} = { error => 'Must be logged in for associating ontology terms! ' };
        return;
    }
    if ( any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
        # if this fails, it will throw an acception and will (probably
        # rightly) be counted as a server error
        #########################################################
        if ($stock && $cvterm_id) {
            try {
                #check if the stock_cvterm exists
                my $s_cvterm_rs = $stock->search_related(
                    'stock_cvterms', { cvterm_id => $cvterm_id, pub_id => $pub_id } );
                # if it exists , we need to increment the rank
                my $rank = 0;
                if ($s_cvterm_rs->first) {
                    $rank = $s_cvterm_rs->get_column('rank')->max + 1;
                    # now check if the evidence codes already exists
                    my ($rel_prop, $ev_prop, $desc_prop, $with_prop);
                    my $eprops = $s_cvterm_rs->search_related('stock_cvtermprops');
                    $rel_prop = $eprops->search( {
                        type_id => $cvterm_rs->search( { name => 'relationship'})->single->cvterm_id,
                        value => $relationship  })->first;

                    $ev_prop = $eprops->search( {
                        type_id =>   $cvterm_rs->search( { name => 'evidence_code'})->single->cvterm_id,
                        value => $evidence_code })->first;

                    $desc_prop = $eprops->search( {
                        type_id =>  $cvterm_rs->search( { name => 'evidence description'})->single->cvterm_id,
                        value => $evidence_description })->first if $evidence_description;

                    $with_prop = $eprops->search( {
                        type_id =>  $cvterm_rs->search( { name => 'evidence_with'})->single->cvterm_id,
                        value => $evidence_with })->first if $evidence_with;

                    # return error if annotation + evidence exist
                    if ($rel_prop && $ev_prop) {
                        $c->stash->{rest} = { error => "Annotation exists with these evidence codes! " };
                        return;
                    }
                }
                # now store a new stock_cvterm
                my $s_cvterm = $stock->create_related('stock_cvterms', {
                    cvterm_id => $cvterm_id,
                    pub_id    => $pub_id,
                    rank      => $rank, } );
#########
                $s_cvterm->create_stock_cvtermprops(
                    { 'relationship' => $relationship } , { db_name => 'OBO_REL', cv_name =>'relationship' } ) if looks_like_number($relationship);
                $s_cvterm->create_stock_cvtermprops(
                    { 'evidence_code' => $evidence_code } , { db_name => 'ECO', cv_name =>'evidence_code' } ) if looks_like_number($evidence_code);
                 $s_cvterm->create_stock_cvtermprops(
                     { 'evidence_description' => $evidence_description } , { cv_name =>'local', autocreate => 1 } ) if looks_like_number($evidence_description);
                $s_cvterm->create_stock_cvtermprops(
                    { 'evidence_with' => $evidence_with  } , { cv_name =>'local' , autocreate=>1} ) if looks_like_number($evidence_with);
                # store the person loading the annotation
                $s_cvterm->create_stock_cvtermprops(
                    { 'sp_person_id' => $logged_person_id  } , { cv_name =>'local' , autocreate=>1} );
                #store today's date
                my $val = "now()";
                $s_cvterm->create_stock_cvtermprops(
                    { 'create_date' =>  \$val   } , { cv_name =>'local' , autocreate=>1, allow_duplicate_values => 1} );

                $c->stash->{rest} = ['success'];
                return;
            } catch {
                print STDERR "***** associate_ontology failed! $_ \n\n";
                $c->stash->{rest} = { error => "Failed: $_" };
                # send an email to sgn bugs
                $c->stash->{email} = {
                    to      => 'sgn-bugs@sgn.cornell.edu',
                    from    => 'sgn-bugs@sgn.cornell.edu',
                    subject => "Associate ontology failed! Stock_id = $stock_id",
                    body    => $_,
                };
                $c->forward( $c->view('Email') );
                return;
            };
            # if you reached here this means associate_ontology worked. Now send an email to sgn-db-curation
            print STDERR "***** User " . $logged_user->get_object->get_first_name . " " . $logged_user->get_object->get_last_name . "has stored a new ontology term for stock $stock_id\n\n";
            $c->stash->{email} = {
                to      => 'sgn-db-curation@sgn.cornell.edu',
                from    => 'www-data@sgn-vm.sgn.cornell.edu',
                subject => "New ontology term loaded. Stock $stock_id",
                body    => "User " . $logged_user->get_object->get_first_name . " " . $logged_user->get_object->get_last_name . "has stored a new ontology term for stock $stock_id http://solgenomics.net/stock/$stock_id/view",
            };
            $c->forward( $c->view('Email') );

        } else {
            $c->stash->{rest} = { error => 'need both valid stock_id and cvterm_id for adding an ontology term to this stock! ' };
        }
    } else {
        $c->stash->{rest} = { error => 'No privileges for adding new ontology terms. You must have an sgn submitter account. Please contact sgn-feedback@solgenomics.net for upgrading your user account. ' };
    }
}

sub references : Chained('/stock/get_stock') :PathPart('references') : ActionClass('REST') { }


sub references_GET :Args(0) {
    my ($self, $c) = @_;
    my $stock = $c->stash->{stock};
    # get a list of references
    my $q =  "SELECT dbxref.dbxref_id, pub.pub_id, accession,title
              FROM public.stock_pub
              JOIN public.pub USING (pub_id)
              JOIN public.pub_dbxref USING (pub_id)
              JOIN public.dbxref USING (dbxref_id)
              WHERE stock_id= ?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($stock->get_stock_id);
    my $response_hash={};
    while (my ($dbxref_id, $pub_id, $accession, $title) = $sth->fetchrow_array) {
        $response_hash->{$accession . ": " . $title} = $pub_id ;
    }
    $c->stash->{rest} = $response_hash;
}


# nothing is returned here for now. This is just required for the integrity of the associate ontology form
sub evidences : Chained('/stock/get_stock') :PathPart('evidences') : ActionClass('REST') { }

sub evidences_GET :Args(0) {
    my ($self, $c) = @_;
    my $stock = $c->stash->{stock};
    # get a list of evidences
    my $response_hash={};

    $c->stash->{rest} = $response_hash;
}

sub toggle_obsolete_annotation : Path('/ajax/stock/toggle_obsolete_annotation') : ActionClass('REST') { }

sub toggle_obsolete_annotation_POST :Args(0) {
    my ($self, $c) = @_;
    my $stock = $c->stash->{stock};
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $obsolete_cvterm = $schema->resultset("Cv::Cvterm")->search(
        { name => 'obsolete',
          is_obsolete => 0 ,
        } )->single; #should be one local term
    my $stock_cvterm_id = $c->request->body_parameters->{id};
    my $obsolete = $c->request->body_parameters->{obsolete};
    my $response = {} ;
    if ($stock_cvterm_id && $c->user ) {
        my $stock_cvterm = $schema->resultset("Stock::StockCvterm")->find( { stock_cvterm_id => $stock_cvterm_id } );
        if ($stock_cvterm) {
            my ($prop) = $stock_cvterm->stock_cvtermprops( { type_id => $obsolete_cvterm->cvterm_id } ) if $obsolete_cvterm;
            if ($prop) {
                $prop->update( { value => $obsolete } ) ;
            } else {
                $stock_cvterm->create_stock_cvtermprops(
                    { obsolete   => $obsolete },
                    { autocreate => 1, cv_name => 'local'  },
                    );
            }
            $response->{response} = "success";
        }
        else { $response->{error} = "No stock_cvtermp found for id $stock_cvterm_id ! "; }
    } else { $response->{error} = 'stock_cvterm $stock_cvterm_id does not exists! ';  }
    $c->stash->{rest} = $response;
}


=head2 trait_autocomplete

Public Path: /ajax/stock/trait_autocomplete

Autocomplete a trait name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.
Finds only traits that exist in nd_experiment_phenotype

=cut

sub trait_autocomplete : Local : ActionClass('REST') { }

sub trait_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');
    # trim and regularize whitespace
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my @response_list;
    my $q = "SELECT DISTINCT cvterm.name FROM phenotype JOIN cvterm ON cvterm_id = observable_id WHERE cvterm.name ilike ? ORDER BY cvterm.name";
    #my $q = "select distinct cvterm.name from stock join nd_experiment_stock using (stock_id) join nd_experiment_phenotype using (nd_experiment_id) join phenotype using (phenotype_id) join cvterm on cvterm_id = phenotype.observable_id WHERE cvterm.name ilike ?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute( '%'.$term.'%');
    while  (my ($term_name) = $sth->fetchrow_array ) {
        push @response_list, $term_name;
    }
    $c->stash->{rest} = \@response_list;
}

=head2 project_autocomplete

Public Path: /ajax/stock/project_autocomplete

Autocomplete a project name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.
Finds only projects that are linked with a stock

=cut

sub project_autocomplete : Local : ActionClass('REST') { }

sub project_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');
    # trim and regularize whitespace
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my @response_list;
    my $q = "SELECT  distinct project.name FROM project WHERE project.name ilike ? ORDER BY project.name LIMIT 100";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute( '%'.$term.'%');
    while  (my ($project_name) = $sth->fetchrow_array ) {
        push @response_list, $project_name;
    }
    $c->stash->{rest} = \@response_list;
}

=head2 project_year_autocomplete

Public Path: /ajax/stock/project_year_autocomplete

Autocomplete a project year value.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.
Finds only year projectprops that are linked with a stock

=cut

sub project_year_autocomplete : Local : ActionClass('REST') { }

sub project_year_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');
    # trim and regularize whitespace
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my @response_list;
    my $q = "SELECT  distinct value FROM
  nd_experiment_stock JOIN
  nd_experiment_project USING (nd_experiment_id) JOIN
  projectprop USING (project_id) JOIN
  cvterm on cvterm_id = projectprop.type_id
  WHERE cvterm.name ilike ? AND value ilike ?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute( '%year%' , '%'.$term.'%');
    while  (my ($project_name) = $sth->fetchrow_array ) {
        push @response_list, $project_name;
    }
    $c->stash->{rest} = \@response_list;
}


=head2 seedlot_name_autocomplete

Public Path: /ajax/stock/seedlot_name_autocomplete

Autocomplete a seedlot name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.

=cut

sub seedlot_name_autocomplete : Local : ActionClass('REST') { }

sub seedlot_name_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;
    my $term = $c->req->param('term');
    # trim and regularize whitespace
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    my @response_list;
    my $q = "SELECT uniquename FROM stock where type_id = ? AND uniquename ilike ? LIMIT 1000";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute( $seedlot_cvterm_id , '%'.$term.'%');
    while  (my ($uniquename) = $sth->fetchrow_array ) {
        push @response_list, $uniquename;
    }
    $c->stash->{rest} = \@response_list;
}


=head2 stockproperty_autocomplete

Public Path: /ajax/stock/stockproperty_autocomplete

Autocomplete a stock property. Takes GET param for term and property,
C<term>, responds with a JSON array of completions for that term.
Finds stockprop values that are linked with a stock

=cut

sub stockproperty_autocomplete : Local : ActionClass('REST') { }

sub stockproperty_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $term = $c->req->param('term');
    my $cvterm_name = $c->req->param('property');
    # trim and regularize whitespace
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $cvterm_name, 'stock_property')->cvterm_id();
    my @response_list;
    my $q = "SELECT distinct value FROM stockprop WHERE type_id=? and value ilike ?";
    my $sth = $schema->storage->dbh->prepare($q);
    $sth->execute( $cvterm_id, '%'.$term.'%');
    while  (my ($val) = $sth->fetchrow_array ) {
        push @response_list, $val;
    }
    $c->stash->{rest} = \@response_list;
}

=head2 geolocation_autocomplete

Public Path: /ajax/stock/geolocation_autocomplete

Autocomplete a geolocation description.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.
Finds only locations that are linked with a stock

=cut

sub geolocation_autocomplete : Local : ActionClass('REST') { }

sub geolocation_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');
    # trim and regularize whitespace
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my @response_list;
    my $q = "SELECT  distinct nd_geolocation.description FROM
  nd_experiment_stock JOIN
  nd_experiment USING (nd_experiment_id) JOIN
  nd_geolocation USING (nd_geolocation_id)
  WHERE nd_geolocation.description ilike ?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute( '%'.$term.'%');
    while  (my ($location) = $sth->fetchrow_array ) {
        push @response_list, $location;
    }
    $c->stash->{rest} = \@response_list;
}

=head2 stock_autocomplete

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub stock_autocomplete : Local : ActionClass('REST') { }

sub stock_autocomplete_GET :Args(0) {
    my ($self, $c) = @_;

    my $term = $c->req->param('term');
    my $stock_type_id = $c->req->param('stock_type_id');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my $stock_type_where = '';
    if ($stock_type_id){
        $stock_type_where = " AND type_id = $stock_type_id ";
    }

    my @response_list;
    my $q = "select distinct(uniquename) from stock where uniquename ilike ? $stock_type_where ORDER BY stock.uniquename LIMIT 100";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my ($stock_name) = $sth->fetchrow_array) {
	push @response_list, $stock_name;
    }

    #print STDERR "stock_autocomplete RESPONSELIST = ".join ", ", @response_list;

    $c->stash->{rest} = \@response_list;
}

=head2 accession_autocomplete

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub accession_autocomplete : Local : ActionClass('REST') { }

sub accession_autocomplete_GET :Args(0) {
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @response_list;
    my $q = "select distinct(stock.uniquename) from stock join cvterm on(type_id=cvterm_id) where stock.uniquename ilike ? and (cvterm.name='accession' or cvterm.name='vector_construct') ORDER BY stock.uniquename LIMIT 20";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my ($stock_name) = $sth->fetchrow_array) {
	push @response_list, $stock_name;
    }

    #print STDERR Dumper @response_list;

    $c->stash->{rest} = \@response_list;
}

=head2 accession_or_cross_autocomplete

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub accession_or_cross_autocomplete : Local : ActionClass('REST') { }

sub accession_or_cross_autocomplete_GET :Args(0) {
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @response_list;
    my $q = "select distinct(stock.uniquename) from stock join cvterm on(type_id=cvterm_id) where stock.uniquename ilike ? and (cvterm.name='accession' or cvterm.name='cross') ORDER BY stock.uniquename LIMIT 20";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my ($stock_name) = $sth->fetchrow_array) {
	push @response_list, $stock_name;
    }

    #print STDERR Dumper @response_list;

    $c->stash->{rest} = \@response_list;
}

=head2 cross_autocomplete

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub cross_autocomplete : Local : ActionClass('REST') { }

sub cross_autocomplete_GET :Args(0) {
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @response_list;
    my $q = "select distinct(stock.uniquename) from stock join cvterm on(type_id=cvterm_id) where stock.uniquename ilike ? and cvterm.name='cross' ORDER BY stock.uniquename LIMIT 20";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my ($stock_name) = $sth->fetchrow_array) {
        push @response_list, $stock_name;
    }

    #print STDERR Dumper @response_list;
    $c->stash->{rest} = \@response_list;
}

=head2 family_name_autocomplete

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub family_name_autocomplete : Local : ActionClass('REST') { }

sub family_name_autocomplete_GET :Args(0) {
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @response_list;
    my $q = "select distinct(stock.uniquename) from stock join cvterm on(type_id=cvterm_id) where stock.uniquename ilike ? and cvterm.name='family_name' ORDER BY stock.uniquename LIMIT 20";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my ($stock_name) = $sth->fetchrow_array) {
        push @response_list, $stock_name;
    }

    #print STDERR Dumper @response_list;
    $c->stash->{rest} = \@response_list;
}


=head2 population_autocomplete

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub population_autocomplete : Local : ActionClass('REST') { }

sub population_autocomplete_GET :Args(0) {
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();

    my @response_list;
    my $q = "select distinct(uniquename) from stock where uniquename ilike ? and type_id=? ORDER BY stock.uniquename";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%', $population_cvterm_id);
    while (my ($stock_name) = $sth->fetchrow_array) {
	push @response_list, $stock_name;
    }

    #print STDERR "stock_autocomplete RESPONSELIST = ".join ", ", @response_list;

    $c->stash->{rest} = \@response_list;
}

=head2 accession_population_autocomplete

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub accession_population_autocomplete : Local : ActionClass('REST') { }

sub accession_population_autocomplete_GET :Args(0) {
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @response_list;
    my $q = "select distinct(stock.uniquename) from stock join cvterm on(type_id=cvterm_id) where stock.uniquename ilike ? and (cvterm.name='accession' or cvterm.name='population') ORDER BY stock.uniquename";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my ($stock_name) = $sth->fetchrow_array) {
	push @response_list, $stock_name;
    }

    #print STDERR "stock_autocomplete RESPONSELIST = ".join ", ", @response_list;

    $c->stash->{rest} = \@response_list;
}


=head2 pedigree_female_parent_autocomplete

Public Path: /ajax/stock/pedigree_female_parent_autocomplete

Autocomplete a female parent associated with pedigree.

=cut

sub pedigree_female_parent_autocomplete: Local : ActionClass('REST'){}

sub pedigree_female_parent_autocomplete_GET : Args(0){
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my @response_list;

    my $q = "SELECT distinct (pedigree_female_parent.uniquename) FROM stock AS pedigree_female_parent
    JOIN stock_relationship ON (stock_relationship.subject_id = pedigree_female_parent.stock_id)
    JOIN cvterm AS cvterm1 ON (stock_relationship.type_id = cvterm1.cvterm_id) AND cvterm1.name = 'female_parent'
    JOIN stock AS check_type ON (stock_relationship.object_id = check_type.stock_id)
    JOIN cvterm AS cvterm2 ON (check_type.type_id = cvterm2.cvterm_id) AND cvterm2.name = 'accession'
    WHERE pedigree_female_parent.uniquename ilike ? ORDER BY pedigree_female_parent.uniquename";

    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my($pedigree_female_parent) = $sth->fetchrow_array){
      push @response_list, $pedigree_female_parent;
    }

  #print STDERR Dumper @response_list ;
    $c->stash->{rest} = \@response_list;

}


=head2 pedigree_male_parent_autocomplete

Public Path: /ajax/stock/pedigree_male_parent_autocomplete

Autocomplete a male parent associated with pedigree.

=cut

sub pedigree_male_parent_autocomplete: Local : ActionClass('REST'){}

sub pedigree_male_parent_autocomplete_GET : Args(0){
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my @response_list;

    my $q = "SELECT distinct (pedigree_male_parent.uniquename) FROM stock AS pedigree_male_parent
    JOIN stock_relationship ON (stock_relationship.subject_id = pedigree_male_parent.stock_id)
    JOIN cvterm AS cvterm1 ON (stock_relationship.type_id = cvterm1.cvterm_id) AND cvterm1.name = 'male_parent'
    JOIN stock AS check_type ON (stock_relationship.object_id = check_type.stock_id)
    JOIN cvterm AS cvterm2 ON (check_type.type_id = cvterm2.cvterm_id) AND cvterm2.name = 'accession'
    WHERE pedigree_male_parent.uniquename ilike ? ORDER BY pedigree_male_parent.uniquename";

    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my($pedigree_male_parent) = $sth->fetchrow_array){
        push @response_list, $pedigree_male_parent;
    }

    $c->stash->{rest} = \@response_list;

}


=head2 cross_female_parent_autocomplete

Public Path: /ajax/stock/cross_female_parent_autocomplete

Autocomplete a female parent associated with cross.

=cut

sub cross_female_parent_autocomplete: Local : ActionClass('REST'){}

sub cross_female_parent_autocomplete_GET : Args(0){
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my @response_list;

    my $q = "SELECT distinct (cross_female_parent.uniquename) FROM stock AS cross_female_parent
    JOIN stock_relationship ON (stock_relationship.subject_id = cross_female_parent.stock_id)
    JOIN cvterm AS cvterm1 ON (stock_relationship.type_id = cvterm1.cvterm_id) AND cvterm1.name = 'female_parent'
    JOIN stock AS check_type ON (stock_relationship.object_id = check_type.stock_id)
    JOIN cvterm AS cvterm2 ON (check_type.type_id = cvterm2.cvterm_id) AND cvterm2.name = 'cross'
    WHERE cross_female_parent.uniquename ilike ? ORDER BY cross_female_parent.uniquename";

    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my($cross_female_parent) = $sth->fetchrow_array){
      push @response_list, $cross_female_parent;
    }

  #print STDERR Dumper @response_list ;
    $c->stash->{rest} = \@response_list;

}


=head2 cross_male_parent_autocomplete

Public Path: /ajax/stock/cross_male_parent_autocomplete

Autocomplete a male parent associated with cross.

=cut

sub cross_male_parent_autocomplete: Local : ActionClass('REST'){}

sub cross_male_parent_autocomplete_GET : Args(0){
    my ($self, $c) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;
    my @response_list;

    my $q = "SELECT distinct (cross_male_parent.uniquename) FROM stock AS cross_male_parent
    JOIN stock_relationship ON (stock_relationship.subject_id = cross_male_parent.stock_id)
    JOIN cvterm AS cvterm1 ON (stock_relationship.type_id = cvterm1.cvterm_id) AND cvterm1.name = 'male_parent'
    JOIN stock AS check_type ON (stock_relationship.object_id = check_type.stock_id)
    JOIN cvterm AS cvterm2 ON (check_type.type_id = cvterm2.cvterm_id) AND cvterm2.name = 'cross'
    WHERE cross_male_parent.uniquename ilike ? ORDER BY cross_male_parent.uniquename";

    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute('%'.$term.'%');
    while (my($cross_male_parent) = $sth->fetchrow_array){
        push @response_list, $cross_male_parent;
    }

    $c->stash->{rest} = \@response_list;

}


sub parents : Local : ActionClass('REST') {}

sub parents_GET : Path('/ajax/stock/parents') Args(0) {
    my $self = shift;
    my $c = shift;

    my $stock_id = $c->req->param("stock_id");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $female_parent_type_id = $schema->resultset("Cv::Cvterm")->find( { name=> "female_parent" } )->cvterm_id();

    my $male_parent_type_id = $schema->resultset("Cv::Cvterm")->find( { name=> "male_parent" } )->cvterm_id();

    my %parent_types;
    $parent_types{$female_parent_type_id} = "female";
    $parent_types{$male_parent_type_id} = "male";

    my $parent_rs = $schema->resultset("Stock::StockRelationship")->search( { 'me.type_id' => { -in => [ $female_parent_type_id, $male_parent_type_id] }, object_id => $stock_id })->search_related("subject");

    my @parents;
    while (my $p = $parent_rs->next()) {
	push @parents, [
	    $p->get_column("stock_id"),
	    $p->get_column("uniquename"),
	];

    }
    $c->stash->{rest} = {
	stock_id => $stock_id,
	parents => \@parents,
    };
}

sub remove_stock_parent : Local : ActionClass('REST') { }

sub remove_parent_GET : Path('/ajax/stock/parent/remove') Args(0) {
    my ($self, $c) = @_;

    my $stock_id = $c->req->param("stock_id");
    my $parent_id = $c->req->param("parent_id");

    if (!$stock_id || ! $parent_id) {
	$c->stash->{rest} = { error => "No stock and parent specified" };
	return;
    }

    if (! ($c->user && ($c->user->check_roles('curator') || $c->user->check_roles('submitter'))))  {
	$c->stash->{rest} = { error => "Log in is required, or insufficent privileges, for removing parents" };
	return;
    }

    my $q = $c->dbic_schema("Bio::Chado::Schema")->resultset("Stock::StockRelationship")->find( { object_id => $stock_id, subject_id=> $parent_id });

    eval {
	$q->delete();
    };
    if ($@) {
	$c->stash->{rest} = { error => $@ };
	return;
    }

    $c->stash->{rest} = { success => 1 };
}



=head2 add_stock_parent

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub add_stock_parent : Local : ActionClass('REST') { }

sub add_stock_parent_GET :Args(0) {
    my ($self, $c) = @_;

    print STDERR "Add_stock_parent function...\n";
    if (!$c->user()) {
	print STDERR "User not logged in... not associating stocks.\n";
	$c->stash->{rest} = {error => "You need to be logged in to add pedigree information." };
	return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	print STDERR "User does not have sufficient privileges.\n";
	$c->stash->{rest} = {error =>  "you have insufficient privileges to add pedigree information." };
	return;
    }

    my $stock_id = $c->req->param('stock_id');
    my $parent_name = $c->req->param('parent_name');
    my $parent_type = $c->req->param('parent_type');

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $cvterm_name = "";
    my $cross_type = "";
    if ($parent_type eq "male") {
        $cvterm_name = "male_parent";
    }
    elsif ($parent_type eq "female") {
        $cvterm_name = "female_parent";
        $cross_type = $c->req->param('cross_type');
    }

    my $type_id_row = SGN::Model::Cvterm->get_cvterm_row($schema, $cvterm_name, "stock_relationship" )->cvterm_id();

    # check if a parent of this parent_type is already associated with this stock
    #
    my $previous_parent = $schema->resultset("Stock::StockRelationship")->find({
        type_id => $type_id_row,
        object_id => $stock_id
    });

    if ($previous_parent) {
	print STDERR "The stock ".$previous_parent->subject_id." is already associated with stock $stock_id - returning.\n";
	$c->stash->{rest} = { error => "A $parent_type parent with id ".$previous_parent->subject_id." is already associated with this stock. Please specify another parent." };
	return;
    }

    print STDERR "PARENT_NAME = $parent_name STOCK_ID $stock_id  $cvterm_name\n";

    my $stock = $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id });

   my $parent = $schema->resultset("Stock::Stock")->find( { uniquename => $parent_name } );



    if (!$stock) {
	$c->stash->{rest} = { error => "Stock with $stock_id is not found in the database!"};
	return;
    }
    if (!$parent) {
	$c->stash->{rest} = { error => "Stock with uniquename $parent_name was not found, Either this is not unique name or it is not in the database!"};
	return;     }

    my $new_row = $schema->resultset("Stock::StockRelationship")->new(
	{
	    subject_id => $parent->stock_id,
	    object_id  => $stock->stock_id,
	    type_id    => $type_id_row,
        value => $cross_type
	});

    eval {
	$new_row->insert();
    };

    if ($@) {
	$c->stash->{rest} = { error => "An error occurred: $@"};
    }
    else {
	$c->stash->{rest} = { error => '', };
    }
}



sub generate_genotype_matrix : Path('/phenome/genotype/matrix/generate') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $group = shift;

    my $file = $c->config->{genotype_dump_file} || "/tmp/genotype_dump_file";

    CXGN::Phenome::DumpGenotypes::dump_genotypes($c->dbc->dbh, $file);


    $c->stash->{rest}= [ 1];

}


=head2 add_phenotype


L<Catalyst::Action::REST> action.

Store a new phenotype and link with nd_experiment_stock

=cut


sub add_phenotype :PATH('/ajax/stock/add_phenotype') : ActionClass('REST') { }

sub add_phenotype_GET :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{rest} = { error => "Nothing here, it's a GET.." } ;
}

sub add_phenotype_POST {
    my ( $self, $c ) = @_;
    my $response;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    if (  any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
        my $req = $c->req;

        my $stock_id = $c->req->param('stock_id');
        my $project_id = $c->req->param('project_id');
        my $geolocation_id = $c->req->param('geolocation_id');
        my $observable_id = $c->req->param('observable_id');
        my $value = $c->req->param('value');
        my $date = DateTime->now;
        my $user =  $c->user->get_object->get_sp_person_id;
        try {
            # find the cvterm for a phenotyping experiment
            my $pheno_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,'phenotyping_experiment','experiment_type');


            #create the new phenotype
            my $phenotype = $schema->resultset("Phenotype::Phenotype")->find_or_create(
	        {
                    observable_id => $observable_id, #cvterm
                    value => $value ,
                    uniquename => "Stock: $stock_id, Observable id: $observable_id. Uploaded by web form by $user on $date" ,
                });
            #create a new nd_experiment
            my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create(
                {
                    nd_geolocation_id => $geolocation_id,
                    type_id => $pheno_cvterm->cvterm_id(),
                } );
            #link to the project
            $experiment->find_or_create_related('nd_experiment_projects', {
                project_id => $project_id,
                                                } );
            #link the experiment to the stock
            $experiment->find_or_create_related('nd_experiment_stocks' , {
                stock_id => $stock_id,
                type_id  =>  $pheno_cvterm->cvterm_id(),
                                                });
            #link the phenotype with the nd_experiment
            my $nd_experiment_phenotype = $experiment->find_or_create_related(
                'nd_experiment_phenotypes', {
                    phenotype_id => $phenotype->phenotype_id()
                } );

            $response = { message => "stock_id $stock_id and project_id $project_id associated with cvterm $observable_id , phenotype value $value (phenotype_id = " . $phenotype->phenotype_id . "\n" , }
        } catch {
            $response = { error => "Failed: $_" }
        };
    }  else {  $c->stash->{rest} = { error => 'user does not have a curator/sequencer/submitter account' };
    }
}

=head2 action stock_members_phenotypes()

 Usage:        /stock/<stock_id>/datatables/traits
 Desc:         get all the phenotypic scores associated with the stock $stock_id
 Ret:          json of the form
               { data => [  { db_name : 'A', observable: 'B', value : 'C' }, { ... }, ] }
 Args:
 Side Effects:
 Example:

=cut

sub stock_members_phenotypes :Chained('/stock/get_stock') PathPart('datatables/traits') Args(0) {
    my $self = shift;
    my $c = shift;
    #my $trait_id = shift;


    my $subject_phenotypes = $self->get_phenotypes($c);

    # collect the data from the hashref...
    #
    my @stock_data;

    foreach my $project (keys (%$subject_phenotypes)) {
	foreach my $trait (@{$subject_phenotypes->{$project}}) {
	    push @stock_data, [
		$project,
		$trait->get_column("db_name").":".$trait->get_column("accession"),
		$trait->get_column("observable"),
		$trait->get_column("value"),
	    ];
	}
    }

    $c->stash->{rest} = { data => \@stock_data,
                          #has_members_genotypes => $has_members_genotypes
    };

}

sub _stock_project_phenotypes {
    my ($self, $schema, $bcs_stock) = @_;

    return {} unless $bcs_stock;
    my $rs =  $schema->resultset("Stock::Stock")->stock_phenotypes_rs($bcs_stock);
    my %project_hashref;
    while ( my $r = $rs->next) {
	my $project_desc = $r->get_column('project_description');
	push @{ $project_hashref{ $project_desc }}, $r;
    }
    return \%project_hashref;
}

=head2 action get_stock_trials()

 Usage:        /stock/<stock_id>/datatables/trials
 Desc:         retrieves trials associated with the stock
 Ret:          a table in json suitable for datatables
 Args:
 Side Effects:
 Example:

=cut

sub get_stock_trials :Chained('/stock/get_stock') PathPart('datatables/trials') Args(0) {
    my $self = shift;
    my $c = shift;

    my @trials = $c->stash->{stock}->get_trials();

    my @formatted_trials;
    foreach my $t (@trials) {
	push @formatted_trials, [ '<a href="/breeders/trial/'.$t->[0].'">'.$t->[1].'</a>', $t->[3], '<a href="javascript:show_stock_trial_detail('.$c->stash->{stock}->get_stock_id().', \''.$c->stash->{stock}->get_name().'\' ,'.$t->[0].',\''.$t->[1].'\')">Details</a>' ];
    }
    $c->stash->{rest} = { data => \@formatted_trials };
}


=head2 action get_shared_trials()

 Usage:        /datatables/sharedtrials
 Desc:         retrieves trials associated with multiple stocks
 Ret:          a table in json suitable for datatables
 Args:         array of stock uniquenames
 Side Effects:
 Example:

=cut

sub get_shared_trials :Path('/stock/get_shared_trials') : ActionClass('REST'){

sub get_shared_trials_POST :Args(1) {
    my ($self, $c) = @_;
    $c->stash->{rest} = { error => "Nothing here, it's a POST.." } ;
}
sub get_shared_trials_GET :Args(1) {

    my $self = shift;
    my $c = shift;
    my @stock_ids = $c->request->param( 'stock_ids[]' );
    my $stock_string = join ",", map { "'$_'" } (@stock_ids);
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );

    my $criteria_list = [
               'accessions',
               'trials'
             ];

    my $dataref = {
               'trials' => {
                           'accessions' => $stock_string
                         }
                  };

    my $queryref = {
               'trials' => {
                           'accessions' => 1
                         }
                  };

    my $status = $bs->test_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass});
    if ($status->{'error'}) {
      $c->stash->{rest} = { error => $status->{'error'}};
      return;
    }
    my $trial_query = $bs->metadata_query($criteria_list, $dataref, $queryref);
    my @shared_trials = @{$trial_query->{results}};

    my @formatted_rows = ();

    foreach my $stock_id (@stock_ids) {
	     my $trials_string ='';
       my $stock = CXGN::Stock->new(schema => $schema, stock_id => $stock_id);
       my $uniquename = $stock->uniquename;
       $dataref = {
             'trials' => {
                         'accessions' => $stock_id
                       }
                };
        $trial_query = $bs->metadata_query($criteria_list, $dataref, $queryref);
        my @current_trials = @{$trial_query->{results}};
	      my $num_trials = scalar @current_trials;

	      foreach my $t (@current_trials) {
          print STDERR "t = " . Dumper($t);
          $trials_string = $trials_string . '<a href="/breeders/trial/'.$t->[0].'">'.$t->[1].'</a>,  ';
	      }
	      $trials_string =~ s/,\s+$//;
	      push @formatted_rows, ['<a href="/stock/'.$stock_id.'/view">'.$uniquename.'</a>', $num_trials, $trials_string ];
    }

    my $num_trials = scalar @shared_trials;
    if ($num_trials > 0) {
	    my $trials_string = '';
	    foreach my $t (@shared_trials) {
	       $trials_string = $trials_string . '<a href="/breeders/trial/'.$t->[0].'">'.$t->[1].'</a>,  ';
      }
	    $trials_string  =~ s/,\s+$//;
	    push @formatted_rows, [ "Trials in Common", $num_trials, $trials_string];
    } else {
      push @formatted_rows, [ "Trials in Common", $num_trials, "No shared trials found."];
    }

    $c->stash->{rest} = { data => \@formatted_rows, shared_trials => \@shared_trials };
  }
}

=head2 action get_stock_trait_list()

 Usage:        /stock/<stock_id>/datatables/traitlist
 Desc:         retrieves the list of traits assayed on the stock
 Ret:          json in a table format, suitable for datatables
 Args:
 Side Effects:
 Example:

=cut

sub get_stock_trait_list :Chained('/stock/get_stock') PathPart('datatables/traitlist') Args(0) {
    my $self = shift;
    my $c = shift;

    my @trait_list = $c->stash->{stock}->get_trait_list();

    my @formatted_list;
    foreach my $t (@trait_list) {
	print STDERR Dumper($t);
	push @formatted_list, [ '<a href="/cvterm/'.$t->[0].'/view">'.$t->[1].'</a>', $t->[2], sprintf("%3.1f", $t->[3]), sprintf("%3.1f", $t->[4]), sprintf("%.0f", $t->[5])];
    }
    print STDERR Dumper(\@formatted_list);

    $c->stash->{rest} = { data => \@formatted_list };
}

sub get_phenotypes_by_stock_and_trial :Chained('/stock/get_stock') PathPart('datatables/trial') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $stock_type = $c->stash->{stock}->get_type()->name();

    my $q;
    if ($stock_type eq 'accession'){
        $q = "SELECT stock.stock_id, stock.uniquename, cvterm_id, cvterm.name, avg(phenotype.value::REAL), stddev(phenotype.value::REAL), count(phenotype.value::REAL) FROM stock JOIN stock_relationship ON (stock.stock_id=stock_relationship.object_id) JOIN  nd_experiment_stock ON (nd_experiment_stock.stock_id=stock_relationship.subject_id) JOIN nd_experiment_project ON (nd_experiment_stock.nd_experiment_id=nd_experiment_project.nd_experiment_id) JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment_project.nd_experiment_id) JOIN phenotype USING(phenotype_id) JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id) WHERE project_id=? AND stock.stock_id=? GROUP BY stock.stock_id, stock.uniquename, cvterm_id, cvterm.name";
    } else {
        $q = "SELECT stock.stock_id, stock.uniquename, cvterm_id, cvterm.name, avg(phenotype.value::REAL), stddev(phenotype.value::REAL), count(phenotype.value::REAL) FROM stock JOIN nd_experiment_stock USING(stock_id) JOIN nd_experiment_project ON (nd_experiment_stock.nd_experiment_id=nd_experiment_project.nd_experiment_id) JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment_project.nd_experiment_id) JOIN phenotype USING(phenotype_id) JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id) WHERE project_id=? AND stock.stock_id=? GROUP BY stock.stock_id, stock.uniquename, cvterm_id, cvterm.name";
    }

    my $h = $c->dbc->dbh->prepare($q);
    $h->execute($trial_id, $c->stash->{stock}->get_stock_id());

    my @phenotypes;
    while (my ($stock_id, $stock_name, $cvterm_id, $cvterm_name, $avg, $stddev, $count) = $h->fetchrow_array()) {
	push @phenotypes, [ "<a href=\"/cvterm/$cvterm_id/view\">$cvterm_name</a>", sprintf("%.2f", $avg), sprintf("%.2f", $stddev), $count ];
    }
    $c->stash->{rest} = { data => \@phenotypes };
}

sub get_phenotypes {
    my $self = shift;
    my $c = shift;
    shift;
    my $trait_id = shift;

    my $stock_id = $c->stash->{stock_row}->stock_id();

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $bcs_stock_rs = $schema->resultset("Stock::Stock")->search( { stock_id => $stock_id });

    if (! $bcs_stock_rs) { die "The stock $stock_id does not exist in the database"; }

    my $bcs_stock = $bcs_stock_rs->first();


    # now we have rs of stock_relationship objects. We need to find
    # the phenotypes of their related subjects
    #
    my $subjects = $bcs_stock->search_related('stock_relationship_objects')
                             ->search_related('subject');
    my $subject_phenotypes = $self->_stock_project_phenotypes($schema, $subjects );

    return $subject_phenotypes;
}

sub get_pedigree_string :Chained('/stock/get_stock') PathPart('pedigree') Args(0) {
    my $self = shift;
    my $c = shift;
    my $level = $c->req->param("level");

    my $stock = CXGN::Stock->new(
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        stock_id => $c->stash->{stock}->get_stock_id()
    );
    my $parents = $stock->get_pedigree_string($level);
    print STDERR "Parents are: ".Dumper($parents)."\n";

    $c->stash->{rest} = { pedigree_string => $parents };
}


sub get_pedigree_string_ :Chained('/stock/get_stock') PathPart('pedigreestring') Args(0) {
    my $self = shift;
    my $c = shift;
    my $level = $c->req->param("level");
    my $stock_id = $c->stash->{stock}->get_stock_id();
    my $stock_name = $c->stash->{stock}->get_name();

    my $pedigree_string;

    my %pedigree = _get_pedigree_hash($c,[$stock_id]);

    if ($level eq "Parents") {
        my $mother = $pedigree{$stock_name}{'1'}{'mother'} || 'NA';
        my $father = $pedigree{$stock_name}{'1'}{'father'} || 'NA';
        $pedigree_string = "$mother/$father" ;
    }
    elsif ($level eq "Grandparents") {
        my $maternal_mother = $pedigree{$pedigree{$stock_name}{'1'}{'mother'}}{'2'}{'mother'} || 'NA';
        my $maternal_father = $pedigree{$pedigree{$stock_name}{'1'}{'mother'}}{'2'}{'father'} || 'NA';
        my $paternal_mother = $pedigree{$pedigree{$stock_name}{'1'}{'father'}}{'2'}{'mother'} || 'NA';
        my $paternal_father = $pedigree{$pedigree{$stock_name}{'1'}{'father'}}{'2'}{'father'} || 'NA';
        my $maternal_parent_string = "$maternal_mother/$maternal_father";
        my $paternal_parent_string = "$paternal_mother/$paternal_father";
        $pedigree_string =  "$maternal_parent_string//$paternal_parent_string";
    }
    elsif ($level eq "Great-Grandparents") {
        my $m_maternal_mother = $pedigree{$pedigree{$pedigree{$stock_name}{'1'}{'mother'}}{'2'}{'mother'}}{'3'}{'mother'} || 'NA';
        my $m_maternal_father = $pedigree{$pedigree{$pedigree{$stock_name}{'1'}{'mother'}}{'2'}{'father'}}{'3'}{'mother'} || 'NA';
        my $p_maternal_mother = $pedigree{$pedigree{$pedigree{$stock_name}{'1'}{'mother'}}{'2'}{'mother'}}{'3'}{'father'} || 'NA';
        my $p_maternal_father = $pedigree{$pedigree{$pedigree{$stock_name}{'1'}{'mother'}}{'2'}{'father'}}{'3'}{'father'} || 'NA';
        my $m_paternal_mother = $pedigree{$pedigree{$pedigree{$stock_name}{'1'}{'father'}}{'2'}{'mother'}}{'3'}{'mother'} || 'NA';
        my $m_paternal_father = $pedigree{$pedigree{$pedigree{$stock_name}{'1'}{'father'}}{'2'}{'father'}}{'3'}{'mother'} || 'NA';
        my $p_paternal_mother = $pedigree{$pedigree{$pedigree{$stock_name}{'1'}{'father'}}{'2'}{'mother'}}{'3'}{'father'} || 'NA';
        my $p_paternal_father = $pedigree{$pedigree{$pedigree{$stock_name}{'1'}{'father'}}{'2'}{'father'}}{'3'}{'father'} || 'NA';
        my $mm_parent_string = "$m_maternal_mother/$m_maternal_father";
        my $mf_parent_string = "$p_maternal_mother/$p_maternal_father";
        my $pm_parent_string = "$m_paternal_mother/$m_paternal_father";
        my $pf_parent_string = "$p_paternal_mother/$p_paternal_father";
        $pedigree_string =  "$mm_parent_string//$mf_parent_string///$pm_parent_string//$pf_parent_string";
    }
    $c->stash->{rest} = { pedigree_string => $pedigree_string };
}

sub _get_pedigree_hash {
    my ($c, $accession_ids, $format) = @_;

    my $placeholders = join ( ',', ('?') x @$accession_ids );
    my $query = "
        WITH RECURSIVE included_rows(child, child_id, mother, mother_id, father, father_id, type, depth, path, cycle) AS (
                SELECT c.uniquename AS child,
                c.stock_id AS child_id,
                m.uniquename AS mother,
                m.stock_id AS mother_id,
                f.uniquename AS father,
                f.stock_id AS father_id,
                m_rel.value AS type,
                1,
                ARRAY[c.stock_id],
                false
                FROM stock c
                LEFT JOIN stock_relationship m_rel ON(c.stock_id = m_rel.object_id and m_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'female_parent'))
                LEFT JOIN stock m ON(m_rel.subject_id = m.stock_id)
                LEFT JOIN stock_relationship f_rel ON(c.stock_id = f_rel.object_id and f_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'male_parent'))
                LEFT JOIN stock f ON(f_rel.subject_id = f.stock_id)
                WHERE c.stock_id IN ($placeholders)
                GROUP BY 1,2,3,4,5,6,7,8,9,10
            UNION
                SELECT c.uniquename AS child,
                c.stock_id AS child_id,
                m.uniquename AS mother,
                m.stock_id AS mother_id,
                f.uniquename AS father,
                f.stock_id AS father_id,
                m_rel.value AS type,
                included_rows.depth + 1,
                path || c.stock_id,
                c.stock_id = ANY(path)
                FROM included_rows, stock c
                LEFT JOIN stock_relationship m_rel ON(c.stock_id = m_rel.object_id and m_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'female_parent'))
                LEFT JOIN stock m ON(m_rel.subject_id = m.stock_id)
                LEFT JOIN stock_relationship f_rel ON(c.stock_id = f_rel.object_id and f_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'male_parent'))
                LEFT JOIN stock f ON(f_rel.subject_id = f.stock_id)
                WHERE c.stock_id IN (included_rows.mother_id, included_rows.father_id) AND NOT cycle
                GROUP BY 1,2,3,4,5,6,7,8,9,10
        )
        SELECT child, mother, father, type, depth
        FROM included_rows
        GROUP BY 1,2,3,4,5
        ORDER BY 5,1;";

    my $sth = $c->dbc->dbh->prepare($query);
    $sth->execute(@$accession_ids);

    my %pedigree;
    no warnings 'uninitialized';
    while (my ($name, $mother, $father, $cross_type, $depth) = $sth->fetchrow_array()) {
        $pedigree{$name}{$depth}{'mother'} = $mother;
        $pedigree{$name}{$depth}{'father'} = $father;
    }
    return %pedigree;
}

sub stock_lookup : Path('/stock_lookup/') Args(2) ActionClass('REST') { }

sub stock_lookup_POST {
    my $self = shift;
    my $c = shift;
    my $lookup_from_field = shift;
    my $lookup_field = shift;
    my $value_to_lookup = $c->req->param($lookup_from_field);

    #print STDERR $lookup_from_field;
    #print STDERR $lookup_field;
    #print STDERR $value_to_lookup;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $s = $schema->resultset("Stock::Stock")->find( { $lookup_from_field => $value_to_lookup } );
    my $value;
    if ($s && $lookup_field eq 'stock_id') {
        $value = $s->stock_id();
    }
    $c->stash->{rest} = { $lookup_from_field => $value_to_lookup, $lookup_field => $value };
}

sub get_trial_related_stock:Chained('/stock/get_stock') PathPart('datatables/trial_related_stock') Args(0){
    my $self = shift;
    my $c = shift;
    my $stock_id = $c->stash->{stock_row}->stock_id();

    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');

    my $trial_related_stock = CXGN::Stock::RelatedStocks->new({dbic_schema => $schema, stock_id =>$stock_id});
    my $result = $trial_related_stock->get_trial_related_stock();
    my @stocks;
    foreach my $r (@$result){
      my ($stock_id, $stock_name, $cvterm_name) = @$r;
      my $url;
      if ($cvterm_name eq 'seedlot'){
          $url = qq{<a href = "/breeders/seedlot/$stock_id">$stock_name</a>};
      } else {
          $url = qq{<a href = "/stock/$stock_id/view">$stock_name</a>};
      }
      push @stocks, [$url, $cvterm_name, $stock_name];
    }

    $c->stash->{rest}={data=>\@stocks};
}

sub get_progenies:Chained('/stock/get_stock') PathPart('datatables/progenies') Args(0){
    my $self = shift;
    my $c = shift;
    my $stock_id = $c->stash->{stock_row}->stock_id();

    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
    my $progenies = CXGN::Stock::RelatedStocks->new({dbic_schema => $schema, stock_id =>$stock_id});
    my $result = $progenies->get_progenies();
    my @stocks;
    foreach my $r (@$result){
      my ($cvterm_name, $stock_id, $stock_name) = @$r;
      push @stocks, [$cvterm_name, qq{<a href = "/stock/$stock_id/view">$stock_name</a>}, $stock_name];
    }

    $c->stash->{rest}={data=>\@stocks};
}

sub get_group_and_member:Chained('/stock/get_stock') PathPart('datatables/group_and_member') Args(0){
    my $self = shift;
    my $c = shift;
    my $stock_id = $c->stash->{stock_row}->stock_id();

    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');

    my $related_groups = CXGN::Stock::RelatedStocks->new({dbic_schema => $schema, stock_id =>$stock_id});
    my $result = $related_groups->get_group_and_member();
    my @group;

    foreach my $r (@$result){
        my ($stock_id, $stock_name, $cvterm_name) = @$r;
        if ($cvterm_name eq "cross"){
            push @group, [qq{<a href=\"/cross/$stock_id\">$stock_name</a>}, $cvterm_name, $stock_name];
        } else {
            push @group, [qq{<a href = "/stock/$stock_id/view">$stock_name</a>}, $cvterm_name, $stock_name];
        }
    }

    $c->stash->{rest}={data=>\@group};

}

sub get_stock_for_tissue:Chained('/stock/get_stock') PathPart('datatables/stock_for_tissue') Args(0){
    my $self = shift;
    my $c = shift;
    my $stock_id = $c->stash->{stock_row}->stock_id();

    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');

    my $tissue_stocks = CXGN::Stock::RelatedStocks->new({dbic_schema => $schema, stock_id =>$stock_id});
    my $result = $tissue_stocks->get_stock_for_tissue();
    my @stocks;
    foreach my $r (@$result){

      my ($stock_id, $stock_name, $cvterm_name) = @$r;

      push @stocks, [qq{<a href = "/stock/$stock_id/view">$stock_name</a>}, $cvterm_name, $stock_name];
    }

    $c->stash->{rest}={data=>\@stocks};

}

sub get_stock_datatables_genotype_data : Chained('/stock/get_stock') :PathPart('datatables/genotype_data') : ActionClass('REST') { }

sub get_stock_datatables_genotype_data_GET  {
    my $self = shift;
    my $c = shift;
    my $limit = $c->req->param('length') || 1000;
    my $offset = $c->req->param('start') || 0;
    my $stock_id = $c->stash->{stock_row}->stock_id();

    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $stock = CXGN::Stock->new({schema => $schema, stock_id => $stock_id});
    my $stock_type = $stock->type();

    my %genotype_search_params = (
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        cache_root=>$c->config->{cache_file_path},
        genotypeprop_hash_select=>[],
        protocolprop_top_key_select=>[],
        protocolprop_marker_hash_select=>[]
    );
    if ($stock_type eq 'accession') {
        $genotype_search_params{accession_list} = [$stock_id];
    } elsif ($stock_type eq 'tissue_sample') {
        $genotype_search_params{tissue_sample_list} = [$stock_id];
    }
    my $genotypes_search = CXGN::Genotype::Search->new(\%genotype_search_params);
    my $file_handle = $genotypes_search->get_cached_file_search_json($c->config->{cluster_shared_tempdir}, 1); #only gets metadata and not all genotype data!

    my @result;
    my $counter = 0;

    open my $fh, "<& :encoding(UTF-8)", $file_handle or die "Can't open output file: $!";
    my $header_line = <$fh>;
    if ($header_line) {
        my $marker_objects = decode_json $header_line;

        my $start_index = $offset;
        my $end_index = $offset + $limit;
        # print STDERR Dumper [$start_index, $end_index];

        while (my $gt_line = <$fh>) {
            if ($counter >= $start_index && $counter < $end_index) {
                my $g = decode_json $gt_line;

                push @result, [
                    '<a href = "/breeders_toolbox/trial/'.$g->{genotypingDataProjectDbId}.'">'.$g->{genotypingDataProjectName}.'</a>',
                    $g->{genotypingDataProjectDescription},
                    $g->{analysisMethod},
                    $g->{genotypeDescription},
                    '<a href="/stock/'.$stock_id.'/genotypes?genotype_id='.$g->{genotypeDbId}.'">Download</a>'
                ];
            }
            $counter++;
        }
    }

    my $draw = $c->req->param('draw');
    if ($draw){
        $draw =~ s/\D//g; # cast to int
    }

    $c->stash->{rest} = { data => \@result, draw => $draw, recordsTotal => $counter,  recordsFiltered => $counter };
}

=head2 make_stock_obsolete

L<Catalyst::Action::REST> action.

Makes a stock entry obsolete in the database

=cut

sub stock_obsolete : Path('/stock/obsolete') : ActionClass('REST') { }

sub stock_obsolete_GET {
    my ( $self, $c ) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    if (!$c->user()) {
        $c->stash->{rest} = { error => "Log in required for making stock obsolete." }; return;
    }

    if ( !any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
        $c->stash->{rest} = { error => 'user does not have a curator/sequencer/submitter account' };
        $c->detach();
    }

    my $stock_id = $c->req->param('stock_id');
    my $is_obsolete  = $c->req->param('is_obsolete');

	my $stock = $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id } );

    if ($stock) {

        try {
            my $stock = CXGN::Stock->new({
                schema=>$schema,
                stock_id=>$stock_id,
                is_saving=>1,
                sp_person_id => $c->user()->get_object()->get_sp_person_id(),
                user_name => $c->user()->get_object()->get_username(),
                modification_note => "Obsolete at ".localtime,
                is_obsolete => $is_obsolete
            });
            my $saved_stock_id = $stock->store();

            my $dbh = $c->dbc->dbh();
            my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
            my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

            $c->stash->{rest} = { message => "Stock obsoleted" };
        } catch {
            $c->stash->{rest} = { error => "Failed: $_" }
        };
    } else {
	    $c->stash->{rest} = { error => "Not a valid stock $stock_id " };
	}

    #$c->stash->{rest} = { message => 'success' };
}



1;
