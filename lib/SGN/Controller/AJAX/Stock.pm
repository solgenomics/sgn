
=head1 NAME

SGN::Controller::AJAX::Stock - a REST controller class to provide the
backend for objects linked with stocks

=head1 DESCRIPTION

Add new stock properties, stock dbxrefs and so on.. 

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>
Naama Menda <nm249@cornell.edu>


=cut

package SGN::Controller::AJAX::Stock;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::Phenome::Schema;
use CXGN::Phenome::Allele;
use CXGN::Page::FormattingHelpers qw / columnar_table_html info_table_html /;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


=head2 add_stockprop


L<Catalyst::Action::REST> action.

Stores a new stockprop in the database

=cut

sub stockprop : Local : ActionClass('REST') { }

sub stockprop_POST {
    my ( $self, $c ) = @_;
    my $response;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    if (  any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
        my $req = $c->req;

        my $stock_id = $c->req->param('stock_id');
        my $propvalue  = $c->req->param('propvalue');
        my $type_id = $c->req->param('type_id');
        my ($existing_prop) = $schema->resultset("Stock::Stockprop")->search( {
            stock_id => $stock_id,
            type_id => $type_id,
            value => $propvalue, } );
        if ($existing_prop) { $response = { error=> 'type_id/propvalue '.$type_id." ".$propvalue." already associated" } ; 
        }else {

            my $prop_rs = $schema->resultset("Stock::Stockprop")->search( {
                stock_id => $stock_id,
                type_id => $type_id, } );
            my $rank = $prop_rs ? $prop_rs->get_column('rank')->max : -1 ;
            $rank++;

            try {
            $schema->resultset("Stock::Stockprop")->find_or_create( {
                stock_id => $stock_id,
                type_id => $type_id,
                value => $propvalue,
                rank => $rank, } );
            $response = { message => "stock_id $stock_id and type_id $type_id associated with value $propvalue", }
            } catch {
                $response = { error => "Failed: $_" }
            };
        }
    } else {  $c->stash->{rest} = { error => 'user does not have a curator/sequencer/submitter account' };
    }
}


