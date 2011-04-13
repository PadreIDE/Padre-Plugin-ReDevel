package Padre::Plugin::ReDevel;

use strict;
use warnings;
use 5.008;

our $VERSION = '0.03';

use Padre::Wx ();
use Data::Dumper; # ToDo - required only on debug mode
use File::Spec;
use File::HomeDir;
use YAML::Tiny;

use base 'Padre::Plugin';

our $ProtocolRegex = qr/^remote:\/\//;
our $ProtocolHandlerClass = 'Padre::Plugin::ReDevel::SSH';


=head1 NAME

Padre::Plugin::ReDevel - Padre support for remote development

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
    'ReDevel';
}


# The command structure to show in the Plugins menu
sub menu_plugins_simple {
    my $self = shift;
    return $self->plugin_name => [
        "About" => 'show_about',
        "Open config" => 'open_config',
        # ToDo - remove debug shortcut
        "Reload config\tCtrl+Shift+N" => 'load_config',

        # ToDo - remove debug menu (or make it conditional on Padre debug mode)
        # ToDo - remove debug shortcut
        "Devel ReDevel"  => [
            "Reload\tCtrl+Shift+M" => sub { $_[0]->current->ide->plugin_manager->reload_plugin('Padre::Plugin::ReDevel') },
        ],
    ];
}


# ToDo - use some Padre method?
sub conf_dir {
    return File::Spec->catdir(
        File::HomeDir->my_data,
        File::Spec->isa('File::Spec::Win32') ? 'Perl Padre' : '.padre'
    );
}


sub conf_fpath {
    my $self = shift;
    return File::Spec->catfile( $self->conf_dir, 'redevel.yml' );
}


sub open_config {
    my ( $self ) = @_;

    my $conf_fpath = $self->conf_fpath();
    my $main = $self->ide->wx->main;
    my $id = $main->setup_editor( $conf_fpath );
    return 1;
}


sub load_config {
    my $self = shift;

    my $conf_fpath = $self->conf_fpath();
    my $config = undef;
    eval { $config = YAML::Tiny::LoadFile($conf_fpath); };
    if ( $@ ) {
        #ToDo - warn dialog
        warn $@;
        return 0;
    }

    print Dumper( $config );
    $self->{ppr_config} = $config;
    return 1;
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
    $about->SetName("Padre Plugin ReDevel");
    $about->SetDescription("Remote development through SSH.");
    $about->SetVersion($VERSION);
    Wx::AboutBox($about);
    return 1;
}


sub plugin_enable {
    my $self = shift;
    
    $self->load_config();
    
    require Padre::File;
    require Padre::Plugin::ReDevel::SSH;
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
