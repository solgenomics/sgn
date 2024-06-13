#!/usr/bin/env perl

=head1 NAME

AddAuditTables.pm

=head1 SYNOPSIS

mx-run AddAuditTables.pm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds audit tables
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Adrian Powell <afp43@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddAuditTables;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds audit tables

has '+prereq' => (
	default => sub {
        [],
    },

);

sub patch {
    my $self=shift;

    $self->dbh->do(<<EOSQL);
--do your SQL here

--CREATE TABLE public.logged_in_user (sp_person_id INT);
--INSERT INTO public.logged_in_user (sp_person_id) VALUES (57);
--ALTER TABLE public.logged_in_user OWNER TO web_usr;

CREATE SCHEMA IF NOT EXISTS audit;
ALTER SCHEMA audit OWNER TO web_usr;

CREATE TABLE audit.cv_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       cv_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.cv_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.cv_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);
IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.cv_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.cv_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.cv_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER cv_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.cv
       FOR EACH ROW
       EXECUTE PROCEDURE public.cv_audit_trig();

CREATE TABLE audit.cvprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       cvprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.cvprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.cvprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.cvprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.cvprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.cvprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER cvprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.cvprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.cvprop_audit_trig();

CREATE TABLE audit.cvterm_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       cvterm_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.cvterm_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.cvterm_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.cvterm_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.cvterm_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.cvterm_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER cvterm_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.cvterm
       FOR EACH ROW
       EXECUTE PROCEDURE public.cvterm_audit_trig();

CREATE TABLE audit.cvterm_dbxref_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       cvterm_dbxref_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.cvterm_dbxref_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.cvterm_dbxref_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.cvterm_dbxref_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.cvterm_dbxref_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.cvterm_dbxref_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER cvterm_dbxref_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.cvterm_dbxref
       FOR EACH ROW
       EXECUTE PROCEDURE public.cvterm_dbxref_audit_trig();

CREATE TABLE audit.cvterm_relationship_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       cvterm_relationship_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.cvterm_relationship_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.cvterm_relationship_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.cvterm_relationship_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.cvterm_relationship_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.cvterm_relationship_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER cvterm_relationship_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.cvterm_relationship
       FOR EACH ROW
       EXECUTE PROCEDURE public.cvterm_relationship_audit_trig();

CREATE TABLE audit.cvtermpath_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       cvtermpath_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.cvtermpath_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.cvtermpath_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.cvtermpath_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.cvtermpath_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.cvtermpath_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER cvtermpath_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.cvtermpath
       FOR EACH ROW
       EXECUTE PROCEDURE public.cvtermpath_audit_trig();

CREATE TABLE audit.cvtermprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       cvtermprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.cvtermprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.cvtermprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.cvtermprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.cvtermprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.cvtermprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER cvtermprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.cvtermprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.cvtermprop_audit_trig();

CREATE TABLE audit.cvtermsynonym_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       cvtermsynonym_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.cvtermsynonym_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.cvtermsynonym_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.cvtermsynonym_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.cvtermsynonym_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.cvtermsynonym_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER cvtermsynonym_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.cvtermsynonym
       FOR EACH ROW
       EXECUTE PROCEDURE public.cvtermsynonym_audit_trig();

CREATE TABLE audit.db_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       db_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.db_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.db_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.db_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.db_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.db_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER db_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.db
       FOR EACH ROW
       EXECUTE PROCEDURE public.db_audit_trig();

CREATE TABLE audit.dbxref_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       dbxref_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.dbxref_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.dbxref_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.dbxref_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.dbxref_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.dbxref_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER dbxref_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.dbxref
       FOR EACH ROW
       EXECUTE PROCEDURE public.dbxref_audit_trig();

CREATE TABLE audit.dbxrefprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       dbxrefprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.dbxrefprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.dbxrefprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.dbxrefprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.dbxrefprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.dbxrefprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER dbxrefprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.dbxrefprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.dbxrefprop_audit_trig();

CREATE TABLE audit.genotype_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       genotype_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.genotype_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.genotype_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.genotype_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.genotype_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.genotype_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER genotype_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.genotype
       FOR EACH ROW
       EXECUTE PROCEDURE public.genotype_audit_trig();

CREATE TABLE audit.nd_experiment_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_audit_trig();

