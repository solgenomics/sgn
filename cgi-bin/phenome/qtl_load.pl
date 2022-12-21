package CXGN::Phenome::QtlLoadDetailPage;
use CatalystX::GlobalContext qw( $c );

=head1 DESCRIPTION
processes and loads qtl data obtained from the the web forms 
(qtl_form.pl) on the user specific directory and the database.
  

=head1 AUTHOR
Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;
use warnings;

my $qtl_load_detail_page = CXGN::Phenome::QtlLoadDetailPage->new();

use File::Spec;
use CXGN::DB::Connection;
use CXGN::Phenome::Qtl;
use CXGN::Phenome::Qtl::Tools;
use CXGN::Phenome::Population;
use CXGN::Phenome::UserTrait;
use CXGN::Chado::Phenotype;
use CXGN::Chado::Cvterm;
use CXGN::Chado::Organism;
use CXGN::Phenome::Individual;
use CXGN::Accession;
use CXGN::Map;
use CXGN::Map::Version;
use CXGN::Map::Tools;
use CXGN::LinkageGroup;
use List::MoreUtils qw /uniq/;
use CXGN::Marker::Modifiable;
use CXGN::Marker::Tools;
use CXGN::Marker::Location;
use CXGN::Phenome::GenotypeExperiment;
use CXGN::Phenome::Genotype;
use CXGN::Phenome::GenotypeRegion;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People::Person;
use CXGN::Page;
use Bio::Chado::Schema;
use Storable qw /store retrieve/;
use CGI;

use CatalystX::GlobalContext qw( $c );

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    my $dbh          = CXGN::DB::Connection->new();
    my $login        = CXGN::Login->new($dbh);
    my $sp_person_id = $login->verify_session();

    $self->set_sp_person_id($sp_person_id);
    $self->set_dbh($dbh);

    if ($sp_person_id) {
        $self->process_data();
    }

    return $self;
}

sub process_data {
    my $self = shift;
    my $page = CXGN::Page->new( "SGN", "isaak" );
    my $dbh  = $self->get_dbh();

    my $login          = CXGN::Login->new($dbh);
    my $sp_person_id   = $login->verify_session();
    my $referring_page = '/qtl/form';
  
    my %args = $page->get_all_encoded_arguments();
    $args{pop_common_name_id} = $self->common_name_id();

    my $type     = $args{type};
    my $pop_id   = $args{pop_id};
    my $args_ref = \%args;

    my $qtl_obj = CXGN::Phenome::Qtl->new( $sp_person_id, $args_ref );
    $qtl_obj->create_user_qtl_dir($c);
    my $qtl_tools = CXGN::Phenome::Qtl::Tools->new();

    if ($pop_id) {
        $self->set_population_id($pop_id);
        $qtl_obj->set_population_id($pop_id);
    }

    my ( $pop_name, $desc, $pop_detail, $message );

    if ( $type eq 'begin' ) 
    {
        $self->show_pop_form();
    }

    elsif ( $type eq 'pop_form' ) 
    {
        $self->post_pop_form($qtl_obj, $qtl_tools);
    }

    elsif ( $type eq 'trait_form' ) 
    {
        $self->post_trait_form($qtl_obj, $args{'trait_file'}, $pop_id);

    }

    elsif ( $type eq 'pheno_form' ) 
    {
        $self->post_pheno_form($qtl_obj, $args{'pheno_file'}, $pop_id);
    }

    elsif ( $type eq 'geno_form' ) 
    {
        $self->post_geno_form($qtl_obj, $args{'geno_file'}, $pop_id);  
    }

    elsif ( $type eq 'stat_form' ) 
    {
        $self->post_stat_form($args_ref);
    }
}

sub pheno_upload {
    my $self   = shift;
    my $qtl    = shift;
    my $p_file = shift;

    my $safe_char = "a-zA-Z0-9_.-";
    my ( $temp_pheno_file, $name );

    $p_file =~ tr/ /_/;
    $p_file =~ s/[^$safe_char]//g;

    if ( $p_file =~ /^([$safe_char]+)$/ ) {

        $p_file = $1;

    }
    else {
        die "Phenotype file name contains invalid characters";
    }

    my $phe_upload = $c->req->upload('pheno_file');

    if ( defined $phe_upload ) {
        $name = $phe_upload->filename;

        my ( $qtl_dir, $user_dir ) = $qtl->get_user_qtl_dir($c);
        my $qtlfiles = retrieve("$user_dir/qtlfiles");

        my $trait_file = $qtlfiles->{trait_file};
        $self->compare_file_names( $name, $trait_file );
        $qtlfiles->{pheno_file} = $name;
        store $qtlfiles, "$user_dir/qtlfiles";

    }
    else {
	die "Catalyst::Request::Upload object for phenotype file not defined.";

    }

    if ( $p_file eq $name ) {
        $temp_pheno_file = $qtl->apache_upload_file( $phe_upload, $c );
        return $temp_pheno_file;

    }
    else { return 0; }

}

sub geno_upload {
    my $self   = shift;
    my $qtl    = shift;
    my $g_file = shift;

    my ( $temp_geno_file, $name );

    my $safe_char = "a-zA-Z0-9_.-";

    $g_file =~ tr/ /_/;
    $g_file =~ s/[^$safe_char]//g;

    if ( $g_file =~ /^([$safe_char]+)$/ ) {

        $g_file = $1;

    }
    else {
        die "Genotype file name contains invalid characters";
    }
  
    my $gen_upload = $c->req->upload('geno_file');

    if ( defined $gen_upload ) {
        $name = $gen_upload->filename;

        my ( $qtl_dir, $user_dir ) = $qtl->get_user_qtl_dir($c);
        my $qtlfiles = retrieve("$user_dir/qtlfiles");

        my $trait_file = $qtlfiles->{trait_file};
        my $pheno_file = $qtlfiles->{pheno_file};

        $self->compare_file_names( $name, $trait_file );
        $self->compare_file_names( $name, $pheno_file );

        $qtlfiles->{geno_file} = $name;
        store $qtlfiles, "$user_dir/qtlfiles";

    }
    else {
        die "Catalyst::Request::Upload object for genotype file not defined.";

    }

    if ( $g_file eq $name ) {
        $temp_geno_file = $qtl->apache_upload_file( $gen_upload, $c );
        return $temp_geno_file;
    }
    else { return 0; }
}

