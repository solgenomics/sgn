
=head1 NAME

SGN::Controller::DecisionVote - public pages of the variety votes of decision meetings

=head1 DESCRIPTION

No login is needed: the token of the personal link (e-mailed to each invited
person) identifies the voter. There is no public link.

  /decision_vote/ballot/<ballot token>  give the candidates a place, notes; results once closed

Data: SGN::Controller::AJAX::DecisionVote.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

package SGN::Controller::DecisionVote;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub ballot : Path('/decision_vote/ballot') Args(1) {
    my ($self, $c, $token) = @_;
    $c->stash->{token} = ($token // '') =~ /^[0-9a-f]{48}$/ ? $token : '';
    $c->stash->{kind} = 'ballot';
    $c->stash->{template} = '/decision_vote/vote.mas';
}

1;
