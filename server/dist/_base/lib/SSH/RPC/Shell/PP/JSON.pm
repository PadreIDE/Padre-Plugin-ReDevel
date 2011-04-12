package SSH::RPC::Shell::PP::JSON;

use base 'SSH::RPC::Shell::PP::Base';

use strict;
use JSON;

=head1 NAME

SSH::RPC::Shell::PP::Base - Base class for processing requests on remote side in JSON format.

=head1 SYNOPSIS

ToDo. See L<App::ReDevelS>.

=head1 METHODS


=head2 run ()

Main method. Run one command. Pack request/response to JSON.

=cut

sub run {
    my ( $self, $fh ) = @_;
    $fh = \*STDIN unless defined $fh;

    my $request_text = '';
    my $empty_lines = '';
    while ( my $line = <$fh> ) {
        if ( $line eq "\n" || $line eq "\r\n" ) {
            $empty_lines++;
            # two empty lines (or eof) -> output to decode finished
            last if $empty_lines >= 2;

        } else {
            $empty_lines = 0;
            $request_text .= $line;
        }
    }

    my $request = JSON->new->utf8->decode( $request_text );
    my $result = $self->process_request( $request );

    if ( ref $result eq 'HASH' ) {
        my $encoded_result = eval{ JSON->new->pretty->utf8->encode($result) };
        if ( $@ ) {
            print '{ "error" : "Malformed response.", "status" : "511" }' . "\n";
            return 0;
        }
        print $encoded_result."\n";
    }

    return 1;
}


1;
