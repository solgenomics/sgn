package Test::AlignViewer;

=head1 NAME

t/tools/align_viewer.t - a website-level test of the align_viewer

=head1 DESCRIPTION

Tests the align_viewer.

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use base 'Test::Class';
use constant HAS_MUSCLE => sub { no warnings; system "muscle"; $? == 0 ? 1 : 0 }->();
use constant MUSCLE_TESTS => HAS_MUSCLE ? 3 : 0;

use Test::More tests => 9 + MUSCLE_TESTS;
use Test::WWW::Mechanize;


die "Need to set the SGN_TEST_SERVER environment variable" unless defined($ENV{SGN_TEST_SERVER});
my $base_url = $ENV{SGN_TEST_SERVER};

sub make_fixture : Test(setup) {
    my $self = shift;
    $self->{mech} = Test::WWW::Mechanize->new;
}

sub teardown : Test(teardown) {
}

# Convenience methods on the test object

sub get_ok {
    my ($self,$url,$msg) = @_;
    return $self->{mech}->get_ok("$base_url$url",$msg);
}
sub get {
    my ($self,$url,$msg) = @_;
    return $self->{mech}->get("$base_url$url",$msg);
}
sub content_contains {
    my ($self,@args) = @_;
    return $self->{mech}->content_contains(@args);
}
sub submit_form_ok {
    my ($self,@args) = @_;
    return $self->{mech}->submit_form_ok(@args);
}
sub submit_form {
    my ($self,@args) = @_;
    return $self->{mech}->submit_form(@args);
}
#### Tests

sub BASIC : Tests {
    my $self = shift;
    $self->get_ok("/tools/align_viewer/index.pl");
    $self->content_contains("Alignment Analyzer");
    $self->get_ok("/tools/align_viewer/show_align.pl");
    $self->content_contains("No sequence data provided!");
}
sub INVALID_FASTA_INPUT : Tests {
    my $self = shift;
    $self->get("/tools/align_viewer/index.pl");
    my $params = {
               form_name => "aligninput",
               fields    => {
                    seq_data => ">SL1.00sc00001\nAAAGTTCAGAGAATGGATTTTCA"
               },
    };
    $self->submit_form_ok($params, "Submit align form");
    $self->content_contains("FASTA must have at least two valid sequences","Form requires at least 2 valid sequences");
}

sub ALIGNMENT_EXAMPLE : Tests {
    my $self = shift;
    my $url = "/tools/align_viewer/index.pl?&format=fasta&title=Alignment%20Example&type=pep&show_prot_example=1";

    $self->get_ok($url);
    my $params = {
               form_name => "aligninput",
    };
    $self->submit_form_ok($params, "Submit Alignment Example form");
    $self->content_contains("View and Analyze Alignment");
}

sub UNALINGED_EXAMPLE : Tests {
    return unless HAS_MUSCLE;
    my $self = shift;
    my $url = "/tools/align_viewer/index.pl?&format=fasta_unaligned&maxiters=1&title=CDS%20Example&type=cds&show_cds_example=1";

    $self->get_ok($url);
    my $params = {
               form_name => "aligninput",
    };
    $self->submit_form_ok($params, "Submit Alignment Example form");
    $self->content_contains("View and Analyze Alignment");
}

Test::Class->runtests;