sub trait_upload {
    my $self   = shift;
    my $qtl    = shift;
    my $c_file = shift;

    my ( $temp_trait_file, $name );

    print STDERR "Trait file: $c_file\n";
    my $safe_char = "a-zA-Z0-9_.-";

    $c_file =~ tr/ /_/;
    $c_file =~ s/[^$safe_char]//g;

    if ( $c_file =~ /^([$safe_char]+)$/ ) {

        $c_file = $1;

    }
    else {
        die "Trait file name contains invalid characters";
    }
  
    my $trait_upload = $c->req->upload('trait_file');
 
    if ( defined $trait_upload ) 
    {
        $name = $trait_upload->filename;
        my ( $qtl_dir, $user_dir ) = $qtl->get_user_qtl_dir($c);
        my $qtlfiles = {};
        $qtlfiles->{trait_file} = $name;
        store( $qtlfiles, "$user_dir/qtlfiles" );

    }
    else 
    {
        die "Catalyst::Request::Upload object for trait file not defined.";

    }
  
    if ( $c_file eq $name ) 
    {
        $temp_trait_file = $qtl->apache_upload_file( $trait_upload, $c );
        return $temp_trait_file;
    }
    else { return 0; }
}

sub load_pop_details {
    my $self        = shift;
    my $pop_args    = shift;
    my %pop_details = %{$pop_args};

    my $org            = $pop_details{organism};
    my $name           = $pop_details{pop_name};  
    my $desc           = $pop_details{pop_desc};
    my $cross_id       = $pop_details{pop_type};
    my $female         = $pop_details{pop_female_parent};
    my $male           = $pop_details{pop_male_parent};
    my $recurrent      = $pop_details{pop_recurrent_parent};
    my $donor          = $pop_details{pop_donor_parent};
    my $comment        = $pop_details{pop_comment};
    my $is_public      = $pop_details{pop_is_public};
    my $common_name_id = $pop_details{pop_common_name_id};

    my $dbh          = $self->get_dbh();
    my $login        = CXGN::Login->new($dbh);
    my $sp_person_id = $login->verify_session();

    my ( $female_id, $male_id, $recurrent_id, $donor_id );
    
    $name  =~ s/^\s+|\s+$//g;
    my $population = CXGN::Phenome::Population->new_with_name( $dbh, $name );
    my $population_id = $population->get_population_id();
    if ($population_id) {
        $self->population_exists( $population, $name );
    }

    print STDERR "storing parental accessions...\n";

    if ($female) {
        $female_id = $self->store_accession($female);
        print STDERR "female: $female_id\n";
    }

    if ($male) {
        $male_id = $self->store_accession($male);
        print STDERR "male: $male_id\n";
    }

    if ($recurrent) {
        $recurrent_id = $self->store_accession($recurrent);

    }
    if ($donor) {
        $donor_id = $self->store_accession($donor);
    }

 print STDERR "storing population details....\n";
    my $pop = CXGN::Phenome::Population->new($dbh);
    $pop->set_name($name);
    $pop->set_description($desc);
    $pop->set_sp_person_id($sp_person_id);
    $pop->set_cross_type_id($cross_id);
    $pop->set_female_parent_id($female_id);
    $pop->set_male_parent_id($male_id);
    $pop->set_recurrent_parent_id($recurrent_id);
    $pop->set_donor_parent_id($donor_id);
    $pop->set_comment($comment);
    $pop->set_web_uploaded('t');
    $pop->set_common_name_id($common_name_id);
    $pop->store();
 print STDERR "Done storing population details....\n";

    # my $pop_id = $dbh->last_insert_id("population");
    my $population = CXGN::Phenome::Population->new_with_name( $dbh, $name );
    my $pop_id = $population->get_population_id();
print STDERR "Done storing population details....pop id: $pop_id\n";

    $pop = CXGN::Phenome::Population->new( $dbh, $pop_id );
    $pop->store_data_privacy($is_public);

    return $pop_id, $name, $desc;
}

