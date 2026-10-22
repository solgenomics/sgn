=head1 NAME

t/unit/SGN/Controller/BreedersToolbox.t - stash of the genotype QC page

=head1 DESCRIPTION

Calls the /breeders/genotype_qc action with a minimal stand-in for the
Catalyst context (no database). Its template,
mason/breeders_toolbox/manage_genotype_qc.mas, requires a facilities
argument; without it the page dies with "no value sent for required
parameter 'facilities'".

=cut

use strict;
use warnings;

use Test::More;
use SGN::Controller::BreedersToolbox;

## no critic (Modules::RequireFilenameMatchesPackage)
{
    package Local::BreedersToolbox::Context;
    sub new { my ($class, %args) = @_; return bless { stash => {}, config => $args{config} }, $class; }
    sub user { return 1; }
    sub config { return $_[0]->{config}; }
    sub stash { return $_[0]->{stash}; }
    sub dbic_schema { return; }
}

my $c = Local::BreedersToolbox::Context->new(
    config => { genotyping_facilities => 'None,Cornell IGD,Intertek' },
);

SGN::Controller::BreedersToolbox->manage_genotype_qc($c);

is($c->stash->{template}, '/breeders_toolbox/manage_genotype_qc.mas', 'genotype QC template is used');
is_deeply($c->stash->{facilities}, ['None', 'Cornell IGD', 'Intertek'], 'configured genotyping facilities are stashed');

my $template = 'mason' . $c->stash->{template};
open(my $fh, '<', $template) or die "Can't read $template: $!";
my $source = do { local $/; <$fh> };
close($fh);

my ($args) = $source =~ m{<%args>(.*?)</%args>}s;
my @required = map { /^\s*[\$\@\%](\w+)\s*;?\s*$/ ? $1 : () } split /\n/, $args // '';

ok(scalar(@required), 'the template has required arguments');
foreach my $arg (@required) {
    ok(exists $c->stash->{$arg}, "required template argument '$arg' is stashed");
}

done_testing();
