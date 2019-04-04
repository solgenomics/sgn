
package SGN::Controller::Status;

use Moose;
use Data::Dumper;

BEGIN { extends "Catalyst::Controller"; }



sub status : Path('/status') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
    my $dbh = $schema->storage->dbh();
    my $h;

    # Get Accession count
    $h = $dbh->prepare("SELECT COUNT(accession_id) AS count FROM accessions;");
    $h->execute();
    my ($accession_count) = $h->fetchrow_array() and $h->finish();

    # Get Breeding Program Count
    $h = $dbh->prepare("SELECT COUNT(breeding_program_id) AS count FROM breeding_programs;");
    $h->execute();
    my ($breeding_program_count) = $h->fetchrow_array() and $h->finish();

    # Get Count of Lines with Pheno Data
    $h = $dbh->prepare("SELECT COUNT(DISTINCT accession_id) AS count FROM accessionsxplots;");
    $h->execute();
    my ($accession_count_pheno) = $h->fetchrow_array() and $h->finish();

    # Get Count of Lines with Geno Data
    $h = $dbh->prepare("SELECT COUNT(DISTINCT accession_id) AS count FROM accessionsxgenotyping_protocols WHERE genotyping_protocol_id IS NOT NULL;");
    $h->execute();
    my ($accession_count_geno) = $h->fetchrow_array() and $h->finish();

    # Get Trait Count
    $h = $dbh->prepare("SELECT COUNT(DISTINCT observable_id) AS count FROM phenotype;");
    $h->execute();
    my ($trait_count) = $h->fetchrow_array() and $h->finish();

    # Get Pheno Trial Count
    $h = $dbh->prepare("SELECT COUNT(trial_id) AS count FROM trials;");
    $h->execute();
    my ($pheno_trial_count) = $h->fetchrow_array() and $h->finish();

    # Get Count of Total Pheno Observations
    $h = $dbh->prepare("SELECT COUNT(DISTINCT phenotype_id) FROM materialized_phenoview WHERE phenotype_id IS NOT NULL;");
    $h->execute();
    my ($pheno_observations) = $h->fetchrow_array() and $h->finish();

    # Get last pheno addition date
    $h = $dbh->prepare("SELECT MAX(create_date) FROM phenotype;");
    $h->execute();
    my ($pheno_last_addition) = $h->fetchrow_array() and $h->finish();

    # Pass query results to template
    $c->stash->{accession_count} = $accession_count;
    $c->stash->{breeding_program_count} = $breeding_program_count;
    $c->stash->{accession_count_pheno} = $accession_count_pheno;
    $c->stash->{accession_count_geno} = $accession_count_geno;
    $c->stash->{trait_count} = $trait_count;
    $c->stash->{pheno_trial_count} = $pheno_trial_count;
    $c->stash->{pheno_observations} = $pheno_observations;
    $c->stash->{pheno_last_addition} = $pheno_last_addition;
    $c->stash->{template} = '/about/sgn/status.mas';
}

1;