sub store_accession {
    my $self      = shift;
    my $accession = shift;
    my $dbh       = $self->get_dbh();

    print STDERR "organism_id: $accession\n";
    my ( $species, $cultivar ) = split( /cv|var|cv\.|var\./, $accession );
    $species  =~ s/^\s+|\s+$//g;
    $cultivar =~ s/\.//;
    $cultivar =~ s/^\s+|\s+$//g;
    $species = ucfirst($species);

    print STDERR "$accession: species:$species, cultivar:$cultivar\n";
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $organism = CXGN::Chado::Organism->new_with_species( $schema, $species );
    $self->check_organism( $organism, $species, $cultivar );

    my $existing_organism_id = $organism->get_organism_id();
    my $organism_name        = $organism->get_species();

    eval {
        my $sth = $dbh->prepare(
            "SELECT accession_id, chado_organism_id, common_name 
                                    FROM accession 
                                    WHERE common_name ILIKE ?"
        );
        $sth->execute($cultivar);
        my ( $accession_id, $chado_organism_id, $common_name ) =
          $sth->fetchrow_array();
        print STDERR
"select existing accession: $accession_id, $chado_organism_id, $common_name\n";

        if ($accession_id) {
            unless ($chado_organism_id) {
                $sth = $dbh->prepare(
                    "UPDATE sgn.accession 
                                             SET chado_organism_id = ? 
                                             WHERE accession_id = $accession_id"
                );
                $sth->execute($existing_organism_id);
            }
        }
        elsif ( !$accession_id ) {

            $sth = $dbh->prepare(
                "INSERT INTO sgn.accession 
                                             (common_name, chado_organism_id) 
                                             VALUES (?,?)"
            );
            $sth->execute( $cultivar, $existing_organism_id );
            $accession_id = $dbh->last_insert_id( "accession", "sgn" );

            #my $accession = CXGN::Accession->new($dbh, $accession_id);
            #$common_name = $accession->accession_common_name();
            print STDERR
              "inserted: $accession_id, $chado_organism_id, $common_name\n";
        }

        my ( $accession_names_id, $accession_name );

        unless ( !$common_name ) {
            $sth = $dbh->prepare(
                "SELECT accession_name_id, accession_name
                                    FROM sgn.accession_names 
                                    WHERE accession_name ILIKE ?"
            );
            $sth->execute($common_name);

            ( $accession_names_id, $accession_name ) = $sth->fetchrow_array();
            print STDERR
"selected existing accession_names: $accession_names_id, $accession_name\n";
        }
        unless ($accession_names_id) {
            $sth = $dbh->prepare(
                "INSERT INTO sgn.accession_names 
                                              (accession_name, accession_id) 
                                               VALUES (?, ?)"
            );
            $sth->execute( $common_name, $accession_id );

            $accession_names_id =
              $dbh->last_insert_id( "accession_names", "sgn" );
            print STDERR
              "inserted accession_names : $common_name, $accession_id\n";

        }

        unless ( !$accession_names_id ) {
            $sth = $dbh->prepare(
                "UPDATE sgn.accession 
                                             SET accession_name_id = ? 
                                             WHERE accession_id = ?"
            );
            $sth->execute( $accession_names_id, $accession_id );
            print STDERR "updated accession: with $accession_names_id\n";
        }

        if (@_) {
            print STDERR "@_\n";
            $dbh->rollback();
            return 0;
        }
        else {
            $dbh->commit();
            return $accession_id;
        }
    };

}

=head2 store_traits

 Usage: my ($true_or_false) = $self->store_traits($file);
 Desc: reads traits, their definition, and unit from 
       user submitted tab-delimited traits file and stores traits 
       that does not exist in the db or exist but with different units
 Ret: true or false
 Args: tab delimited trait file, with full path
 Side Effects: accesses database
 Example:

=cut

sub store_traits {
    my $self         = shift;
    my $file         = shift;
    my $pop_id       = $self->get_population_id();
    my $sp_person_id = $self->get_sp_person_id();
    my $dbh          = $self->get_dbh();

    open( F, "<$file" ) || die "Can't open file $file.";

    my $header = <F>;
    chomp($header);
    my @fields = split /\t/, $header;    
    @fields = map { lc( $_ ) } @fields;
   		   
    my ( $trait, $trait_id, $trait_name, $unit, $unit_id );

    if (   $fields[0] !~ /trait|name/
	   || $fields[1] !~ /definition/
	   || $fields[2] !~ /unit/ 
	)
    {
        my $error =
          "Data columns in the traits file need to be in the order of: 
                    <b>traits -> definition -> unit</b>. <br/>
                    Now they are in the order of <b><i>$fields[0] -> $fields[1] 
                    -> $fields[2]</i></b>.\n";

        $self->trait_columns($error);
    }
    else {

        eval {
            while (<F>)
            {
                chomp;
                my (@values) = split /\t/;
		print STDERR "\n store traits: $values[0] -- $values[1] ..\n";
                $trait =
                  CXGN::Phenome::UserTrait->new_with_name( $dbh, $values[0] );

                if ( !$trait ) {
                    $trait = CXGN::Phenome::UserTrait->new($dbh);

                    $trait->set_cv_id(17);#16 for cassavabase
                    $trait->set_name( $values[0] );
                    $trait->set_definition( $values[1] );
                    $trait->set_sp_person_id($sp_person_id);
                    $trait_id = $trait->store();

                    $trait = CXGN::Phenome::UserTrait->new( $dbh, $trait_id );
                    $trait_id = $trait->get_user_trait_id();

                    unless ( !$values[2] ) {
                        $unit_id = $trait->get_unit_id( $values[2] );
                        if ( !$unit_id ) {
                            $unit_id = $trait->insert_unit( $values[2] );
                        }

                    }
                    if ( ($trait_id) && ($pop_id) && ($unit_id) ) {
                        $trait->insert_user_trait_unit( $trait_id, $unit_id,
                            $pop_id );

                    }

                }
                else {

                    unless ( !$values[2] ) {
                        $trait_id = $trait->get_user_trait_id();
                        $unit_id  = $trait->get_unit_id( $values[2] );
                        if ( !$unit_id ) {
                            $unit_id = $trait->insert_unit( $values[2] );

                        }
                        if ( ($trait_id) && ($pop_id) && ($unit_id) ) {
                            $trait->insert_user_trait_unit( $trait_id, $unit_id,
                                $pop_id );
                        }

                    }

                }

            }

        };
        if ($@) {          
            print STDERR "An error occurred storing traits: $@\n";
            $dbh->rollback();
            return 0;
        }
        else {
            print STDERR "Committing...traits\n";
            return 1;
        }
    }
}

=head2 store_individual

 Usage: $individual_id = $self->store_individual($dbh, $name, $pop_id, $sp_person_id);
 Desc: stores individual genotypes is they don't 
       exist in the same pop in the db
 Ret: individual id
 Args: db handle, individual name, population id sp_person_id 
 Side Effects: accesses database
 Example:

=cut