sub stockprop_GET {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $stock_id = $c->req->param('stock_id');
    my $stock = $c->stash->{stock};
    my $type_id; ###
    my $prop_rs = $stock->stockprops(
        { type_id => $type_id, } );
    # print the prop name and value#
    $c->stash->{rest} =  ['sucess'];
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
    my $locus_input = $c->req->param('loci');
    
    my ($locus_data, $allele_symbol) = split (/ Allele: / ,$locus_input);
    my $is_default = $allele_symbol ? 'f' : 't' ;
    $locus_data =~ m/(.*)\s\((.*)\)/ ;
    my $locus_name = $1;
    my $locus_symbol = $2;

    my ($allele) = $c->dbic_schema('CXGN::Phenome::Schema')
        ->resultset('Locus')
        ->search({
            locus_symbol => $locus_symbol,
                 } )
        ->search_related('alleles' , {
            allele_symbol => $allele_symbol,
            is_default => $is_default} );
    if (!$allele) {
        $c->stash->{rest} = { error => "no allele found for locus '$locus_data' (allele: '$allele_symbol')" };
        return;
    }
    my $stock = $c->dbic_schema('Bio::Chado::Schema' , 'sgn_chado')
        ->resultset("Stock::Stock")->find({stock_id => $stock_id } ) ;
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
                $stock->create_stockprops(
                    { 'sgn allele_id' => $allele->allele_id },
                    { cv_name => 'local', allow_duplicate_values => 1, autocreate => 1 },
                    );
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

    my $stock = $c->stash->{stock};
    my $allele_ids = $c->stash->{stockprops}->{'sgn allele_id'};
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
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
    my $stock = $c->stash->{stock};
    my $sp_dbxrefs = $c->stash->{stock_dbxrefs}->{'SP'};
    my $po_dbxrefs = $c->stash->{stock_dbxrefs}->{'PO'};
    # should GO be here too?
    my $go_dbxrefs = $c->stash->{stock_dbxrefs}->{'GO'};
    my @stock_dbxrefs;
    push @stock_dbxrefs, @$sp_dbxrefs if $sp_dbxrefs;
    push @stock_dbxrefs, @$po_dbxrefs if $po_dbxrefs;
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
    # the ontology term is a stock_dbxref
    # the evidence details are in stock_dbxrefprop (relationship, evidence_code,
    # evidence_description, evidence_with, reference, obsolete )
    # and the metadata for sp_person_id, create_date, etc. 
    my @obs_annot;
    #keys= cvterms, values= hash of arrays
    #(keys= ontology details, values= list of evidences)
    my %ont_hash = () ;
    #some CVs to be used for the evidence codes
    my $cv_rs =  $schema->resultset("Cv::Cv");
    my ($rel_cv) = $cv_rs->search(name => 'relationship');
    my ($evidence_cv) = $cv_rs->search(name => 'evidence_code' );
    # go over the lists of Bio::Chado::Schema::General::Dbxref objects
    # and build the annotation details
    foreach (@stock_dbxrefs) {
        my $cv_name      = $_->dbxref->cvterm->cv->name;
        my $cvterm_id    = $_->dbxref->cvterm->cvterm_id;
        my $cvterm_name  = $_->dbxref->cvterm->name;
        my $db_name      = $_->dbxref->db->name;
        my $accession    = $_->dbxref->accession;
        my $db_accession = $accession;
        $db_accession = $cvterm_id if $db_name eq 'SP';
        my $url = $_->dbxref->db->urlprefix . $_->dbxref->db->url;
        my $cvterm_link =
            qq |<a href="/chado/cvterm.pl?cvterm_id=$cvterm_id" target="blank">$cvterm_name</a>|;
        # the stock_dbxrefprop objects have all the evidence and metadata for the annotation
        my $props = $_->stock_dbxrefprops;
        my ($relationship) = $props->search_related('type', { cv_id=>$rel_cv->cv_id} )->single; # should be 1 relationship per annotation
        my ($evidence_code) =  $props->search_related('type', { cv_id=>$evidence_cv->cv_id} )->single; # should be 1 evidence_code ?
        ############
        my $evidence_desc_name;
        my $rel_name = $relationship ? $relationship->name : undef;
        my $ev_name  = $evidence_code ? $evidence_code->name : undef;
        #if the dbxref has an obsolete property (must have a true value
        # since annotations can be obsolete and un-obsolete, it is possible
        # to have an obsolete property with value = 0, meaning the annotation
        # is not obsolete.
        # build the unobsolete link
        my ($obsolete_prop) = $props->search(
            {
                value => '1',
                'type.name' => 'obsolete',
            },
            { join =>  'type' } , );
        if ($obsolete_prop) {
            my $unobsolete = $privileged ? qq| <a href="/ajax/ontology/unobsolete_annotation($obsolete_prop)">[unobsolete]</a> | : undef;
            ### NEED TO MAKE AN AJAX REQUEST 
            # onclick: $obsolete_prop->update( {value => '0' } );
            
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
            my $obsolete_link = $privileged ? qq| <a href="/ajax/ontology/obsolete_annotation($_)">[delete]</a> | : undef ;
            my ($ev_with) = $props->search( {'type.name' => 'evidence_with'} , { join => 'type'  } );
            my $ev_with_dbxref = $ev_with ? $schema->resultset("General::Dbxref")->find( { dbxref_id=> $ev_with->value } ) : undef;
            my $ev_with_url = $ev_with_dbxref ?  $ev_with_dbxref->urlprefix . $ev_with_dbxref->url . $ev_with_dbxref->accession : undef;
            my $ev_with_acc = $ev_with_dbxref ? $ev_with_dbxref->accession : undef ;
            # the reference is a dbxref id in the prop table
            my ($reference) = $props->search( {'type.name' => 'reference'} , { join => 'type'  } );
            my $reference_dbxref = $reference ? $schema->resultset("General::Dbxref")->find( { dbxref_id=> $reference->value } ) : undef;
            my $reference_url = $reference_dbxref ? $reference_dbxref->urlprefix . $reference_dbxref->url . $reference_dbxref->accession : undef;
            my $reference_acc = $reference_dbxref ? $reference_dbxref->accession : undef;
            # the submitter is a sp_person_id prop
            my ($submitter) = $props->search( {'type.name' => 'sgn sp_person_id'} , { join => 'type' } );
            my $sp_person_id = $submitter ? $submitter->value : undef;
            my $submitter_info ;# : <a href'"solpeople/personal_info.pl?sp_person_id=$sp_person_id">$first_name $last_name </a>
            my ($date) = $props->search( {'type.name' => 'create_date'} , { join =>  'type'  } )->first || undef ; # $props->search( {'type.name' => 'modified_date'} , { join =>  'type' } ) ;
            my $evidence_date = $date ? $date->value : undef;

            # add an empty row if there is more than 1 evidence code
            my $ev_string;
            $ev_string .= "<hr />" if $ont_hash{$cv_name}{$ontology_details};
            no warnings 'uninitialized';
            $ev_string .=  $ev_name . "<br />";
            $ev_string .= $evidence_desc_name . "<br />" if $evidence_desc_name;
            $ev_string .= "<a href=\"$ev_with_url\">$ev_with_acc</a><br />" if $ev_with_acc;
            $ev_string .="<a href=\"$reference_url\">$reference_acc</a><br />" if $reference_acc;
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
    if ( @obs_annot &&  $privileged ) {
      ##NEED TO RE-WRITE print _obsoleted  $ontology_evidence .= print_obsoleted(@obs_annot);
    }
    $hashref->{html} = $ontology_evidence;
    $c->stash->{rest} = $hashref;
}

############
sub associate_ontology:Path('/ajax/stock/associate_ontology') :ActionClass('REST') {}

sub associate_ontology_POST :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{rest} = { error => "Nothing here, it's a POST.." } ;
}

sub associate_ontology_GET :Args(0) {
    my ( $self, $c ) = @_;
    my $stock_id = $c->req->param('object_id');
    my $ontology_input = $c->req->param('term_name');
    my $relationship = $c->req->param('relationship'); # a cvterm_id
    my $evidence_code = $c->req->param('evidence'); # a cvterm_id
    my $evidence_description = $c->req->param('evidence_desc'); # a cvterm_id 
    my $evidence_with = $c->req->param('evidence_with'); # a dbxref_id (type='evidence_with' value = 'dbxref_id'
    my $reference = $c->req->param('reference'); # a dbxref_id
    my $params = map { $_ => $c->req->param($_) } qw/
       stock_id ontology_input relationship evidence_code evidence_description
       evident_with reference
    /;
    #solanaceae_phenotype--SP:000001--fruit size
    my ($cv_name, $db_accession, $cvterm_name)  = split /--/ , $ontology_input;
    my ($db_name, $accession) = split ':' , $db_accession;

    my ($cvterm) = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado')
        ->resultset('General::Db')
        ->search({ 'me.name' => $db_name, } )->search_related('dbxrefs' , { accession => $accession } )
        ->search_related('cvterm')->first; # should be only 1 cvterm per dbxref
    if (!$cvterm) {
        $c->stash->{rest} = { error => "no ontology term found for term $db_name : $accession" };
        return;
    }
    my ($stock) = $c->stash->{stock} || $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado')->resultset("Stock::Stock")->find( { stock_id => $stock_id } );


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
                print STDERR "********trying to load stockdbxrefprops: \n $relationship =1\n $evidence_code = 1 , $evidence_description =1 , reference= $reference, evidence_with = $evidence_with \n\n";
                my $s_dbxref = $stock->find_or_create_related(
                    'stock_dbxrefs', { dbxref_id => $cvterm->dbxref_id, } );
                $s_dbxref->create_stock_dbxrefprops(
                    { $relationship => 1 , } , { db_name => 'OBO_REL', cv_name =>'relationship' } );
                $s_dbxref->create_stock_dbxrefprops(
                    { $evidence_code => 1 } , { db_name => 'ECO', cv_name =>'evidence_code' } );
                 $s_dbxref->create_stock_dbxrefprops(
                     { $evidence_description => 1 } , { db_name => 'ECO', cv_name =>'evidence_code' } ) if $evidence_description;
                $s_dbxref->create_stock_dbxrefprops(
                    { 'reference' => $reference , } , { cv_name =>'local' } );
                $s_dbxref->create_stock_dbxrefprops(
                    { 'evidence_with' => $evidence_with , } , { cv_name =>'local' , autocreate=>1} ) if $evidence_with;

                $c->stash->{rest} = ['success'];
                return;
            } catch {
                $c->stash->{rest} = { error => "Failed: $_" };
                return;
            };
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
        $response_hash->{$pub_id} = $accession . ": " . $title;
    }
    $c->stash->{rest} = $response_hash;
}
1;
