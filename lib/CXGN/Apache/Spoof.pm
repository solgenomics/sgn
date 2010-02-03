
=head1 PACKAGE

 CXGN::Apache::Spoof

=head1 USAGE

 use CXGN::Apache::Spoof;

=head1 DESCRIPTION

 Allow tests or command-line perl to run on scripts that would normally
 depend on being run by apache-perl.

 This is very incomplete.  If you need to add a subroutine, do so!

 Warning: using this package might kill a script that should be run
 by apache on a normal basis.  Don't forget to delete the 'use' statement
 if that is the case!

=cut

package Apache::Cookie;
#dummy mod_perl package
use CXGN::Class::MethodMaker [
	scalar => [
		{-default => "/"},
		'path',
		'name',
		'value',
		{-default => "localhost.localdomain" },
		'domain',
	]
];

our $COOKIES = {}; #name => cookie object

sub new {
	my $class = shift;
	my $r = shift;
	my $self = bless {}, $class;
	$self->{request} = $r;
	return $self;
}

sub fetch {
	return $COOKIES;	
}

sub bake { 
	my $self = shift;
	
	die "$self Needs to be named first:\n" . Dumper($self) . "\n"
		unless $self->{name};

	$COOKIES->{$self->{name}} = $self;
} 

1;

package Apache;
sub request { 
	my $class = shift;
	my $self = bless {}, $class;
	$self->{hostname} = 'localhost';
	return $self;
}
sub hostname {
	my $self = shift;
	return $self->{hostname};
}
sub pnotes { "duly_noted" }
1;