sub store_individual {
    my $self           = shift;
    my $ind_name       = shift;
    my $pop_id         = $self->get_population_id();
    my $sp_person_id   = $self->get_sp_person_id();
    my $dbh            = $self->get_dbh();
    my $common_name_id = $self->common_name_id();

    my ( $individual, $individual_id, $individual_name );
    my @individuals =
      CXGN::Phenome::Individual->new_with_name( $dbh, $ind_name, $pop_id );

    eval {
        if ( scalar(@individuals) == 0 )
        {
            $individual = CXGN::Phenome::Individual->new($dbh);
            $individual->set_name($ind_name);
            $individual->set_population_id($pop_id);
            $individual->set_sp_person_id($sp_person_id);
            $individual->set_common_name_id($common_name_id);
            $individual_id = $individual->store();

            $individual_name = $individual->get_name();
        }

        elsif ( scalar(@individuals) == 1 ) {

            print STDERR "There is a genotype with name $ind_name 
                          in the same population ($pop_id). \n";
            die "There might be a phenotype data for the same trait 
                 for the same genotype $ind_name. I can't store 
                 duplicate phenotype data. So I am quitting..\n";
        }
        elsif ( scalar(@individuals) > 0 ) {
            die "There are two genotypes with the same name ($ind_name)
              in the population: $pop_id.\n";
        }
    };
    if ($@) {
        $dbh->rollback();
        print STDERR "An error occurred storing individuals: $@\n";
        return 0;

    }
    else {
        $dbh->commit();
        print STDERR "STORED individual $individual_name.\n";
        return $individual;
    }
}

=head2 store_trait_values

 Usage: my ($true_or_false) = &store_trait_values($dbh, $file, $pop_id, $sp_person_id);
 Desc: stores phenotype values for traits evaluated for individuals of a population.
 Ret: true or false
 Args: db handle, tab delimited phenotype file with full path, population id, sp_person_id
 Side Effects: accesses database
 Example:

=cut

sub store_trait_values {
    my $self         = shift;
    my $file         = shift;
    my $pop_id       = $self->get_population_id();
    my $sp_person_id = $self->get_sp_person_id();
    my $dbh          = $c->dbc->dbh;
    open( F, "<$file" ) || die "Can't open file $file.";

    my $header = <F>;
    chomp($header);
    my @fields = split /\t/, $header;
    print STDERR "\n store phenotype values pop id-- $pop_id : header: $header .. \n";
    my @trait = ();
    my ( $trait_name, $trait_id );

    for ( my $i = 1 ; $i < @fields ; $i++ ) 
    {
	my $field_name =  $fields[$i];
	print STDERR "\n store phenotype values: field $i: ..$fields[$i].. ..$field_name.. \n";
	$field_name =~ s/^\s+|\s+$//g;
	print STDERR "\n store phenotype values: field $i: ..$fields[$i].. ..$field_name.. \n";

        $trait[$i] = CXGN::Phenome::UserTrait->new_with_name($dbh, $field_name);
	print STDERR "\n store phenotype values: get_name --$fields[$i]-- \n";

	$trait_name = $trait[$i]->get_name();
        $trait_id   = $trait[$i]->get_user_trait_id();
	print STDERR "\n store phenotype values: GOT trait_name -- $trait_name -- trait id -- $trait_id .. \n";
    }
    eval {
        while (<F>)
        {
            chomp;
            my (@values) = split /\t/;
	    $values[0] =~ s/^\s+|\s+$//g;
	    print STDERR "\n store individual: $values[0]\n";
            my $individual = $self->store_individual( $values[0] );

            die "The genotype does not exist in the database. 
             Therefore, it can not store the associated 
             phenotype data\n"
              unless ($individual);

            my $individual_id   = $individual->get_individual_id();
            my $individual_name = $individual->get_name();

            for ( my $i = 1 ; $i < @values ; $i++ ) {
                my $phenotype = CXGN::Chado::Phenotype->new($dbh);
                $phenotype->set_unique_name(
                    qq | $individual_name $pop_id .":". $i |);

                $phenotype->set_observable_id( $trait[$i]->get_user_trait_id() );
                
		if ($values[$i] != 0 && !$values[$i]) {$values[$i] = undef;}
                if ($values[$i] && $values[$i] =~ /NA|-|^\s+$|^\.+$/ig) 
                {
                    $values[$i] = undef;
                }
		      
		$values[$i] =~ s/^\s+|\s+$//g;
		my $tr_name = $trait[$i]->get_name();
		print STDERR "\nstore phenotype values: $individual_name -- $tr_name  -- count: $i -- $values[$i] \n";
                $phenotype->set_value($values[$i]);
                $phenotype->set_individual_id($individual_id);
                $phenotype->set_sp_person_id($sp_person_id);
                my $phenotype_id = $phenotype->store();

                $trait[$i]->insert_phenotype_user_trait_ids(
                    $trait[$i]->get_user_trait_id(),
                    $phenotype_id );

            }
        }
    };

    if ($@) {
        $dbh->rollback();
        print STDERR "An error occurred storing trait values: $@\n";
        return 0;

    }
    else {
        print STDERR "Committing...trait values to tables public.phenotype 
                  and user_trait_id and phenotype_id to phenotype_user_trait\n";
        return 1;

    }

}