CREATE TABLE audit.nd_experiment_contact_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_contact_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_contact_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_contact_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_contact_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_contact_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_contact_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_contact_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_contact
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_contact_audit_trig();

CREATE TABLE audit.nd_experiment_dbxref_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_dbxref_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_dbxref_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_dbxref_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_dbxref_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_dbxref_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_dbxref_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_dbxref_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_dbxref
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_dbxref_audit_trig();

CREATE TABLE audit.nd_experiment_genotype_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_genotype_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_genotype_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_genotype_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_genotype_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_genotype_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_genotype_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_genotype_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_genotype
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_genotype_audit_trig();

CREATE TABLE audit.nd_experiment_phenotype_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_phenotype_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_phenotype_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_phenotype_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_phenotype_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_phenotype_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_phenotype_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_phenotype_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_phenotype
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_phenotype_audit_trig();

CREATE TABLE audit.nd_experiment_project_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_project_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_project_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_project_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_project_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_project_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_project_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_project_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_project
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_project_audit_trig();

CREATE TABLE audit.nd_experiment_protocol_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_protocol_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_protocol_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_protocol_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_protocol_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_protocol_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_protocol_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_protocol_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_protocol
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_protocol_audit_trig();

CREATE TABLE audit.nd_experiment_pub_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_pub_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_pub_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_pub_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);
IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_pub_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_pub_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_pub_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_pub_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_pub
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_pub_audit_trig();

CREATE TABLE audit.nd_experiment_stock_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_stock_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_stock_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_stock_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_stock_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_stock_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_stock_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_stock_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_stock
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_stock_audit_trig();

CREATE TABLE audit.nd_experiment_stock_dbxref_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_stock_dbxref_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_stock_dbxref_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_stock_dbxref_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_stock_dbxref_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_stock_dbxref_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_stock_dbxref_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_stock_dbxref_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_stock_dbxref
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_stock_dbxref_audit_trig();

CREATE TABLE audit.nd_experiment_stockprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experiment_stockprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experiment_stockprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experiment_stockprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experiment_stockprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experiment_stockprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experiment_stockprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experiment_stockprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experiment_stockprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experiment_stockprop_audit_trig();

CREATE TABLE audit.nd_experimentprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_experimentprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_experimentprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_experimentprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_experimentprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_experimentprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_experimentprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_experimentprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_experimentprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_experimentprop_audit_trig();

CREATE TABLE audit.nd_geolocation_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_geolocation_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_geolocation_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_geolocation_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_geolocation_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_geolocation_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_geolocation_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_geolocation_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_geolocation
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_geolocation_audit_trig();

CREATE TABLE audit.nd_geolocationprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_geolocationprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_geolocationprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_geolocationprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_geolocationprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_geolocationprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_geolocationprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_geolocationprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_geolocationprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_geolocationprop_audit_trig();

CREATE TABLE audit.nd_protocol_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_protocol_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_protocol_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_protocol_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_protocol_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_protocol_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_protocol_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_protocol_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_protocol
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_protocol_audit_trig();

CREATE TABLE audit.nd_protocol_reagent_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_protocol_reagent_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_protocol_reagent_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_protocol_reagent_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_protocol_reagent_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_protocol_reagent_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_protocol_reagent_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_protocol_reagent_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_protocol_reagent
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_protocol_reagent_audit_trig();

CREATE TABLE audit.nd_protocolprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_protocolprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_protocolprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_protocolprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_protocolprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_protocolprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_protocolprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_protocolprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_protocolprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_protocolprop_audit_trig();

CREATE TABLE audit.nd_reagent_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_reagent_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_reagent_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_reagent_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_reagent_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_reagent_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_reagent_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_reagent_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_reagent
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_reagent_audit_trig();

CREATE TABLE audit.nd_reagent_relationship_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_reagent_relationship_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_reagent_relationship_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_reagent_relationship_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_reagent_relationship_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_reagent_relationship_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_reagent_relationship_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_reagent_relationship_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_reagent_relationship
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_reagent_relationship_audit_trig();

CREATE TABLE audit.nd_reagentprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       nd_reagentprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.nd_reagentprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.nd_reagentprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.nd_reagentprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.nd_reagentprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.nd_reagentprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER nd_reagentprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.nd_reagentprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.nd_reagentprop_audit_trig();

