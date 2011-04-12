package SSH::RPC::Shell::PP::Cmd::BaseJSON;

use strict;
use base 'SSH::RPC::Shell::PP::Cmd::Base';

use JSON;



=head1 NAME

SSH::RPC::Shell::PP::Cmd::BaseJSON - Base class for shell commands in JSON format.

=head1 SYNOPSIS

ToDo. See L<App::ReDevelS>.

=head1 METHODS


=head2 send_ok_response

Pack and send ok response to client as JSON.

=cut

sub send_ok_response {
    my ( $self, $response, $is_last ) = @_;

    my $result = $self->pack_ok_response( $response, $is_last );
    my $encoded_result = eval{ JSON->new->pretty->utf8->encode( $result ) };
    if ( $@ ) {
        print '{ "error" : "Malformed response.", "status" : "511" }' . "\n";
        print "\n\n";
        return 0;
    }

    print $encoded_result."\n";
    print "\n\n";
    return 1;
}


1;
