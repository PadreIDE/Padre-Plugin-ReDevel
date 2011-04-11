package Padre::Plugin::Remote;

use strict;
use warnings;
use 5.008;

our $VERSION = '0.03';

use Padre::Wx ();

use base 'Padre::Plugin';

our $ProtocolRegex = qr/^remote:\/\//;
our $ProtocolHandlerClass = 'Padre::Plugin::Remote::SSH';


=head1 NAME

Padre::Plugin::Remote - Padre support for remote development

=head1 SYNOPSIS

TODO

=cut

sub padre_interfaces {
    return (
        'Padre::Plugin' => 0.84,
        'Padre::File'   => 0.4,
    );
}

sub plugin_name {
    'Remote';
}


# The command structure to show in the Plugins menu
sub menu_plugins_simple {
    my $self = shift;
    return $self->plugin_name => [
        "About" => sub { $self->show_about() },
        # ToDo - debug
        "PPR-Devel"  => [
            "Reload\tCtrl+Shift+M" => sub { $_[0]->current->ide->plugin_manager->reload_plugin('Padre::Plugin::Remote') },
        ],
    ];
}


sub padre_hooks {
    my $self = shift;
    return {
        before_save => sub {
            print " [[[TEST_PLUGIN:before_save]]] " . join( ', ', @_ ) . "\n";
            return undef;
        },
        after_save => sub {
            print  " [[[TEST_PLUGIN:before_save]]] " . join( ', ', @_ ) . "\n";
            return 1;
        },
    };
}


sub show_about {
    my $self = shift;
    my $about = Wx::AboutDialogInfo->new;
    $about->SetName("Padre Plugin Remote (PPR)");
    $about->SetDescription("Remote development through SSH.");
    Wx::AboutBox($about);
    return 1;
}


sub plugin_enable {
    my $self = shift;
    require Padre::File;
    require Padre::Plugin::Remote::SSH;
    require Net::OpenSSH;
    Padre::File->RegisterProtocol($ProtocolRegex, $ProtocolHandlerClass);
    return 1;
}


sub plugin_disable {
    my $self = shift;
    Padre::File->DropProtocol($ProtocolRegex, $ProtocolHandlerClass);
    return 1;
}


1;

__END__


=head1 AUTHOR

Michal Jurosz, C<mj@mj41.cz>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 Michal Jurosz

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl 5 itself.

=cut