CREATE TABLE audit.organism_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       organism_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.organism_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.organism_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.organism_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.organism_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.organism_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER organism_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.organism
       FOR EACH ROW
       EXECUTE PROCEDURE public.organism_audit_trig();

CREATE TABLE audit.organism_dbxref_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       organism_dbxref_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.organism_dbxref_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.organism_dbxref_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.organism_dbxref_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.organism_dbxref_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.organism_dbxref_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER organism_dbxref_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.organism_dbxref
       FOR EACH ROW
       EXECUTE PROCEDURE public.organism_dbxref_audit_trig();

CREATE TABLE audit.organism_relationship_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       organism_relationship_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.organism_relationship_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.organism_relationship_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.organism_relationship_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.organism_relationship_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.organism_relationship_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER organism_relationship_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.organism_relationship
       FOR EACH ROW
       EXECUTE PROCEDURE public.organism_relationship_audit_trig();

CREATE TABLE audit.organismpath_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       organismpath_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.organismpath_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.organismpath_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.organismpath_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.organismpath_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.organismpath_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER organismpath_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.organismpath
       FOR EACH ROW
       EXECUTE PROCEDURE public.organismpath_audit_trig();

CREATE TABLE audit.organismprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       organismprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.organismprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.organismprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.organismprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.organismprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.organismprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER organismprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.organismprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.organismprop_audit_trig();

CREATE TABLE audit.phenotype_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       phenotype_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.phenotype_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.phenotype_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.phenotype_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.phenotype_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.phenotype_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER phenotype_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.phenotype
       FOR EACH ROW
       EXECUTE PROCEDURE public.phenotype_audit_trig();

CREATE TABLE audit.phenotype_cvterm_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       phenotype_cvterm_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.phenotype_cvterm_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.phenotype_cvterm_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.phenotype_cvterm_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.phenotype_cvterm_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.phenotype_cvterm_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER phenotype_cvterm_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.phenotype_cvterm
       FOR EACH ROW
       EXECUTE PROCEDURE public.phenotype_cvterm_audit_trig();

CREATE TABLE audit.phenotypeprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       phenotypeprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.phenotypeprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.phenotypeprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.phenotypeprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.phenotypeprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.phenotypeprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER phenotypeprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.phenotypeprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.phenotypeprop_audit_trig();

CREATE TABLE audit.project_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       project_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.project_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.project_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.project_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.project_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.project_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER project_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.project
       FOR EACH ROW
       EXECUTE PROCEDURE public.project_audit_trig();

CREATE TABLE audit.project_contact_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       project_contact_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.project_contact_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.project_contact_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.project_contact_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.project_contact_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.project_contact_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER project_contact_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.project_contact
       FOR EACH ROW
       EXECUTE PROCEDURE public.project_contact_audit_trig();

CREATE TABLE audit.project_pub_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       project_pub_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.project_pub_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.project_pub_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);
IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.project_pub_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.project_pub_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.project_pub_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER project_pub_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.project_pub
       FOR EACH ROW
       EXECUTE PROCEDURE public.project_pub_audit_trig();

CREATE TABLE audit.project_relationship_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       project_relationship_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.project_relationship_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.project_relationship_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.project_relationship_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.project_relationship_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.project_relationship_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER project_relationship_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.project_relationship
       FOR EACH ROW
       EXECUTE PROCEDURE public.project_relationship_audit_trig();

CREATE TABLE audit.projectprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       projectprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.projectprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.projectprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.projectprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.projectprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.projectprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER projectprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.projectprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.projectprop_audit_trig();

CREATE TABLE audit.pub_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       pub_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.pub_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.pub_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.pub_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.pub_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.pub_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER pub_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.pub
       FOR EACH ROW
       EXECUTE PROCEDURE public.pub_audit_trig();

CREATE TABLE audit.pub_dbxref_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       pub_dbxref_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.pub_dbxref_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.pub_dbxref_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.pub_dbxref_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.pub_dbxref_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.pub_dbxref_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER pub_dbxref_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.pub_dbxref
       FOR EACH ROW
       EXECUTE PROCEDURE public.pub_dbxref_audit_trig();

CREATE TABLE audit.pub_relationship_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       pub_relationship_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.pub_relationship_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.pub_relationship_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.pub_relationship_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.pub_relationship_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.pub_relationship_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER pub_relationship_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.pub_relationship
       FOR EACH ROW
       EXECUTE PROCEDURE public.pub_relationship_audit_trig();

