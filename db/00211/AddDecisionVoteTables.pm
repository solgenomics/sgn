#!/usr/bin/env perl


=head1 NAME

AddDecisionVoteTables.pm

=head1 SYNOPSIS

mx-run AddDecisionVoteTables [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds the tables of the variety votes of decision meetings
(/breeders/meeting): people who are not Breedbase users (farmers, field
workers) register with a public link and rank the candidate accessions of a
meeting between a start and an end date.

  sgn_people.sp_decision_vote          a vote: meeting, dates, accessions to vote (accessions),
                                       accessions only for notes (note_accessions),
                                       copy of the analysis evidence (only invited people vote:
                                       there is no public link)
  sgn_people.sp_decision_vote_voter    a registered person (name, e-mail) and the token of the
                                       ballot link sent to them by e-mail (sp_person_id: a Breedbase
                                       user invited by the organizer); notes_refused counts the
                                       sends refused for disrespectful words
  sgn_people.sp_decision_vote_invite   a person invited to the vote: name and e-mail, or a Breedbase
                                       user (invited_sp_person_id); registered and sent the ballot link
                                       when the invitation is sent (invited_date is empty until then)
  sgn_people.sp_decision_vote_ballot   the rank (accessions to vote) and optional notes a voter gave
                                       an accession (rank is empty for the accessions only for notes)

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddDecisionVoteTables;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds the sgn_people.sp_decision_vote, sp_decision_vote_voter, sp_decision_vote_invite and sp_decision_vote_ballot tables used by the variety votes of decision meetings

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

    my $dbuser = 'web_usr';

    $self->dbh->do(<<EOSQL);
CREATE TABLE IF NOT EXISTS sgn_people.sp_decision_vote (
    sp_decision_vote_id SERIAL PRIMARY KEY,
    meeting_id BIGINT NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    analysis_id BIGINT,
    accessions JSONB NOT NULL,
    note_accessions JSONB NOT NULL DEFAULT '[]',
    evidence JSONB,
    sp_person_id BIGINT REFERENCES sgn_people.sp_person(sp_person_id) ON DELETE SET NULL,
    create_date TIMESTAMP NOT NULL DEFAULT now(),
    CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS sp_decision_vote_meeting_idx ON sgn_people.sp_decision_vote (meeting_id);

CREATE TABLE IF NOT EXISTS sgn_people.sp_decision_vote_voter (
    sp_decision_vote_voter_id SERIAL PRIMARY KEY,
    sp_decision_vote_id INTEGER NOT NULL REFERENCES sgn_people.sp_decision_vote(sp_decision_vote_id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(100),
    organization VARCHAR(255),
    location VARCHAR(255),
    email VARCHAR(255) NOT NULL,
    sp_person_id BIGINT REFERENCES sgn_people.sp_person(sp_person_id) ON DELETE SET NULL,
    token VARCHAR(64) NOT NULL UNIQUE,
    general_comment TEXT,
    registered_date TIMESTAMP NOT NULL DEFAULT now(),
    link_sent_date TIMESTAMP,
    voted_date TIMESTAMP,
    notes_refused INTEGER NOT NULL DEFAULT 0
);

-- one registration per person and e-mail in a vote (people of a family may share an e-mail)
CREATE UNIQUE INDEX IF NOT EXISTS sp_decision_vote_voter_person_idx ON sgn_people.sp_decision_vote_voter (sp_decision_vote_id, lower(email), lower(name));

CREATE INDEX IF NOT EXISTS sp_decision_vote_voter_vote_idx ON sgn_people.sp_decision_vote_voter (sp_decision_vote_id);

CREATE TABLE IF NOT EXISTS sgn_people.sp_decision_vote_ballot (
    sp_decision_vote_voter_id INTEGER NOT NULL REFERENCES sgn_people.sp_decision_vote_voter(sp_decision_vote_voter_id) ON DELETE CASCADE,
    accession VARCHAR(255) NOT NULL,
    rank INTEGER CHECK (rank IS NULL OR rank > 0),
    comment TEXT,
    PRIMARY KEY (sp_decision_vote_voter_id, accession)
);

CREATE TABLE IF NOT EXISTS sgn_people.sp_decision_vote_invite (
    sp_decision_vote_invite_id SERIAL PRIMARY KEY,
    sp_decision_vote_id INTEGER NOT NULL REFERENCES sgn_people.sp_decision_vote(sp_decision_vote_id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    invited_sp_person_id BIGINT REFERENCES sgn_people.sp_person(sp_person_id) ON DELETE SET NULL,
    sp_person_id BIGINT REFERENCES sgn_people.sp_person(sp_person_id) ON DELETE SET NULL,
    create_date TIMESTAMP NOT NULL DEFAULT now(),
    invited_date TIMESTAMP,
    times_sent INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS sp_decision_vote_invite_email_idx ON sgn_people.sp_decision_vote_invite (sp_decision_vote_id, lower(email));

GRANT SELECT, UPDATE, DELETE, INSERT ON sgn_people.sp_decision_vote TO $dbuser;
GRANT SELECT, UPDATE, DELETE, INSERT ON sgn_people.sp_decision_vote_voter TO $dbuser;
GRANT SELECT, UPDATE, DELETE, INSERT ON sgn_people.sp_decision_vote_ballot TO $dbuser;
GRANT SELECT, UPDATE, DELETE, INSERT ON sgn_people.sp_decision_vote_invite TO $dbuser;

GRANT USAGE ON SEQUENCE sgn_people.sp_decision_vote_sp_decision_vote_id_seq TO $dbuser;
GRANT USAGE ON SEQUENCE sgn_people.sp_decision_vote_voter_sp_decision_vote_voter_id_seq TO $dbuser;
GRANT USAGE ON SEQUENCE sgn_people.sp_decision_vote_invite_sp_decision_vote_invite_id_seq TO $dbuser;

EOSQL

    print "You're done!\n";
}


####
1; #
####