=head2 store_map

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub store_map {
    my $self = shift;
    my $file = shift;

    my $dbh    = $self->get_dbh();
    my $pop_id = $self->get_population_id();

    my $pop      = CXGN::Phenome::Population->new( $dbh, $pop_id );
    my $pop_name = $pop->get_name();
    my $parent_m = $pop->get_male_parent_id();
    my $parent_f = $pop->get_female_parent_id();
    my $desc     = $pop->get_description();

    my $acc            = CXGN::Accession->new( $dbh, $parent_f );
    my $female_name    = $acc->accession_common_name();
    my $chado_org_id_f = $acc->chado_organism_id();

    $acc = CXGN::Accession->new( $dbh, $parent_m );
    my $male_name      = $acc->accession_common_name();
    my $chado_org_id_m = $acc->chado_organism_id();

    my $existing_map_id = CXGN::Map::Tools::population_map( $dbh, $pop_id );

    my ( $map, $map_id, $map_version_id );
    if ($existing_map_id) {
        $map_version_id =
          CXGN::Map::Version->map_version( $dbh, $existing_map_id );
        $map = CXGN::Map->new( $dbh, { map_id => $existing_map_id } );

    }
    else {
        $map = CXGN::Map->new_map( $dbh, $pop_name );
        $map_version_id = $map->{map_version_id};
    }
    $map_id = $map->{map_id};

    my $species_m = $self->species($chado_org_id_m);
    my $species_f = $self->species($chado_org_id_f);
    
    my $long_name =
        $species_f . ' cv. '
      . $female_name . ' x '
      . $species_m . ' cv. '
      . $male_name;
    print STDERR "map long name: $long_name\n";
    $map->{long_name}     = $long_name;
    $map->{map_type}      = 'genetic';
    $map->{parent_1}      = $parent_f;
    $map->{parent_2}      = $parent_m;
    $map->{abstract}      = $desc;
    $map->{population_id} = $pop_id;
    $map_id               = $map->store();

    my $lg_result;
    if ($map_version_id) {
        $lg_result = $self->store_lg( $map_version_id, $file );

        if ($lg_result) {
            print STDERR " STORED LINKAGE GROUPS\n";
        }
        else {
            print STDERR "FAILED STORING LINKAGE GROUPS\n";
        }
    }

    if ( $map_id && $map_version_id && $lg_result ) {
        return $map_id, $map_version_id;
    }
    else {
        print STDERR "Either map or map_version or 
                     linkage_groups storing did not work\n";
        return 0;
    }

}

=head2 species

 Usage: my $species = $self->species($org_id)
 Desc: when given the chado.organism_id, it returns the 
       genus and species name (in abbreviated format) 
 Ret: abbreviated species name
 Args: chado organism id
 Side Effects: access db
 Example:

=cut

sub species {
    my $self   = shift;
    my $org_id = shift;
    my $dbh    = $self->get_dbh();

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $org = CXGN::Chado::Organism->new( $schema, $org_id );

    return my $species = $org->get_abbreviation();

}

