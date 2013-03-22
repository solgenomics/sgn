
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
use Try::Tiny;
use CXGN::Phenome::Schema;
use CXGN::Phenome::Allele;
use CXGN::Chado::Stock;
use CXGN::Page::FormattingHelpers qw/ columnar_table_html info_table_html html_alternate_show /;
use CXGN::Phenome::DumpGenotypes;

use Scalar::Util qw(looks_like_number);

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
                my $cxgn_stock = CXGN::Chado::Stock->new($schema, $stock_id);
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
    my $sp_cvterms = $c->stash->{stock_cvterms}->{SP};
    my $po_cvterms = $c->stash->{stock_cvterms}->{PO} ;
    # should GO be here too?
    my $go_cvterms = $c->stash->{stock_cvterms}->{GO};
    my @stock_cvterms;
    push @stock_cvterms, @$sp_cvterms if $sp_cvterms;
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
        $db_accession = $cvterm_id if $db_name eq 'SP';
        my $url = $_->cvterm->dbxref->db->urlprefix . $_->cvterm->dbxref->db->url;
        my $cvterm_link =
            qq |<a href="/chado/cvterm.pl?cvterm_id=$cvterm_id" target="blank">$cvterm_name</a>|;
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
                     { 'evidence_description' => $evidence_description } , { cv_name =>'null', autocreate => 1 } ) if looks_like_number($evidence_description);
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
    my $q = "select distinct cvterm.name from stock join nd_experiment_stock using (stock_id) join nd_experiment_phenotype using (nd_experiment_id) join phenotype using (phenotype_id) join cvterm on cvterm_id = phenotype.observable_id WHERE cvterm.name ilike ?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute( '%'.$term.'%');
    while  (my ($term_name) = $sth->fetchrow_array ) {
        push @response_list, $term_name;
    }
    $c->{stash}->{rest} = \@response_list;
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

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @response_list;
    my $q = "select distinct(name) from stock where name ilike ?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($term.'%');
    while (my ($stock_name) = $sth->fetchrow_array) { 
	push @response_list, $stock_name;
    }

    print STDERR "stock_autocomplete RESPONSELIST = ".join ", ", @response_list;
    
    $c->{stash}->{rest} = \@response_list;
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
    if ($parent_type eq "male") { 
	$cvterm_name = "male_parent";
    }
    elsif ($parent_type eq "female") { 
	$cvterm_name = "female_parent";
    }
    
    my $type_id_row = $schema->resultset("Cv::Cvterm")->find( { name=> $cvterm_name } );

    # check if a parent of this parent_type is already associated with this stock
    #
    my $previous_parent = $schema->resultset("Stock::StockRelationship")->find( { type_id => $type_id_row->cvterm_id,
										  object_id => $stock_id });

    if ($previous_parent) {
	print STDERR "The stock ".$previous_parent->subject_id." is already associated with stock $stock_id - returning.\n";
	$c->stash->{rest} = { error => "A $parent_type parent with id ".$previous_parent->subject_id." is already associated with this stock. Please specify another parent." };
	return;
    }



    my $cvterm_id;
    if ($type_id_row) { 
	$cvterm_id = $type_id_row->cvterm_id;
    }

    print STDERR "PARENT_NAME = $parent_name STOCK_ID $stock_id  $cvterm_name\n";

    my $stock = $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id });
    my $parent = $schema->resultset("Stock::Stock")->find( { name => $parent_name } );

    if (!$stock) { $c->stash->{rest} = { error => "Stock with $stock_id is not found in the database!"}; return; }
    if (!$parent) { $c->stash->{rest} = { error => "Stock with name $parent_name is not in the database!"}; return; }
   

		  

    my $new_row = $schema->resultset("Stock::StockRelationship")->new( { subject_id => $parent->stock_id,
									object_id  => $stock->stock_id,
									type_id    => $cvterm_id,
								      });
    eval { 
	$new_row->insert();
    };

    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred: $@"};
    }

    $c->stash->{rest} = { error => '', };
									
}

sub generate_genotype_matrix : Path('/phenome/genotype/matrix/generate') :Args(1) { 
    my $self = shift;
    my $c = shift;
    my $group = shift;

    my $file = $c->config->{genotype_dump_file} || "/tmp/genotype_dump_file";
    
    CXGN::Phenome::DumpGenotypes::dump_genotypes($c->dbc->dbh, $file);


    $c->stash->{rest}= [ 1];


}



1;
