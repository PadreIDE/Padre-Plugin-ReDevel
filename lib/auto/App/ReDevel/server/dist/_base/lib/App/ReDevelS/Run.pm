package App::ReDevelS::Run;

use strict;
use warnings;

use base 'SSH::RPC::Shell::PP::Cmd::BaseJSON';

use File::Path;

=head1 NAME

App::ReDevelS::Run - App::ReDevel class for server.

=head1 SYNOPSIS

ToDo. See L<App::ReDevelS>.

=head1 DESCRIPTION

Run commands on server.

=head1 METHODS


=head2 new

Constructor.

=cut


sub new {
    my ( $class ) = @_;
    my $self = $class->SUPER::new();
    return $self;
}


=head2 run_mkpath

Run mkpath.

=cut

sub mkpath_raw {
	my ( $self, $path ) = @_;
	return 1 if -d $path;
    my $rc = File::Path::mkpath( $path, 0, {error => \my $err} );
    return 1 if $rc;
    return 0, $err;
}


=head2 run_mkpath

Run mkpath_raw and pack response.

=cut

sub run_mkpath {
    my $self = shift;
    return $self->pack_base_return( $self->mkpath_raw( @_ ) );
}


1;
