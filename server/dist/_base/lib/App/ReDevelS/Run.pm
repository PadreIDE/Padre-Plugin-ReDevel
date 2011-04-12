package App::ReDevelS::Run;

use strict;
use warnings;

use base 'SSH::RPC::Shell::PP::Cmd::BaseJSON';

use Fcntl ':mode';

=head1 NAME

App::ReDevelS::ScanHost - App::ReDevel class for server.

=head1 SYNOPSIS

ToDo. See L<App::ReDevelS>.

=head1 DESCRIPTION

Run commands on server.

=head1 METHODS


=head2 new

Constructor.

=cut


sub new {
    my ( $class, $hash_obj ) = @_;

    my $self = $class->SUPER::new();
    $self->{hash_obj} = $hash_obj;

    return $self;
}


=head2 get_canon_dir

Canonize given path.

=cut

sub get_canon_dir {
    my ( $self, $dir ) = @_;

    my $canon_dir = undef;

    if ( $dir eq '' ) {
        $canon_dir = '/';

    } else {
        $canon_dir = $dir . '/';
    }

    $canon_dir =~ s{ \/{2,} }{\/}gx;
    return $canon_dir;
}


=head2 get_dir_items

Load directory items list.

=cut

sub get_dir_items {
    my ( $self, $dir_name ) = @_;

    # Load direcotry items list.
    my $dir_handle;
    if ( not opendir($dir_handle, $dir_name) ) {
        $self->add_error("Directory '$dir_name' not open for read.");
        return 0;
    }
    my @all_dir_items = readdir($dir_handle);
    close($dir_handle);

    my @dir_items = ();
    foreach my $item ( @all_dir_items ) {
        next if $item eq '.';
        next if $item eq '..';
        next if $item =~ /^\s*$/;
        push @dir_items, $item;
    }

    return \@dir_items;
}


=head2 my_lstat

Encapsulate 'lstat' function.

=cut

sub my_lstat {
    my ( $self, $full_path ) = @_;

    # Root path '' is '/' for lstat.
    my $lstat_full_path = $full_path;
    $lstat_full_path = '/' unless $full_path;
    
    my @lstat = lstat( $lstat_full_path );
    return ( 0 ) unless scalar @lstat;
    return ( 1, @lstat );
}


=head2 reset_state

Reset info about result's buffer.

=cut

sub reset_state {
    my ( $self, $full_reset ) = @_;

    $self->{errors} = [];

    return 1;
}


=head2 send_state

Send actual result's buffer.

=cut

sub send_state {
    my ( $self, $is_last ) = @_;

    my $result = {
        loaded_items => $self->{loaded_items},
        errors => $self->{errors},
    };
    my $ret_code = $self->send_ok_response( $result, $is_last );
    $self->reset_state( 0 );
    return $ret_code;
}


1;
