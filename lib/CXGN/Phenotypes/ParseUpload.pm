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
    my $zipfile = shift;
    my $nd_protocol_id = shift;
    my $nd_protocol_filename = shift;
    my $validate_result;

    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
            $validate_result = $p->validate($filename, $timestamp_included, $data_level, $schema, $zipfile, $nd_protocol_id, $nd_protocol_filename);
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
    my $zipfile = shift;
    my $user_id = shift;
    my $c = shift;
    my $nd_protocol_id = shift;
    my $nd_protocol_filename = shift;
    my $parse_result;

    foreach my $p ($self->plugins()) {
        if ($type eq $p->name()) {
            $parse_result = $p->parse($filename, $timestamp_included, $data_level, $schema, $zipfile, $user_id, $c, $nd_protocol_id, $nd_protocol_filename);
        }
    }
    return $parse_result;
}

1;
