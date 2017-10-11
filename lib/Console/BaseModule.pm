# --
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## nofilter(TidyAll::Plugin::OTRS::Perl::Require)
## nofilter(TidyAll::Plugin::OTRS::Migrations::OTRS6::TimeObject)
package Console::BaseModule;

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . "/Kernel/cpan-lib";

# Also use relative path to find this if invoked inside of the OTRS directory.
use lib ".";
use lib "./Kernel/cpan-lib";

eval {
    require Kernel::Config;
    require Kernel::System::Encode;
    require Kernel::System::Log;
    require Kernel::System::Main;
    require Kernel::System::DB;
    require Kernel::System::Time;
    require Kernel::System::Package;
    require Kernel::System::XML;
};

=head1 NAME

BaseModule - base class for module commands

=head1 PUBLIC INTERFACE

=head2 CodeActionHandler()
Performs a package Code action from its sopm file such as CodeInstall, CodeUpdate, etc

    my $Success = $ModuleObject->CodeActionHandler(
        Module => /Packages/MyPackage/MyPackage.sopm,
        Action => 'Install',                                # Install, Uninstall, Upgrade, Reinstall
        Type   => 'pre',                                    # pre, post
    );

Returns:

    $Success = 1;       # or false in case of an error

=cut

## nofilter(TidyAll::Plugin::OTRS::Perl::ObjectManagerCreation)
sub CodeActionHandler {
    my ( $Self, %Param ) = @_;

    my $Module = $Param{Module};

    local $Kernel::OM;
    if ( eval 'require Kernel::System::ObjectManager' ) {    ## no critic

        # create object manager
        $Kernel::OM = Kernel::System::ObjectManager->new();
    }

    # create common objects
    my %CommonObject = ();
    $CommonObject{ConfigObject} = Kernel::Config->new();
    $CommonObject{EncodeObject} = Kernel::System::Encode->new(%CommonObject);
    $CommonObject{LogObject}    = Kernel::System::Log->new(
        LogPrefix    => "OTRS-$Module",
        ConfigObject => $CommonObject{ConfigObject},
    );
    $CommonObject{MainObject}    = Kernel::System::Main->new(%CommonObject);
    $CommonObject{DBObject}      = Kernel::System::DB->new(%CommonObject);
    $CommonObject{TimeObject}    = Kernel::System::Time->new(%CommonObject);
    $CommonObject{XMLObject}     = Kernel::System::XML->new(%CommonObject);
    $CommonObject{PackageObject} = Kernel::System::Package->new(%CommonObject);

    my $PackageContent = $CommonObject{MainObject}->FileRead(
        Location => $Module,
    );

    my %Structure = $CommonObject{PackageObject}->PackageParse( String => $PackageContent );

    if ( $Param{Action} eq 'Upgrade' && $Structure{CodeUpgrade} ) {
        my @Codes;
        for my $Part ( @{ $Structure{CodeUpgrade} } ) {
            if ( !$Part->{Version} ) {
                push @Codes, $Part;
            }
            elsif ( $Part->{Version} eq $Param{Version} ) {
                push @Codes, $Part;
            }
        }

        CODE:
        for my $Code (@Codes) {
            next CODE if $Code->{Type} ne $Param{Type};
            my $Success = $CommonObject{PackageObject}->_Code(
                Code      => [$Code],
                Type      => $Code->{Type},
                Structure => \%Structure,
            );
            return if !$Success;
        }
    }
    else {

        my $StructureKey = 'Code' . ucfirst $Param{Action};

        if ( $Structure{$StructureKey} ) {
            my $Success = $CommonObject{PackageObject}->_Code(
                Code      => $Structure{$StructureKey},
                Type      => $Param{Type},
                Structure => \%Structure,
            );

            return if !$Success;
        }
    }

    return 1;
}

=head2 DatabaseActionHandler()
Performs a package Database action from its sopm file such as DatabaseInstall or DatabaseIninstall.

    my $Success = $ModuleObject->DatabaseActionHandler(
        Module => /Packages/MyPackage/MyPackage.sopm,
        Action => 'Install',                                # Install, Uninstall, Upgrade
        Type   => 'pre',                                    # pre, post
    );

Returns:

    $Success = 1;       # or false in case of an error

=cut

sub DatabaseActionHandler {
    my ( $Self, %Param ) = @_;

    my $Module = $Param{Module};

    local $Kernel::OM;
    if ( eval 'require Kernel::System::ObjectManager' ) {    ## no critic

        # create object manager
        $Kernel::OM = Kernel::System::ObjectManager->new();
    }

    # create common objects
    my %CommonObject = ();
    $CommonObject{ConfigObject} = Kernel::Config->new();
    $CommonObject{EncodeObject} = Kernel::System::Encode->new(%CommonObject);
    $CommonObject{LogObject}    = Kernel::System::Log->new(
        LogPrefix    => "OTRS-$Module",
        ConfigObject => $CommonObject{ConfigObject},
    );
    $CommonObject{MainObject}    = Kernel::System::Main->new(%CommonObject);
    $CommonObject{DBObject}      = Kernel::System::DB->new(%CommonObject);
    $CommonObject{TimeObject}    = Kernel::System::Time->new(%CommonObject);
    $CommonObject{XMLObject}     = Kernel::System::XML->new(%CommonObject);
    $CommonObject{PackageObject} = Kernel::System::Package->new(%CommonObject);

    my $PackageContent = $CommonObject{MainObject}->FileRead(
        Location => $Module,
    );

    my %Structure = $CommonObject{PackageObject}->PackageParse( String => $PackageContent );

    my $StructureKey = 'Database' . ucfirst $Param{Action};

    return 1 if !$Structure{$StructureKey};

    return 1 if !$Structure{$StructureKey}->{ $Param{Type} };

    if ( $Param{Version} ) {
        my %RelevantStructure;

        my $CheckVersion = sprintf "%d%03d%03d", split /\./, $Param{Version};

        for my $Type ( qw/pre post/ ) {

            PART:
            for my $Part ( @{ $Structure{$StructureKey}->{$Type} || [] } ) {
                next PART if !$Part->{Version};

                my $PartVersion = sprintf "%d%03d%03d", split /\./, $Part->{Version};

                next PART if $CheckVersion > $PartVersion;

                push @{ $RelevantStructure{$Type} }, $Part;
            }
        }

        $Structure{$StructureKey} = \%RelevantStructure;
    }


    my $Success = $CommonObject{PackageObject}->_Database(
        Database => $Structure{$StructureKey}->{ $Param{Type} },
    );
    return if !$Success;

    return 1;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