=head2 store_lg

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub store_lg {
    my $self = shift;
    my ( $map_version_id, $file ) = @_;
    my $dbh = $self->get_dbh();

    open F, "<$file" or die "can't open $file\n";
    my $markers = <F>;
    my $chr     = <F>;
    chomp($chr);
    close F;
    print STDERR "\n chr: $chr \n";
    my @all_chrs = split "\t", $chr;
    my $num = scalar(@all_chrs);
    print STDERR "\n all chr num: $num\n";

    @all_chrs = uniq @all_chrs;
    $num = scalar(@all_chrs);
    print STDERR "\n unique chr numbers: $num\n";
    foreach my $ch (@all_chrs) { print STDERR "\n chr -- $ch \n ";}
   my @chrs = grep {$_ =~ /\d+/} @all_chrs;
    @chrs = uniq(@chrs);
    $num = scalar(@chrs);
    print STDERR "\n clean chr numbers: $num\n";     
my @cleaned_chrs; 

    foreach my $ch (@chrs) { print STDERR "\n cleaned chr -- $ch \n "; $ch =~ s/\s+//g; push @cleaned_chrs, $ch;}
    @chrs = @cleaned_chrs;
    @chrs = uniq(@chrs);
    $num = scalar(@chrs);
    print STDERR "\n clean chr numbers: $num\n";
    foreach my $ch (@chrs) { print STDERR "\n final cleaned chr -- $ch \n ";}


   
   
   
   
   

   # die "The first cell of 2nd row must be empty." unless !$chrs[0];
   # shift(@chrs);

    my $lg = CXGN::LinkageGroup->new( $dbh, $map_version_id, \@chrs );
    my $result = $lg->store();

    if ($result) {
        print STDERR "Succeeded storing linkage groups
                      on map_version_id $map_version_id\n";
    }
    else {
        print STDERR "Failed storing linkage groups
                      on map_version_id $map_version_id\n";
    }

}

=head2 store_markers

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub store_marker_and_position {
    my $self = shift;
    my ( $file, $map_version_id ) = @_;
    my $dbh = $self->get_dbh();
    open F, "<$file" or die "can't open $file\n";

    my $markers   = <F>;
    my $chrs      = <F>;
    my $positions = <F>;
    chomp( $markers, $chrs, $positions );
    close F;

    my @markers = split /\t/, $markers;
    shift(@markers);

    my @positions = split /\t/, $positions;
    shift(@positions);

    my @chromosomes = split /\t/, $chrs;
    shift(@chromosomes);

    eval {
        for ( my $i = 0 ; $i < @markers ; $i++ )
        {
            print STDERR "\nstore marker and position: $markers[$i] --  $positions[$i] \n";
	    $markers[$i] =~ s/^\s+|\s+$//g;
	    
            my ( $marker_name, $subs ) =
              CXGN::Marker::Tools::clean_marker_name( $markers[$i] );

            my @marker_ids =
              CXGN::Marker::Tools::marker_name_to_ids( $dbh, $marker_name );
            if ( @marker_ids > 1 ) {
                die "Too many IDs found for marker '$marker_name'";
            }
            my ($marker_id) = @marker_ids;

            my $marker_obj;
            if ($marker_id) {
                $marker_obj = CXGN::Marker::Modifiable->new( $dbh, $marker_id );
            }
            else {
                $marker_obj = CXGN::Marker::Modifiable->new($dbh);
                $marker_obj->set_marker_name($marker_name);
                my $inserts = $marker_obj->store_new_data();

                if ( $inserts and @{$inserts} ) {
                }
                else {
                    die "Oops, I thought I was inserting some new data";
                }
                $marker_id = $marker_obj->marker_id();
            }
	    
	    $positions[$i] =~ s/^\s+|\s+$//g;
	    $chromosomes[$i] =~ s/^\s+|\s+$//g;
	    print STDERR "\nstore marker and position: $markers[$i] --$chromosomes[$i] -- $positions[$i] \n";

            my $loc      = $marker_obj->new_location();
            my $pos      = $positions[$i];
            my $conf     = 'uncalculated';
            my $protocol = 'unknown';
            $loc->marker_id($marker_id);

            $loc->map_version_id($map_version_id);
            $loc->lg_name( $chromosomes[$i] );
            $loc->position($pos);
            $loc->confidence($conf);
            $loc->subscript($subs);

            $marker_obj->add_experiment(
                { location => $loc, protocol => $protocol } );
            my $inserts = $marker_obj->store_new_data();

            if ( $inserts and @{$inserts} ) {

            }

            else {
                die "Oops, I thought I was inserting some new data";
            }
        }

    };
    if ($@) {
        print STDERR $@;
        print STDERR
          "Failed loading markers and their positions; rolling back.\n";
        $dbh->rollback();
        return 0;
    }
    else {
        print STDERR "Succeeded. loading markers and their position\n";

        $dbh->commit();
        return 1;
    }

}

=head2 store_genotype

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub store_genotype {
    my $self = shift;
    my ( $file, $map_version_id ) = @_;
    my $dbh    = $self->get_dbh();
    my $pop_id = $self->get_population_id();

    open F, "<$file" or die "can't open $file\n";

    my $markers   = <F>;
    my $chrs      = <F>;
    my $positions = <F>;
    chomp( $markers, $chrs, $positions );

    my @markers = split /\t/, $markers;
    shift(@markers);

    my @chrs = split /\t/, $chrs;
    shift(@chrs);

    my $pop          = CXGN::Phenome::Population->new( $dbh, $pop_id );
    my $pop_name     = $pop->get_name();
    my $sp_person_id = $pop->get_sp_person_id();

    my $map = CXGN::Map->new( $dbh, { map_version_id => $map_version_id } );
    my $map_id = $map->get_map_id();

    my $linkage = CXGN::LinkageGroup->new( $dbh, $map_version_id );

    unless ($map_id) {
        die "I need a valid reference map before I can 
             start loading the genotype data\n";
    }

    eval {

        my $experiment = CXGN::Phenome::GenotypeExperiment->new($dbh);
        $experiment->set_background_accession_id(100);
        $experiment->set_experiment_name($pop_name);
        $experiment->set_reference_map_id($map_id);
        $experiment->set_sp_person_id($sp_person_id);
        $experiment->set_preferred(1);
        my $experiment_id = $experiment->store();

        while ( my $row = <F> ) {
            chomp($row);
            my @plant_genotype = split /\t/, $row;
            my $plant_name = shift(@plant_genotype);
	    $plant_name =~ s/^\s+|\s+$//g;
	    print STDERR "\n storing genotype... individual: $plant_name\n";
            
	    my @individual = CXGN::Phenome::Individual->new_with_name( $dbh, $plant_name, $pop_id );
	   	   
            die "There are two genotypes with the same name or no genotypes 
              in the same population. Can't assign genotype values."
              unless ( scalar(@individual) == 1 );

            if ( $individual[0] ) {

                my $genotype = CXGN::Phenome::Genotype->new($dbh);

                $genotype->set_genotype_experiment_id($experiment_id);
            
		my $individual_id = $individual[0]->get_individual_id();		
		$genotype->set_individual_id($individual_id);

                #$genotype->set_experiment_name($pop_name);
                #$genotype->set_reference_map_id($map_id);
                #$genotype->set_sp_person_id($sp_person_id);
                my $genotype_id = $genotype->store();

                my $mapmaker_genotype;
                for ( my $i = 0 ; $i < @plant_genotype ; $i++ ) {
                    
		    my $genotype_region = CXGN::Phenome::GenotypeRegion->new($dbh);
		   
		    $markers[$i] =~ s/^\s+|\s+$//g;
		    print STDERR "\n marker name: $markers[$i]\n";
		    $markers[$i] = CXGN::Marker::Tools::clean_marker_name( $markers[$i] );
		    print STDERR "\n clean marker name: $markers[$i]\n";
		    my $marker_id;

		    my $marker = CXGN::Marker->new_with_name( $dbh, $markers[$i] );
		    if ($marker) {
			$marker_id = $marker->marker_id();
		    } else {
			my @marker_ids =  CXGN::Marker::Tools::marker_name_to_ids( $dbh, $markers[$i] );
		    
		#	if ( @marker_ids > 1 ) {
		#	    die "Too many IDs found for marker '$markers[$i]'";
		#	} 
		    
			$marker_id = $marker_ids[0];
		    }

		    print STDERR "\n marker id: $markers[$i] -- $marker_id\n";
		    $chrs[$i] =~ s/^\s+|\s+$//g;
		    my $c     = $chrs[$i];
                    my $lg_id = $linkage->get_lg_id( $chrs[$i] );
		    
		    $plant_genotype[$i] =~ s/^\s+|\s+$//g;
                    print STDERR "\n $markers[$i] -- $marker_id -- $chrs[$i] -- $plant_genotype[$i]\n";
		    if ( !$plant_genotype[$i]
                        || ( $plant_genotype[$i] =~ /\-/ ) )
                    {
                        next();
                    }

                    $genotype_region->set_phenome_genotype_id($genotype_id);
                    $genotype_region->set_marker_id_nn( $marker_id );
                    $genotype_region->set_marker_id_ns( $marker_id );
                    $genotype_region->set_marker_id_sn( $marker_id );
                    $genotype_region->set_marker_id_ss( $marker_id );
                    $genotype_region->set_lg_id($lg_id);
                    $genotype_region->set_sp_person_id($sp_person_id);

                    if ( $i == 0 ) {
                        if ( $plant_genotype[$i] =~ /\d/ ) {
                            $mapmaker_genotype = 1;
                        }
                        elsif ( $plant_genotype[$i] =~ /\D/ ) {
                            $mapmaker_genotype = undef;
                        }
                    }

                    if ($mapmaker_genotype) {
                        $genotype_region->set_mapmaker_zygocity_code(
                            $plant_genotype[$i] );
                    }
                    else {
                        $genotype_region->set_zygocity_code(
                            $plant_genotype[$i] );
                    }
                    $genotype_region->set_type("map");
                    $genotype_region->store();
                }

            }
            else {
                die
"There is mismatch between the list of genotypes/lines ($plant_genotype[0] 
                  in your phenotype and genotype datasets\n";
            }
        }

    };

    if ($@) {
        $dbh->rollback();
        print STDERR "An error occurred loading genotype data: 
                       $@. ROLLED BACK CHANGES.\n";
        return undef;
    }
    else {
        print STDERR "All is  fine. Committing...genotype data\n";
        $dbh->commit();
        return 1;
    }

}

=head2 accessors get_sp_person_id, set_sp_person_id

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_sp_person_id {
    my $self = shift;
    return $self->{sp_person_id};
}

sub set_sp_person_id {
    my $self = shift;
    $self->{sp_person_id} = shift;
}

=head2 accessors get_population_id, set_population_id

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_population_id {
    my $self = shift;
    return $self->{population_id};
}

sub set_population_id {
    my $self = shift;
    $self->{population_id} = shift;
}

=head2 accessors get_dbh, set_dbh

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_dbh {
    my $self = shift;
    return $self->{dbh};
}

sub set_dbh {
    my $self = shift;
    $self->{dbh} = shift;
}

=head2 common_name_id

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub common_name_id {
    my $self         = shift;
    my $sp_person_id = $self->get_sp_person_id();
    my $qtl          = CXGN::Phenome::Qtl->new($sp_person_id);
    my ( $qtl_dir, $user_qtl_dir ) = $qtl->get_user_qtl_dir($c);

    my $id;
    if ( -e "$user_qtl_dir/organism.txt" ) {
        open C, "<$user_qtl_dir/organism.txt" or die "Can't open file: !$\n";

        my $row = <C>;
        if ( $row =~ /(\d)/ ) {
            $id = $1;
        }

        close C;

        return $id;
    }
    else {
        return 0;
    }

}

=head2 error_page

 Usage: $self->error_page(@errors);
 Desc: when feed with error messages, it generates an 
       error page with a list of the messages and a link 
       back to the previous page where required data field(s)
       was/were not properly filled.
 Ret: page with the appropriate message
 Args: a list of messages to print...
 Side Effects:
 Example:

=cut

sub error_page {
    my $self  = shift;
    my @error = @_;
   
    $c->forward_to_mason_view('/qtl/qtl_load/missing_data.mas',
                              missing_data => \@error,
                              guide        => $self->guideline(),
        )
}

=head2 check_organism

 Usage: $self->check_organism($organism);
 Desc: checks if organism object is defined and if the
       the parental species is supported by sgn (chado.organism).
       in case organism object is not defined (a query to the chado.organism 
       using a species name does not return a value, it generates 
       a page with advise to check for the spelling of the scientific species name.
 Ret: a page with advice 
 Args: organism object, species name, cultivar name
 Side Effects: 
 Example:

=cut

sub check_organism {
    my ($self, $organism, $species, $cultivar) = @_ ;
    
    unless ( !$cultivar ) {
        $cultivar = " cv. $cultivar";
    }

    if ( !$organism ) 
    {
        $c->forward_to_mason_view('/qtl/qtl_load/check_organism.mas',                                
                                  species  => $species,
                                  cultivar => $cultivar,
                                  guide    => $self->guideline(),
            );
    } else
    {
 #do nothing..relax
    }
}


=head2 population_exists

 Usage: $self->population_exists($population, $population_name);
 Desc: checks if there is already a population with the same name
       and if so it generates a page with the appropriate advice to the user

 Ret: a page with advice 
 Args: population object, population name
 Side Effects: 
 Example:

=cut

sub population_exists {
    my ($self, $pop, $name) = @_;
    
    if ($pop) {
        
        $c->forward_to_mason_view('/qtl/qtl_load/population_exists.mas',
                              name  => $name,
                              guide => $self->guideline()
            );
    }
}

 

sub guideline {
    my $self = shift;
    return qq |<a  href="/qtl/submission/guide">Guidelines</a> |;
}

=head2 trait_columns

 Usage: $self->trait_columns($error);
 Desc: checks if the trait file has the right order
       of data columns and if not advises the submitter
       with the appropriate message

 Ret: a page with advice 
 Args: text message
 Side Effects: 
 Example:

=cut

sub trait_columns {
    my ($self, $trait_error) = @_;
   
    if ($trait_error) {
        $c->forward_to_mason_view('/qtl/qtl_load/trait_columns.mas',
                                  error => $trait_error,
                                  guide => $self->guideline()
            )
    }
}


=head2 accessors compare_file_names

 Usage: $f = $self->compare_file_names($file1, $file2);
 Desc: useful for checking if data files submitted for the traits, 
       phenotype and genotype are different. helpful to avoid indvertent
       uploading of the same file for different fields. 
      
 Ret: a page with advice if the same files are uploaded 
 Args: file names to compare
 Side Effects:
 Example:

=cut

sub compare_file_names {
    my ($self, $file1, $file2) = @_;
   
    unless ( $file1 ne $file2 ) {
        $c->forward_to_mason_view('/qtl/qtl_load/compare_file_names.mas',
                                  file1 => $file1,
                                  file2 => $file2,
                                  guide => $self->guideline()
            )
    }
}

=head2 send_email

 Usage: $self->send_email($subj, $message, $pop_id);
 Desc:  sends email at each step of the qtl data upload
        process.. 
 Ret: nothing
 Args: subject, message, population_id
 Side Effects:
 Example:

=cut

sub send_email {
    my $self = shift;
    my ( $subj, $message, $pop_id ) = @_;
    my $dbh          = $self->get_dbh();
    my $sp_person_id = $self->get_sp_person_id();
    my $person       = CXGN::People::Person->new( $dbh, $sp_person_id );

    my $user_profile =
qq |http://solgenomics.net/solpeople/personal-info.pl?sp_person_id=$sp_person_id |;

    my $username = $person->get_first_name() . " " . $person->get_last_name();
    $message .=
qq |\nQTL population id: $pop_id \nQTL data owner: $username ($user_profile) |;

    print STDERR "\n$subj\n$message\n";
    CXGN::Contact::send_email( $subj, $message,
        'sgn-db-curation@sgn.cornell.edu' );

}


sub post_stat_form {
    my ($self, $args_ref) = @_;
    
    my $sp_person_id = $self->get_sp_person_id();
    my $qtl_obj      = CXGN::Phenome::Qtl->new($sp_person_id, $args_ref );
    my $qtl_tools    = CXGN::Phenome::Qtl::Tools->new(); 
    my $stat_param   = $qtl_obj->user_stat_parameters();
    my @missing      = $qtl_tools->check_stat_fields($stat_param);  
    my $pop_id       = $args_ref->{pop_id};
    
    my ($stat_file, $type);
    if (@missing) {
        $self->error_page(@missing);
    }
    else {
        $stat_file = $qtl_obj->user_stat_file( $c, $pop_id );
        $type = 'confirm';
    }
 
    if ($type eq 'confirm') {
        my $referer = $c->req->base . "qtl/form/stat_form/$pop_id";
        if (-e $stat_file && $c->req->referer eq $referer) 
        {
            my $qtlpage = $c->req->base . "qtl/population/$pop_id";
            my $message = qq | QTL statistical parameters set: Step 5 of 5. 
                               QTL data upload for<a href="$qtlpage">population 
                               $pop_id</a> is completed. |;

            $self->send_email( '[QTL upload: Step 5]', $message, $pop_id );
            $self->redirect_to_next_form("/qtl/form/confirm/$pop_id");
         
        }
        else 
        {
            $c->res->redirect($c->req->referer);
            $c->detach();
        }
    } else 
    {
        $c->res->redirect($c->req->referer);
        $c->detach();
    }
}

sub show_pop_form {
    my ( $self ) = @_;
    $self->send_email( '[QTL upload: Step 1]', 'A user is at the QTL data upload Step 1 of 5', 'NA' );    
    $self->redirect_to_next_form("/qtl/form/pop_form"); 
}

sub post_pop_form {
    my ($self, $qtl_obj, $qtl_tools) = @_;

    my $pop_detail = $qtl_obj->user_pop_details();    
    my @error = $qtl_tools->check_pop_fields($pop_detail);
    
    my  ( $pop_id, $pop_name, $desc );
    if (@error) 
    {
        $self->error_page(@error);
    }
    else 
    {
        ( $pop_id, $pop_name, $desc ) =
            $self->load_pop_details($pop_detail);
    }
    
    unless ( !$pop_id ) 
    {
        $self->send_email( '[QTL upload: Step 1]', 'QTL population data uploaded: Step 1 of 5 completed', $pop_id );
        $self->redirect_to_next_form("/qtl/form/trait_form/$pop_id");        
    }
}

sub post_trait_form {
    my ($self, $qtl_obj, $trait_file, $pop_id) = @_;

    if (!$trait_file) 
    {
        $self->error_page("Trait file");
    }
   
    my $uploaded_file = $self->trait_upload($qtl_obj, $trait_file);
    
    my $traits_in_db;
    if ($uploaded_file) 
    {
        $traits_in_db = $self->store_traits($uploaded_file);
    }
    
    if ($pop_id && $traits_in_db) 
    {
        $self->send_email('[QTL upload: Step 2]', 'QTL traits uploaded: Step 2 of 5', $pop_id);
        $self->redirect_to_next_form("/qtl/form/pheno_form/$pop_id");
    }


}


sub post_pheno_form {
    my ($self, $qtl_obj, $pheno_file, $pop_id) = @_;
    
    if (!$pheno_file) 
    { 
        $self->error_page('Phenotype dataset file'); 
    } 
   
    my $uploaded_file = $self->pheno_upload($qtl_obj, $pheno_file);
    
    my  $phenotype_in_db;
    if ($uploaded_file) 
    {
    $phenotype_in_db = $self->store_trait_values($uploaded_file);
    }
 
    if ($phenotype_in_db && $pop_id) 
    {           
        $self->send_email('[QTL upload: Step 3]', 'QTL phenotype data uploaded: Step 3 of 5', $pop_id);
        $self->redirect_to_next_form("/qtl/form/geno_form/$pop_id"); 
    }


}
sub post_geno_form {
    my ($self, $qtl_obj, $geno_file, $pop_id) = @_;
        
    if (!$geno_file) 
    { 
        $self->error_page('Genotype dataset file'); 
    } 

    my ($map_id, $map_version_id);     
    my  $uploaded_file = $self->geno_upload( $qtl_obj, $geno_file);
    
    if ($uploaded_file)
    {
        ( $map_id, $map_version_id ) = $self->store_map($uploaded_file);
    }
    else 
    {
        $self->error_page('Genotype dataset file');
    }
  
    my $genotype_uploaded;

    if ($map_version_id) 
    {
        my $result = $self->store_marker_and_position($uploaded_file, $map_version_id);
        
        unless ($result)  
        {
            $c->throw_404("Couldn't store markers and position.");
        }
                   
        my $genotype_uploaded = $self->store_genotype($uploaded_file, $map_version_id);           
        
        if ($genotype_uploaded) 
        {
            $self->send_email( '[QTL upload: Step 4]', 'QTL genotype data uploaded : Step 4 of 5', $pop_id );
            $self->redirect_to_next_form("/qtl/form/stat_form/$pop_id");
        }
        else 
        {
            $c->throw_404("failed storing genotype data.");
        }        
    }          
}

sub redirect_to_next_form {
    my ($self, $next_form) = @_;
    $c->res->redirect("$next_form");
    $c->detach();    
}

