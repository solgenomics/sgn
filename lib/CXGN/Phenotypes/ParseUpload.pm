package CXGN::Phenotypes::ParseUpload;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Module::Pluggable require => 1;

sub validate {
    my $self = shift;
    my $type = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $validate_result;

    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
	     $validate_result = $p->validate($filename, $timestamp_included, $data_level, $schema);
	}
    }
    return $validate_result;
}

sub parse {
    my $self = shift;
    my $type = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $parse_result;

    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
	     $parse_result = $p->parse($filename, $timestamp_included, $data_level, $schema);
	}
    }
    return $parse_result;
}

1;
