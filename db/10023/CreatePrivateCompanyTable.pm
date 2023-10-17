#!/usr/bin/env perl


=head1 NAME

 CreatePrivateCompanyTable.pm

=head1 SYNOPSIS

mx-run CreatePrivateCompanyTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Creates the sgn_people.private_company table links
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreatePrivateCompanyTable;

use Moose;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates the sgn_people.private_company table links

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $terms = {
        'company_type' => [
            'default_access',
        ],
        'company_person_type' => [
            'user_access',
            'submitter_access',
            'curator_access'
        ],
        'company_cvterm_type' => [
            'default_cvterm_access'
        ]
    };

    foreach my $t (keys %$terms){
        foreach (@{$terms->{$t}}){
            $schema->resultset("Cv::Cvterm")->create_with({
                name => $_,
                cv => $t
            });
        }
    }

    my $company_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'default_access', 'company_type')->cvterm_id();
    my $company_person_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'user_access', 'company_person_type')->cvterm_id();
    my $company_cvterm_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'default_cvterm_access', 'company_cvterm_type')->cvterm_id();

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

DROP TABLE IF EXISTS sgn_people.private_company CASCADE;
CREATE TABLE sgn_people.private_company (
   private_company_id SERIAL PRIMARY KEY,
   name varchar(128),
   description text,
   contact_email varchar(128),
   contact_person_first_name varchar(128),
   contact_person_last_name varchar(128),
   contact_person_phone varchar(128),
   address_street varchar(128),
   address_street_2 varchar(128),
   address_state varchar(128),
   address_zipcode varchar(128),
   address_country varchar(128),
   type_id INT NOT NULL,
   create_date TIMESTAMP DEFAULT now(),
   CONSTRAINT private_company_sp_person_type_id_fkey
       FOREIGN KEY(type_id)
           REFERENCES cvterm(cvterm_id)
           ON DELETE CASCADE
);

ALTER TABLE sgn_people.private_company OWNER TO postgres;
GRANT select, update, insert, delete ON sgn_people.private_company to postgres, web_usr;
GRANT usage on sequence private_company_private_company_id_seq to postgres, web_usr;

DROP TABLE IF EXISTS sgn_people.private_company_sp_person CASCADE;
CREATE TABLE sgn_people.private_company_sp_person (
    private_company_sp_person_id SERIAL PRIMARY KEY,
    private_company_id INT NOT NULL,
    sp_person_id INT NOT NULL,
    type_id INT NOT NULL,
    is_private BOOLEAN DEFAULT FALSE,
    create_date TIMESTAMP DEFAULT now(),
    CONSTRAINT private_company_sp_person_cvterm_type_id_fkey
        FOREIGN KEY(type_id)
            REFERENCES cvterm(cvterm_id)
            ON DELETE CASCADE,
    CONSTRAINT private_company_sp_person_sp_person_sp_person_id_fkey
        FOREIGN KEY(sp_person_id)
            REFERENCES sp_person(sp_person_id)
            ON DELETE CASCADE,
    CONSTRAINT private_company_sp_person_private_company_private_company_id_fk
        FOREIGN KEY(private_company_id)
            REFERENCES sgn_people.private_company(private_company_id)
            ON DELETE CASCADE
);

ALTER TABLE sgn_people.private_company_sp_person OWNER TO postgres;
GRANT select, update, insert, delete ON sgn_people.private_company_sp_person to postgres, web_usr;
GRANT usage on sequence private_company_sp_person_private_company_sp_person_id_seq to postgres, web_usr;

DROP TABLE IF EXISTS sgn_people.private_company_cvterm CASCADE;
CREATE TABLE sgn_people.private_company_cvterm (
    private_company_cvterm_id SERIAL PRIMARY KEY,
    private_company_id INT NOT NULL,
    cvterm_id INT NOT NULL,
    type_id INT NOT NULL,
    is_private BOOLEAN DEFAULT FALSE,
    create_date TIMESTAMP DEFAULT now(),
    CONSTRAINT private_company_cvterm_cvterm_type_id_fkey
        FOREIGN KEY(type_id)
            REFERENCES cvterm(cvterm_id)
            ON DELETE CASCADE,
    CONSTRAINT private_company_cvterm_cvterm_cvterm_id_fkey
        FOREIGN KEY(cvterm_id)
            REFERENCES cvterm(cvterm_id)
            ON DELETE CASCADE,
    CONSTRAINT private_company_cvterm_private_company_private_company_id_fkey
        FOREIGN KEY(private_company_id)
            REFERENCES sgn_people.private_company(private_company_id)
            ON DELETE CASCADE
);

