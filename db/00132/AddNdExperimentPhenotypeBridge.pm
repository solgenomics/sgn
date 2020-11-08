#!/usr/bin/env perl


=head1 NAME

 AddNdExperimentPhenotypeBridge.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a patch to add the nd_experiment_phenotype_bridge table to move phenotype value storage to a simpler/faster system.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddNdExperimentPhenotypeBridge;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This is a patch to add the nd_experiment_phenotype_bridge table to move phenotype value storage to a simpler/faster system.

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);

DROP TABLE IF EXISTS public.nd_experiment_phenotype_bridge CASCADE;
CREATE TABLE public.nd_experiment_phenotype_bridge (
    nd_experiment_phenotype_bridge_id SERIAL PRIMARY KEY,
    stock_id INT NOT NULL,
    project_id INT NOT NULL,
    phenotype_id INT,
    nd_geolocation_id INT NOT NULL,
    file_id INT,
    image_id INT,
    json_id INT,
    upload_date TIMESTAMP DEFAULT now(),
    create_date TIMESTAMP DEFAULT now(),
    CONSTRAINT nd_experiment_phenotype_bridge_stock_id_fkey
        FOREIGN KEY(stock_id) 
            REFERENCES stock(stock_id)
            ON DELETE CASCADE,
    CONSTRAINT nd_experiment_phenotype_bridge_project_id_fkey
        FOREIGN KEY(project_id) 
            REFERENCES project(project_id)
            ON DELETE CASCADE,
    CONSTRAINT nd_experiment_phenotype_bridge_phenotype_id_fkey
        FOREIGN KEY(phenotype_id) 
            REFERENCES phenotype(phenotype_id)
            ON DELETE CASCADE,
    CONSTRAINT nd_experiment_phenotype_bridge_nd_geolocation_id_fkey
        FOREIGN KEY(nd_geolocation_id) 
            REFERENCES nd_geolocation(nd_geolocation_id)
            ON DELETE CASCADE,
    CONSTRAINT nd_experiment_phenotype_bridge_file_id_fkey
        FOREIGN KEY(file_id) 
            REFERENCES metadata.md_files(file_id)
            ON DELETE CASCADE,
    CONSTRAINT nd_experiment_phenotype_bridge_image_id_fkey
        FOREIGN KEY(image_id) 
            REFERENCES metadata.md_image(image_id)
            ON DELETE CASCADE,
    CONSTRAINT nd_experiment_phenotype_bridge_json_id_fkey
        FOREIGN KEY(json_id) 
            REFERENCES metadata.md_json(json_id)
            ON DELETE CASCADE
);

ALTER TABLE public.nd_experiment_phenotype_bridge OWNER TO postgres;
GRANT ALL PRIVILEGES ON public.nd_experiment_phenotype_bridge TO web_usr;
GRANT ALL PRIVILEGES ON public.nd_experiment_phenotype_bridge TO postgres;
GRANT USAGE ON nd_experiment_phenotype_bridg_nd_experiment_phenotype_bridg_seq TO web_usr;
GRANT USAGE ON nd_experiment_phenotype_bridg_nd_experiment_phenotype_bridg_seq TO postgres;

DROP TABLE IF EXISTS sgn.nd_experiment_phenotype_bridge CASCADE;

EOSQL
	

print "You're done!\n";
}


####
1; #
####
