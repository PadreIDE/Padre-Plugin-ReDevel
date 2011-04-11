package Padre::Plugin::Remote::SSH;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.01';
our @ISA     = 'Padre::File';


sub new {
	my ( $class, $url ) = @_;

	# Create myself
	my $self;
	$self->{url} = $url;
	bless $self, $class;
	
	print __PACKAGE__ . " ToDo\n";

	return $self;
}


1;