ALTER TABLE sgn_people.private_company_cvterm OWNER TO postgres;
GRANT select, update, insert, delete ON sgn_people.private_company_cvterm to postgres, web_usr;
GRANT usage on sequence private_company_cvterm_private_company_cvterm_id_seq to postgres, web_usr;

INSERT INTO sgn_people.private_company (name, description, contact_email, contact_person_first_name, contact_person_last_name, contact_person_phone, address_street, address_street_2, address_state, address_zipcode, address_country, type_id) VALUES ('ImageBreed', 'ImageBreed develops breeding management software for handling aerial imaging data, field experiments, genotyping data, and analyses.', 'nmorales3142\@gmail.com', 'Nicolas', 'Morales', '3216959465', '121 Veterans Place', 'Apt C305', 'NY', '14850', 'USA', $company_type_id);

ALTER TABLE project ADD COLUMN "is_private" BOOLEAN DEFAULT FALSE;
ALTER TABLE stock ADD COLUMN "is_private" BOOLEAN DEFAULT FALSE;
ALTER TABLE phenotype ADD COLUMN "is_private" BOOLEAN DEFAULT FALSE;
ALTER TABLE genotype ADD COLUMN "is_private" BOOLEAN DEFAULT FALSE;
ALTER TABLE nd_protocol ADD COLUMN "is_private" BOOLEAN DEFAULT FALSE;
ALTER TABLE nd_geolocation ADD COLUMN "is_private" BOOLEAN DEFAULT FALSE;

ALTER TABLE project ADD COLUMN "private_company_id" INT NOT NULL DEFAULT(1);
ALTER TABLE stock ADD COLUMN "private_company_id" INT NOT NULL DEFAULT(1);
ALTER TABLE phenotype ADD COLUMN "private_company_id" INT NOT NULL DEFAULT(1);
ALTER TABLE genotype ADD COLUMN "private_company_id" INT NOT NULL DEFAULT(1);
ALTER TABLE nd_protocol ADD COLUMN "private_company_id" INT NOT NULL DEFAULT(1);
ALTER TABLE nd_geolocation ADD COLUMN "private_company_id" INT NOT NULL DEFAULT(1);

ALTER TABLE project ADD CONSTRAINT project_private_company_private_company_id_fkey FOREIGN KEY (private_company_id) REFERENCES sgn_people.private_company(private_company_id) ON DELETE CASCADE;
ALTER TABLE stock ADD CONSTRAINT stock_private_company_private_company_id_fkey FOREIGN KEY (private_company_id) REFERENCES sgn_people.private_company(private_company_id) ON DELETE CASCADE;
ALTER TABLE phenotype ADD CONSTRAINT phenotype_private_company_private_company_id_fkey FOREIGN KEY (private_company_id) REFERENCES sgn_people.private_company(private_company_id) ON DELETE CASCADE;
ALTER TABLE genotype ADD CONSTRAINT genotype_private_company_private_company_id_fkey FOREIGN KEY (private_company_id) REFERENCES sgn_people.private_company(private_company_id) ON DELETE CASCADE;
ALTER TABLE nd_protocol ADD CONSTRAINT nd_protocol_private_company_private_company_id_fkey FOREIGN KEY (private_company_id) REFERENCES sgn_people.private_company(private_company_id) ON DELETE CASCADE;
ALTER TABLE nd_geolocation ADD CONSTRAINT nd_geolocation_private_company_private_company_id_fkey FOREIGN KEY (private_company_id) REFERENCES sgn_people.private_company(private_company_id) ON DELETE CASCADE;

INSERT INTO sgn_people.private_company_sp_person (private_company_id, sp_person_id, type_id)
(SELECT 1, sp_person_id, $company_person_type_id FROM sgn_people.sp_person);

INSERT INTO sgn_people.private_company_cvterm (private_company_id, cvterm_id, type_id)
(SELECT 1, cvterm_id, $company_cvterm_type_id FROM cvterm);

EOSQL


print "You're done!\n";
}


####
1; #
####