CREATE TABLE audit.pubabstract_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       pubabstract_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.pubabstract_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.pubabstract_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.pubabstract_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.pubabstract_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.pubabstract_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER pubabstract_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.pubabstract
       FOR EACH ROW
       EXECUTE PROCEDURE public.pubabstract_audit_trig();

CREATE TABLE audit.pubauthor_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       pubauthor_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.pubauthor_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.pubauthor_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.pubauthor_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.pubauthor_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.pubauthor_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER pubauthor_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.pubauthor
       FOR EACH ROW
       EXECUTE PROCEDURE public.pubauthor_audit_trig();

CREATE TABLE audit.pubprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       pubprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.pubprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.pubprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.pubprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.pubprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.pubprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER pubprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.pubprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.pubprop_audit_trig();

CREATE TABLE audit.stock_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_audit_trig();

CREATE TABLE audit.stock_cvterm_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_cvterm_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_cvterm_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_cvterm_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_cvterm_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_cvterm_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_cvterm_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_cvterm_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock_cvterm
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_cvterm_audit_trig();

CREATE TABLE audit.stock_cvtermprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_cvtermprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_cvtermprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_cvtermprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_cvtermprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_cvtermprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_cvtermprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_cvtermprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock_cvtermprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_cvtermprop_audit_trig();

CREATE TABLE audit.stock_dbxref_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_dbxref_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_dbxref_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_dbxref_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_dbxref_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_dbxref_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_dbxref_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_dbxref_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock_dbxref
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_dbxref_audit_trig();

CREATE TABLE audit.stock_dbxrefprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_dbxrefprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_dbxrefprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_dbxrefprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_dbxrefprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_dbxrefprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_dbxrefprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_dbxrefprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock_dbxrefprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_dbxrefprop_audit_trig();

CREATE TABLE audit.stock_genotype_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_genotype_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_genotype_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_genotype_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_genotype_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_genotype_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_genotype_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_genotype_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock_genotype
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_genotype_audit_trig();

CREATE TABLE audit.stock_pub_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_pub_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_pub_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_pub_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_pub_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_pub_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_pub_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_pub_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock_pub
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_pub_audit_trig();

CREATE TABLE audit.stock_relationship_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_relationship_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_relationship_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_relationship_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_relationship_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_relationship_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_relationship_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_relationship_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock_relationship
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_relationship_audit_trig();

CREATE TABLE audit.stock_relationship_cvterm_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_relationship_cvterm_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_relationship_cvterm_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_relationship_cvterm_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_relationship_cvterm_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_relationship_cvterm_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_relationship_cvterm_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_relationship_cvterm_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock_relationship_cvterm
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_relationship_cvterm_audit_trig();

CREATE TABLE audit.stock_relationship_pub_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stock_relationship_pub_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stock_relationship_pub_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stock_relationship_pub_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stock_relationship_pub_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stock_relationship_pub_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stock_relationship_pub_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stock_relationship_pub_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stock_relationship_pub
       FOR EACH ROW
       EXECUTE PROCEDURE public.stock_relationship_pub_audit_trig();

CREATE TABLE audit.stockcollection_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stockcollection_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stockcollection_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stockcollection_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stockcollection_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stockcollection_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stockcollection_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stockcollection_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stockcollection
       FOR EACH ROW
       EXECUTE PROCEDURE public.stockcollection_audit_trig();

CREATE TABLE audit.stockcollection_stock_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stockcollection_stock_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stockcollection_stock_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stockcollection_stock_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stockcollection_stock_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stockcollection_stock_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stockcollection_stock_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stockcollection_stock_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stockcollection_stock
       FOR EACH ROW
       EXECUTE PROCEDURE public.stockcollection_stock_audit_trig();

CREATE TABLE audit.stockcollectionprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stockcollectionprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stockcollectionprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stockcollectionprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stockcollectionprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stockcollectionprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stockcollectionprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stockcollectionprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stockcollectionprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.stockcollectionprop_audit_trig();

CREATE TABLE audit.stockprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stockprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stockprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stockprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stockprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stockprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stockprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stockprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stockprop
       FOR EACH ROW
       EXECUTE PROCEDURE public.stockprop_audit_trig();

