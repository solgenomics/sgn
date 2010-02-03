package DAS::Util::SqlParser;

=head1 NAME

DAS::Util - A simple XML sql parser

=head1 SYNOPSIS

		my $parser = DAS::Util::SqlParser->new(SQLFILE);
		my $query = $parser->getSQL("GUS.pm", "get_feature_by_name");
		$query =~ s/(\$\w+)/eval $1/eg;
=cut

=head1 AUTHOR

Name:  Haiming Wang
Email: hwang@uga.edu

=cut

use strict;
use XML::Simple;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {};
	my @file = @_;

	my $xsl = XML::Simple->new();
	my $tree = $xsl->XMLin(@file, Cache => 'memshare') or die "cannot open the sql file\n";

	$self->{tree} = $tree;

	bless( $self, $class );
	return $self;

}

sub getSQL {
	my $self = shift;
	my ($modulename, $key) = @_;

	my $obj = $self->{tree}->{module}->{$modulename}->{sqlQuery};

	return $obj->{sql} if (exists $obj->{sql});
	return $obj->{$key}->{sql};
}

sub print {
	my $self = shift;
	print Dumper($self);
}

1;