CREATE TABLE audit.stockprop_pub_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       stockprop_pub_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.stockprop_pub_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.stockprop_pub_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.stockprop_pub_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.stockprop_pub_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.stockprop_pub_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER stockprop_pub_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON public.stockprop_pub
       FOR EACH ROW
       EXECUTE PROCEDURE public.stockprop_pub_audit_trig();

CREATE TABLE audit.list_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       list_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.list_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.list_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.list_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.list_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.list_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER list_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.list
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.list_audit_trig();

CREATE TABLE audit.list_item_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       list_item_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.list_item_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.list_item_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.list_item_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.list_item_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.list_item_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER list_item_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.list_item
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.list_item_audit_trig();

CREATE TABLE audit.sp_dataset_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       sp_dataset_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.sp_dataset_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.sp_dataset_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.sp_dataset_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.sp_dataset_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.sp_dataset_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER sp_dataset_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.sp_dataset
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.sp_dataset_audit_trig();

CREATE TABLE audit.sp_order_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       sp_order_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.sp_order_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.sp_order_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.sp_order_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.sp_order_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.sp_order_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER sp_order_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.sp_order
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.sp_order_audit_trig();

CREATE TABLE audit.sp_orderprop_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       sp_orderprop_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.sp_orderprop_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.sp_orderprop_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.sp_orderprop_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.sp_orderprop_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.sp_orderprop_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER sp_orderprop_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.sp_orderprop
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.sp_orderprop_audit_trig();

CREATE TABLE audit.sp_person_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       sp_person_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.sp_person_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.sp_person_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.sp_person_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.sp_person_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.sp_person_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER sp_person_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.sp_person
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.sp_person_audit_trig();

CREATE TABLE audit.sp_roles_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       sp_roles_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.sp_roles_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.sp_roles_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.sp_roles_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.sp_roles_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.sp_roles_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER sp_roles_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.sp_roles
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.sp_roles_audit_trig();

CREATE TABLE audit.sp_token_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       sp_token_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.sp_token_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.sp_token_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.sp_token_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.sp_token_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.sp_token_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER sp_token_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.sp_token
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.sp_token_audit_trig();

CREATE TABLE audit.sp_person_roles_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       sp_person_roles_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.sp_person_roles_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.sp_person_roles_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.sp_person_roles_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.sp_person_roles_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.sp_person_roles_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER sp_person_roles_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.sp_person_roles
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.sp_person_roles_audit_trig();

CREATE TABLE audit.sp_organization_audit(
       audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
       operation VARCHAR(10) NOT NULL,
       username TEXT NOT NULL DEFAULT "current_user"(),
       logged_in_user INT,
       before JSONB,
       after JSONB,
       transactioncode VARCHAR(40),
       sp_organization_audit_id SERIAL PRIMARY KEY,
       is_undo BOOLEAN
);

ALTER TABLE audit.sp_organization_audit OWNER TO web_usr;

CREATE OR REPLACE FUNCTION sgn_people.sp_organization_audit_trig()
RETURNS trigger
LANGUAGE plpgsql
AS \$function\$
BEGIN

CREATE TEMPORARY TABLE IF NOT EXISTS logged_in_user(sp_person_id bigint);

IF TG_OP = 'INSERT'
THEN
INSERT INTO audit.sp_organization_audit (logged_in_user, operation, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN NEW;

ELSIF TG_OP = 'UPDATE'
THEN
IF NEW != OLD THEN
INSERT INTO audit.sp_organization_audit (logged_in_user, operation, before, after, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), to_jsonb(NEW), (SELECT NOW()::TEXT || txid_current()), FALSE);
END IF;
RETURN NEW;

ELSIF TG_OP = 'DELETE'
THEN
INSERT INTO audit.sp_organization_audit (logged_in_user, operation, before, transactioncode, is_undo)
VALUES ((SELECT max(sp_person_id) FROM logged_in_user WHERE sp_person_id IS NOT NULL), TG_OP, to_jsonb(OLD), (SELECT NOW()::TEXT || txid_current()), FALSE);
RETURN OLD;
END IF;
END;
\$function\$ ;

CREATE TRIGGER sp_organization_audit_trig
       BEFORE INSERT OR UPDATE OR DELETE
       ON sgn_people.sp_organization
       FOR EACH ROW
       EXECUTE PROCEDURE sgn_people.sp_organization_audit_trig();

--

EOSQL

print "You're done!\n";
}


####
1; #
####
